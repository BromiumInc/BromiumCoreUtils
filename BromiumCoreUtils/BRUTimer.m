//
//  Copyright (C) 2013-2016, Bromium Inc.
//
//  This software may be modified and distributed under the terms
//  of the BSD license.  See the LICENSE file for details.
//
//  Created by Johannes Weiß on 20/03/2014.
//

#import "BRUDispatchUtils.h"
#import "BRUBaseDefines.h"
#import "BRUAsserts.h"
#import "BRUARCUtils.h"
#import "BRUTimer.h"

@interface BRUTimer () {
    BOOL _running; /* synchronised by syncQ */
    NSUInteger _generation; /* synchronized by syncQ */
}

@property (nonatomic, readonly, strong) dispatch_queue_t syncQ;
@property (nonatomic, readonly, strong) dispatch_queue_t targetQ;

@property (atomic, readwrite, assign) NSTimeInterval currentInterval;

@end

@implementation BRUTimer

- (void)incrementGenerationUnsynchronized
{
    BRU_ASSERT_ON_QUEUE(self.syncQ);
    self->_generation++;
}

- (NSUInteger)generationUnsynchronized
{
    BRU_ASSERT_ON_QUEUE(self.syncQ);
    return self->_generation;
}

- (NSUInteger)generation
{
    BRU_ASSERT_OFF_QUEUE(self.syncQ);
    __block NSUInteger gen;
    dispatch_sync(self.syncQ, ^{
        gen = self->_generation;
    });
    return gen;
}

- (void)setRunningUnsynchronized:(BOOL)running
{
    BRU_ASSERT_ON_QUEUE(self.syncQ);
    self->_running = running;
}

- (BOOL)runningUnsynchronized
{
    BRU_ASSERT_ON_QUEUE(self.syncQ);
    return self->_running;
}

- (void)setRunning:(BOOL)running
{
    dispatch_barrier_async(self.syncQ, ^{
        [self setRunningUnsynchronized:running];
    });
}

#pragma mark - Helpers

- (void)fireWithDate:(NSDate *)date postFireBlock:(void(^)(void))postFireBlock
{
    BRU_weakify(self);
    dispatch_async(self.targetQ, ^{
        BRU_strongify(self);
        if (self) {
            self.block(self, date);
            postFireBlock();
        }
    });
}

- (void)setupTimer
{
    NSUInteger gen = [self generation];
    BRU_weakify(self);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.currentInterval * NSEC_PER_SEC)),
                   self.syncQ, ^
                   {
                       NSDate *fireDate = [NSDate date];

                       /* attention we're on syncQ here, be quick! */
                       BRU_strongify(self);
                       if (!self) {
                           return;
                       }
                       NSUInteger currentGen = [self generationUnsynchronized];
                       BRUAssert(currentGen > 0 && currentGen >= gen,
                                 @"consistency problems: timer fire gen: %lu, current timer gen: %lu",
                                 gen, currentGen);
                       if (gen != currentGen || ![self runningUnsynchronized]) {
                           /* fired in older generation or not running, ignoring */
                           return;
                       }

                       NSTimeInterval nextInterval = self.adjustFun(self, self.currentInterval);
                       self.currentInterval = nextInterval;

                       if (!self.repeat) {
                           [self setRunningUnsynchronized:NO];
                       }

                       dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                           BRU_strongify(self);
                           if (self) {
                               void (^setupTimerBlock)(void) = ^ {
                                   BRU_strongify(self);
                                   if (self.repeat) {
                                       [self setupTimer];
                                   }
                               };
                               void (^preFireBlock)(void);
                               void (^postFireBlock)(void);

                               switch (self.mode) {
                                   case BRUTimerModeIntervalBetweenBlockExecutions:
                                       preFireBlock = ^{};
                                       postFireBlock = setupTimerBlock;
                                       break;
                                   case BRUTimerModeIntervalClockedOnWallClockTime:
                                       preFireBlock = setupTimerBlock;
                                       postFireBlock = ^{};
                                       break;
                               }
                               preFireBlock();
                               [self fireWithDate:fireDate postFireBlock:postFireBlock];
                           }
                       });
                   });
}

- (BOOL)running
{
    BRU_ASSERT_OFF_QUEUE(self.syncQ);
    __block BOOL r;
    dispatch_barrier_sync(self.syncQ, ^{
        r = [self runningUnsynchronized];
    });
    return r;
}

#pragma mark - Public API

- (instancetype)initWithInterval:(NSTimeInterval)interval
                           block:(void(^)(BRUTimer *, NSDate *))block
                         onQueue:(dispatch_queue_t)userTargetQueue
                         repeats:(BOOL)repeat
                            mode:(BRUTimerMode)mode
                  adjustInterval:(NSTimeInterval(^)(BRUTimer *, NSTimeInterval))adjustFun
{
    if ((self = [super init])) {
        self->_initialInterval = interval;
        self->_block = block ?: ^(__unused BRUTimer *t, __unused NSDate *d) {};
        self->_adjustFun = adjustFun ?: ^(__unused BRUTimer *t, NSTimeInterval iv) { return iv; };
        self->_repeat = repeat;
        self->_running = NO;
        self->_mode = mode;

        self->_syncQ = bru_dispatch_queue_create("com.bromium.BRUTimer.syncQ", DISPATCH_QUEUE_SERIAL);
        self->_targetQ = userTargetQueue ?: bru_dispatch_queue_create("com.bromium.BRUTimer.SerialTargetQ",
                                                                      DISPATCH_QUEUE_SERIAL);
        self->_currentInterval = interval;
        self->_generation = 0;
    }
    return self;
}

- (instancetype)initWithInterval:(NSTimeInterval)interval
                           block:(void(^)(BRUTimer *, NSDate *))block
                         onQueue:(dispatch_queue_t)targetQueue
                         repeats:(BOOL)repeat
                  adjustInterval:(NSTimeInterval(^)(BRUTimer *, NSTimeInterval))adjustFun
{
    return [self initWithInterval:interval
                            block:block
                          onQueue:targetQueue
                          repeats:repeat
                             mode:BRUTimerModeIntervalBetweenBlockExecutions
                   adjustInterval:adjustFun];
}

- (void)fire
{
    [self fireWithDate:[NSDate date] postFireBlock:^{}];
}

- (void)start
{
    BRUAssert(![self running], @"already running");
    [self restart];
}

- (void)restart
{
    [self resumeWithUpdateInterval:YES interval:self.initialInterval];
}

- (void)restartWithInterval:(NSTimeInterval)interval
{
    [self resumeWithUpdateInterval:YES interval:interval];
}

- (void)suspend
{
    [self setRunning:NO];
}

- (void)resume
{
    [self resumeWithUpdateInterval:NO interval:0];
}

- (void)resumeWithUpdateInterval:(BOOL)updateInterval interval:(NSTimeInterval)timeInterval
{
    BRU_ASSERT_OFF_QUEUE(self.syncQ);
    dispatch_sync(self.syncQ, ^{
        if (updateInterval) {
            self.currentInterval = timeInterval;
        }
        [self incrementGenerationUnsynchronized];
        [self setRunningUnsynchronized:YES];
    });
    [self setupTimer];
}

+ (BRUTimer *)scheduledTimerWithInterval:(NSTimeInterval)interval
                                   block:(void(^)(BRUTimer *, NSDate *))block
                                 onQueue:(dispatch_queue_t)targetQueue
                                 repeats:(BOOL)repeat
                                    mode:(BRUTimerMode)mode
                          adjustInterval:(NSTimeInterval(^)(BRUTimer *, NSTimeInterval))adjustFun
{
    BRUTimer *t = [[BRUTimer alloc] initWithInterval:interval
                                               block:block
                                             onQueue:targetQueue
                                             repeats:repeat
                                                mode:mode
                                      adjustInterval:adjustFun];
    [t resume];
    return t;
}

+ (BRUTimer *)scheduledTimerWithInterval:(NSTimeInterval)interval
                                   block:(void(^)(BRUTimer *, NSDate *))block
                                 onQueue:(dispatch_queue_t)targetQueue
                                 repeats:(BOOL)repeat
                          adjustInterval:(NSTimeInterval(^)(BRUTimer *, NSTimeInterval))adjustFun
{
    return [BRUTimer scheduledTimerWithInterval:interval
                                          block:block
                                        onQueue:targetQueue
                                        repeats:repeat
                                           mode:BRUTimerModeIntervalBetweenBlockExecutions
                                 adjustInterval:adjustFun];
}


+ (BRUTimer *)scheduledTimerWithInterval:(NSTimeInterval)interval
                                   block:(void(^)(BRUTimer *, NSDate *))block
                                 onQueue:(dispatch_queue_t)targetQueue
                                 repeats:(BOOL)repeat
{
    return [BRUTimer scheduledTimerWithInterval:interval
                                          block:block
                                        onQueue:targetQueue
                                        repeats:repeat
                                 adjustInterval:nil];
}

+ (BRUTimer *)scheduledTimerWithInterval:(NSTimeInterval)interval
                                   block:(void(^)(BRUTimer *, NSDate *))block
                                 repeats:(BOOL)repeat
                          adjustInterval:(NSTimeInterval(^)(BRUTimer *, NSTimeInterval))adjustFun
{
    return [BRUTimer scheduledTimerWithInterval:interval
                                          block:block
                                        onQueue:NULL
                                        repeats:repeat
                                 adjustInterval:adjustFun];
}

+ (BRUTimer *)scheduledTimerWithInterval:(NSTimeInterval)interval
                                   block:(void(^)(BRUTimer *, NSDate *))block
                                 repeats:(BOOL)repeat
{
    return [BRUTimer scheduledTimerWithInterval:interval
                                          block:block
                                        onQueue:NULL
                                        repeats:repeat
                                 adjustInterval:NULL];
}


@end
