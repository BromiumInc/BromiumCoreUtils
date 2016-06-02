//
//  BRUTimer.h
//  BromiumUtils
//
//  Created by Johannes Weiß on 20/03/2014.
//  Copyright (c) 2014 Bromium UK Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "BRUBaseDefines.h"

typedef NS_ENUM(NSUInteger, BRUTimerMode) {
    BRUTimerModeIntervalBetweenBlockExecutions = 1,
    BRUTimerModeIntervalClockedOnWallClockTime = 2
};

BRU_assume_nonnull_begin

/**
 * BRUTimer is a timer object based on libdispatch. It has four major differences to NSTimer:
 *
 *  1. BRUTimer uses libdispatch (as opposed to NSTimer which uses NSRunLoop).
 *  2. BRUTimer uses blocks instead of Objective-C selectors.
 *  3. BRUTimer doesn't retain itself anywhere, i.e., retain it to make sure it fires.
 *  4. BRUTimer can be suspended and resumed, therefore you usually put save it as readonly member in your object.
 *
 * Additionally, `BRUTimer` has two different modes. In the `BRUTimerModeIntervalBetweenBlockExecutions` the time
 * interval inbetween fires starts when the execution of the last block ends. In the
 * `BRUTimerModeIntervalClockedOnWallClockTime` `BRUTimer` is clocked on wall time. The difference becomes obvious
 * given a `BRUTimer` firing on a 1s interval whose block runs for 5s. The the
 * `BRUTimerModeIntervalClockedOnWallClockTime` one execution of the block will get triggered every second. In the
 * `BRUTimerModeIntervalBetweenBlockExecutions` mode however an execution of the block will get triggered 1s
 * _after the previous execution of the block ends_. For non-repeating timers and the first timer fire the `mode`
 * has no relevance.
 *
 * `BRUTimer` allows for an external queue to be specified which is used to dispatch the block whenever the timer
 * fires. If no queue is specified a newly created _serial_ queue is used.
 *
 */
@interface BRUTimer : NSObject

BRU_DEFAULT_INIT_UNAVAILABLE(null_unspecified)

@property (nonatomic, readonly, assign) NSTimeInterval initialInterval;
@property (nonatomic, readonly, strong) void(^block)(BRUTimer *, NSDate *);
@property (nonatomic, readonly, assign) BOOL repeat;
@property (nonatomic, readonly, strong) NSTimeInterval(^adjustFun)(BRUTimer *, NSTimeInterval);
@property (nonatomic, readonly, assign) BRUTimerMode mode;

/**
 * Initialise a suspended BRUTimer
 *
 * @param interval The fire interval
 * @param block The block to execute on fire
 * @param targetQueue The queue to execute the block on. If nil uses the default global queue.
 * @param repeat Whether the timer repeats
 * @param mode The timer's mode (see class description for the semantics).
 * @param adjustFun The function to adjust the interval after each time the timer fired.
 */
- (instancetype)initWithInterval:(NSTimeInterval)interval
                           block:(void (^)(BRUTimer *, NSDate *))block
                         onQueue:(nullable dispatch_queue_t)targetQueue
                         repeats:(BOOL)repeat
                            mode:(BRUTimerMode)mode
                  adjustInterval:(NSTimeInterval(^ __nullable)(BRUTimer *, NSTimeInterval))adjustFun NS_DESIGNATED_INITIALIZER;

/**
 * Initialise a suspended BRUTimer (running in `BRUTimerModeIntervalBetweenBlockExecutions` mode)
 *
 * @param interval The fire interval
 * @param block The block to execute on fire
 * @param targetQueue The queue to execute the block on. If nil uses the default global queue.
 * @param repeat Whether the timer repeats
 * @param adjustFun The function to adjust the interval after each time the timer fired.
 */
- (instancetype)initWithInterval:(NSTimeInterval)interval
                           block:(void(^)(BRUTimer *, NSDate *))block
                         onQueue:(nullable dispatch_queue_t)targetQueue
                         repeats:(BOOL)repeat
                  adjustInterval:(NSTimeInterval(^ __nullable)(BRUTimer *, NSTimeInterval))adjustFun;

/**
 * Initially starts the timer
 */
- (void)start;

/**
 * Restarts the timer (same as `-[BRUTimer resume]` but resetting the interval back to the initial interval.
 */
- (void)restart;

/**
 * Restarts the timer and sets a new current interval. The initial interval is not changed. Calling `restart`
 * again, will reset the timer be back to the original interval. If you want the timer to remain at the new interval,
 * use `resume`.
 */
- (void)restartWithInterval:(NSTimeInterval)interval;

/**
 * Suspens the timer (ie stops it from firing again)
 */
- (void)suspend;

/**
 * Resumes the timer (lets it fire again)
 */
- (void)resume;

/**
 * Manually fires the timer asynchroneously
 */
- (void)fire;

/**
 * Returns a running BRUTimer. Make sure to retain the returned timer to make sure it fires.
 *
 * @param interval The fire interval.
 * @param block The block to execute on fire.
 * @param targetQueue The queue to execute the block on. If nil uses the default global queue.
 * @param repeat Whether the timer repeats.
 * @param mode The timer's mode (see class description for the semantics).
 * @param adjustFun The function to adjust the interval after each time the timer fired. You must not block this func.
 * @return The newly created timer.
 */
+ (BRUTimer *)scheduledTimerWithInterval:(NSTimeInterval)interval
                                   block:(void(^)(BRUTimer *, NSDate *))block
                                 onQueue:(nullable dispatch_queue_t)targetQueue
                                 repeats:(BOOL)repeat
                                    mode:(BRUTimerMode)mode
                          adjustInterval:(NSTimeInterval(^ __nullable)(BRUTimer *, NSTimeInterval))adjustFun;

/**
 * Returns a running BRUTimer. Make sure to retain the returned timer to make sure it fires.
 *
 * @param interval The fire interval.
 * @param block The block to execute on fire.
 * @param targetQueue The queue to execute the block on. If nil uses the default global queue.
 * @param repeat Whether the timer repeats.
 * @param adjustFun The function to adjust the interval after each time the timer fired. You must not block this func.
 * @return The newly created timer.
 */
+ (BRUTimer *)scheduledTimerWithInterval:(NSTimeInterval)interval
                                   block:(void(^)(BRUTimer *, NSDate *))block
                                 onQueue:(__nullable dispatch_queue_t)targetQueue
                                 repeats:(BOOL)repeat
                          adjustInterval:(NSTimeInterval(^ __nullable)(BRUTimer *, NSTimeInterval))adjustFun;

/**
 * Returns a running BRUTimer. Make sure to retain the returned timer to make sure it fires.
 *
 * @param interval The fire interval.
 * @param block The block to execute on fire.
 * @param targetQueue The queue to execute the block on. If nil uses the default global queue.
 * @param repeat Whether the timer repeats.
 * @return The newly created timer.
 */
+ (BRUTimer *)scheduledTimerWithInterval:(NSTimeInterval)interval
                                   block:(void(^)(BRUTimer *, NSDate *))block
                                 onQueue:(nullable dispatch_queue_t)targetQueue
                                 repeats:(BOOL)repeat;


/**
 * Returns a running BRUTimer. Make sure to retain the returned timer to make sure it fires.
 *
 * @param interval The fire interval.
 * @param block The block to execute on fire.
 * @param repeat Whether the timer repeats.
 * @param adjustFun The function to adjust the interval after each time the timer fired. You must not block this func.
 * @return The newly created timer.
 */
+ (BRUTimer *)scheduledTimerWithInterval:(NSTimeInterval)interval
                                   block:(void(^)(BRUTimer *, NSDate *))block
                                 repeats:(BOOL)repeat
                          adjustInterval:(NSTimeInterval(^ __nullable)(BRUTimer *, NSTimeInterval))adjustFun;


/**
 * Returns a running BRUTimer. Make sure to retain the returned timer to make sure it fires.
 *
 * @param interval The fire interval.
 * @param block The block to execute on fire.
 * @param repeat Whether the timer repeats.
 * @return The newly created timer.
 */
+ (BRUTimer *)scheduledTimerWithInterval:(NSTimeInterval)interval
                                   block:(void(^)(BRUTimer *, NSDate *))block
                                 repeats:(BOOL)repeat;

@end

BRU_assume_nonnull_end
