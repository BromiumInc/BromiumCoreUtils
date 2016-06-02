//
//  BRUTimerTests.m
//  BromiumUtils
//
//  Created by Johannes Weiß on 20/03/2014.
//  Copyright (c) 2014 Bromium UK Ltd. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "BRUConcurrentBox.h"
#import "BRUDispatchUtils.h"
#import "BRUTimer.h"

@interface BRUTimerTests : XCTestCase

@end

@implementation BRUTimerTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testSimpleNonRepeating
{
    volatile __block BOOL alreadyHit = NO;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __attribute__ ((objc_precise_lifetime, unused))
    BRUTimer *t = [BRUTimer scheduledTimerWithInterval:0.1
                                                 block:^(BRUTimer *t, NSDate *d) {
                                                     dispatch_semaphore_signal(sem);
                                                     XCTAssertFalse(alreadyHit,
                                                                    @"timer hits more than once but is non-repeating");
                                                     alreadyHit = YES;
                                                 }
                                               repeats:NO
                                        adjustInterval:nil];
    long timeout = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)));
    XCTAssertFalse(timeout, @"timeout hit");
    /* because it shouldn't repeat we now wait for the timeout */
    timeout = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)));
    XCTAssertTrue(timeout, @"timeout did not hit the second time");
}

- (void)testSimpleRepeating
{
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __attribute__ ((objc_precise_lifetime, unused))
    BRUTimer *t = [BRUTimer scheduledTimerWithInterval:0.1
                                                 block:^(BRUTimer *t, NSDate *d) {
                                                     dispatch_semaphore_signal(sem);
                                                 }
                                               repeats:YES
                                        adjustInterval:nil];
    long timeout = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)));
    XCTAssertFalse(timeout, @"first timeout hit");
    timeout = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)));
    XCTAssertFalse(timeout, @"second timeout hit");
}

- (void)testSuspendWorks
{
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __attribute__ ((objc_precise_lifetime, unused))
    BRUTimer *t = [BRUTimer scheduledTimerWithInterval:0.5
                                                 block:^(BRUTimer *t, NSDate *d) {
                                                     dispatch_semaphore_signal(sem);
                                                 }
                                               repeats:YES
                                        adjustInterval:nil];
    long timeout = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)));
    XCTAssertFalse(timeout, @"timeout hit");
    [t suspend];
    /* because it shouldn't repeat we now wait for the timeout */
    timeout = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)));
    XCTAssertTrue(timeout, @"timeout did not hit the second time");
}

- (void)testSuspendResumeWorks
{
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __attribute__ ((objc_precise_lifetime, unused))
    BRUTimer *t = [BRUTimer scheduledTimerWithInterval:0.5
                                                 block:^(BRUTimer *t, NSDate *d) {
                                                     dispatch_semaphore_signal(sem);
                                                 }
                                               repeats:YES
                                        adjustInterval:nil];
    long timeout = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)));
    XCTAssertFalse(timeout, @"first timeout hit");
    [t suspend];
    /* because it shouldn't repeat we now wait for the timeout */
    timeout = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)));
    XCTAssertTrue(timeout, @"timeout did not hit the second time");
    [t resume];

    timeout = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)));
    XCTAssertFalse(timeout, @"third timeout hit");
}

- (void)testAlterIntervalWorks
{
    dispatch_queue_t q = bru_dispatch_queue_create("testQ", DISPATCH_QUEUE_SERIAL);
    NSMutableArray *a = [NSMutableArray arrayWithObject:[NSDate date]];
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __attribute__ ((objc_precise_lifetime, unused))
    BRUTimer *t = [BRUTimer scheduledTimerWithInterval:0.1
                                                 block:^(BRUTimer *tc, NSDate *d) {
                                                     [a addObject:d];
                                                     dispatch_semaphore_signal(sem);
                                                 }
                                               onQueue:q
                                               repeats:YES
                                        adjustInterval:^NSTimeInterval(BRUTimer *tLocl, NSTimeInterval curIv) {
                                            return curIv + 0.1;
                                        }];
    for (int i=0; i<5; i++) {
        long timeout = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)));
        XCTAssertFalse(timeout, @"first timeout hit");
    }
    dispatch_sync(q, ^{
        for (int i=1; i<5; i++) {
            XCTAssertTrue([a[i] timeIntervalSinceDate:a[i-1]] > 0.1*i,
                          @"interval %d too short: %f",
                          i,
                          [a[i] timeIntervalSinceDate:a[i-1]]);
        }
    });
}

- (void)testBlockingStuffDoesntBlockTimerInWallClockMode
{
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __attribute__ ((objc_precise_lifetime, unused))
    BRUTimer *t = [BRUTimer scheduledTimerWithInterval:0.1
                                                 block:^(BRUTimer *t, NSDate *d) {
                                                     dispatch_semaphore_signal(sem);
                                                     [NSThread sleepForTimeInterval:5];
                                                 }
                                               onQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
                                               repeats:YES
                                                  mode:BRUTimerModeIntervalClockedOnWallClockTime
                                        adjustInterval:nil];
    long timeout = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)));
    XCTAssertFalse(timeout, @"first timeout hit");
    timeout = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)));
    XCTAssertFalse(timeout, @"second timeout hit");
    [t suspend];
}

- (void)testBlockingStuffDoesBlockTimerInIntervalBetweenBlocksMode
{
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __attribute__ ((objc_precise_lifetime, unused))
    BRUTimer *t = [BRUTimer scheduledTimerWithInterval:0.1
                                                 block:^(BRUTimer *t, NSDate *d) {
                                                     dispatch_semaphore_signal(sem);
                                                     [NSThread sleepForTimeInterval:1.5];
                                                 }
                                               onQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
                                               repeats:YES
                                        adjustInterval:nil];
    long timeout = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)));
    XCTAssertFalse(timeout, @"first timeout hit");
    timeout = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)));
    XCTAssertTrue(!!timeout, @"second timeout did not hit");
    [t suspend];
}

- (void)testUnspecifiedQueueIsSerial
{
    dispatch_queue_t syncQ = bru_dispatch_queue_create("com.bromium.Test.SyncQ", DISPATCH_QUEUE_SERIAL);
    NSMutableArray *arr = [NSMutableArray new];
    __attribute__ ((objc_precise_lifetime, unused))
    BRUTimer *t = [BRUTimer scheduledTimerWithInterval:0.01
                                                 block:^(BRUTimer *t, NSDate *d) {
                                                     [NSThread sleepForTimeInterval:0.5];
                                                     dispatch_sync(syncQ, ^{
                                                         [arr addObject:d];
                                                     });
                                                 }
                                               onQueue:nil
                                               repeats:YES
                                                  mode:BRUTimerModeIntervalClockedOnWallClockTime
                                        adjustInterval:nil];
    [NSThread sleepForTimeInterval:1];
    __block NSArray *arrCopy = nil;
    dispatch_sync(syncQ, ^{
        arrCopy = [arr copy];
    });
    [t suspend];
    XCTAssertLessThan([arrCopy count], 5, @"put 5 or more elements in, that shouldn't be possible in that time");
}


- (void)testUnreachableTimerDoesntTick
{
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    {
        __attribute__ ((objc_precise_lifetime, unused))
        BRUTimer *t = [BRUTimer scheduledTimerWithInterval:0.5
                                                     block:^(BRUTimer *t, NSDate *d) {
                                                         dispatch_semaphore_signal(sem);
                                                     }
                                                   onQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
                                                   repeats:YES
                                            adjustInterval:nil];
    }
    long timeout = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)));
    XCTAssertTrue(timeout, @"timeout not hit, BRUTimer seems to retain itself");
}

- (void)testRestartCancelsPreviouslyRegisteredFireDates
{
    BRUConcurrentBox<BRUEitherErrorOrSuccess<NSDate *> *> *box = [BRUConcurrentBox emptyBox];
    BRUTimer *timer;
    timer = [[BRUTimer alloc] initWithInterval:1 block:^(BRUTimer *t, NSDate *d) {
        XCTAssertNotNil(d, @"date nil");
        XCTAssertNotNil(t, @"timer nil");
        [box put:[BRUEitherErrorOrSuccess newWithSuccessObject:d]];
    }
                                       onQueue:NULL
                                       repeats:NO
                                adjustInterval:^NSTimeInterval(BRUTimer *t, NSTimeInterval d) {
                                    return 1;
                                }];
    [timer start];
    [timer restart];
    [timer restart];
    BRUEitherErrorOrSuccess *firstTake = [BRUEitherErrorOrSuccess takeFromBox:box
                                                                timeoutAtDate:[NSDate dateWithTimeIntervalSinceNow:2]];
    XCTAssertNotNil(firstTake.object, @"tried to extract from box as a result of timer firing but got nothing");
    BRUEitherErrorOrSuccess *secondTake = [BRUEitherErrorOrSuccess takeFromBox:box
                                                                 timeoutAtDate:[NSDate dateWithTimeIntervalSinceNow:2]];
    XCTAssertNil(secondTake.object, @"tried to extract from box again, there shouldn't have been anything but got: %@",
                 secondTake.object);
}

- (void)testNonStartedTimerNeverFires
{
    BRUConcurrentBox<BRUEitherErrorOrSuccess<NSDate *> *> *box = [BRUConcurrentBox emptyBox];
    BRUTimer *timer = [[BRUTimer alloc] initWithInterval:0.1 block:^(BRUTimer *t, NSDate *d) {
        XCTAssertNotNil(d, @"date nil");
        XCTAssertNotNil(t, @"timer nil");
        [box put:[BRUEitherErrorOrSuccess newWithSuccessObject:d]];
    }
                                                 onQueue:NULL
                                                 repeats:YES
                                          adjustInterval:NULL];
    BRUEitherErrorOrSuccess *firstTake = [BRUEitherErrorOrSuccess takeFromBox:box
                                                                timeoutAtDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    XCTAssertNil(firstTake.object, @"timer fired but it was never started, got: %@", firstTake.object);
    XCTAssertTrue([NSPOSIXErrorDomain isEqualToString:firstTake.error.domain] && (ETIMEDOUT == firstTake.error.code),
                  @"wrong error, expected timeout");
    [timer description]; /* keep object alive and make it used */
}

- (void)testNonRepeatingTimerFiresOnlyOnce
{
    BRUConcurrentBox<BRUEitherErrorOrSuccess<NSDate *> *> *box = [BRUConcurrentBox emptyBox];
    BRUTimer *timer;
    timer = [[BRUTimer alloc] initWithInterval:0.0000000001 block:^(BRUTimer *t, NSDate *d) {
        XCTAssertNotNil(d, @"date nil");
        XCTAssertNotNil(t, @"timer nil");
        [box put:[BRUEitherErrorOrSuccess newWithSuccessObject:d]];
    }
                                       onQueue:NULL
                                       repeats:NO
                                adjustInterval:NULL];
    [timer start];
    BRUEitherErrorOrSuccess *firstTake = [BRUEitherErrorOrSuccess takeFromBox:box
                                                                timeoutAtDate:[NSDate dateWithTimeIntervalSinceNow:2]];
    XCTAssertNotNil(firstTake.object, @"tried to extract from box as a result of timer firing but got nothing");
    BRUEitherErrorOrSuccess *sndTake = [BRUEitherErrorOrSuccess takeFromBox:box
                                                              timeoutAtDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertNil(sndTake.object, @"tried to extract from box again, there shouldn't have been anything but got: %@",
                 sndTake.object);
}

- (void)testTimerSuspendWorks
{
    BRUConcurrentBox<BRUEitherErrorOrSuccess<NSDate *> *> *box = [BRUConcurrentBox emptyBox];
    BRUTimer *timer;
    timer = [[BRUTimer alloc] initWithInterval:1 block:^(BRUTimer *t, NSDate *d) {
        XCTAssertNotNil(d, @"date nil");
        XCTAssertNotNil(t, @"timer nil");
        [box put:[BRUEitherErrorOrSuccess newWithSuccessObject:d]];
    }
                                       onQueue:NULL
                                       repeats:NO
                                adjustInterval:NULL];
    [timer start];
    [timer suspend];
    BRUEitherErrorOrSuccess *firstTake = [BRUEitherErrorOrSuccess takeFromBox:box
                                                                timeoutAtDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    XCTAssertNil(firstTake.object, @"expected nil, got %@", firstTake.object);
}

- (void)testTimerNastyFireAndSuspendWithinAdjustInterval
{
    BRUConcurrentBox<BRUEitherErrorOrSuccess<NSDate *> *> *box = [BRUConcurrentBox emptyBox];
    BRUTimer *timer;
    timer = [[BRUTimer alloc] initWithInterval:0.1 block:^(BRUTimer *t, NSDate *d) {
        XCTAssertNotNil(d, @"date nil");
        XCTAssertNotNil(t, @"timer nil");
        [box put:[BRUEitherErrorOrSuccess newWithSuccessObject:d]];
    }
                                       onQueue:NULL
                                       repeats:YES
                                adjustInterval:^NSTimeInterval(BRUTimer *t, NSTimeInterval d) {
                                    [t fire];
                                    [t suspend];
                                    return d;
                                }];
    [timer start];
    BRUEitherErrorOrSuccess *firstTake = [BRUEitherErrorOrSuccess takeFromBox:box
                                                                timeoutAtDate:[NSDate dateWithTimeIntervalSinceNow:2]];
    XCTAssertNotNil(firstTake.object, @"tried to extract from box as a result of timer firing but got nothing");
    BRUEitherErrorOrSuccess *sndTake = [BRUEitherErrorOrSuccess takeFromBox:box
                                                              timeoutAtDate:[NSDate dateWithTimeIntervalSinceNow:2]];
    XCTAssertNotNil(sndTake.object, @"tried to extract from box as a result of timer firing but got nothing");
    BRUEitherErrorOrSuccess *trdTake = [BRUEitherErrorOrSuccess takeFromBox:box
                                                              timeoutAtDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertNil(trdTake.object, @"extracted %@ from box but expected nothing", trdTake.object);

}

- (void)testTimerNastyFireAndSuspendWithinFire
{
    dispatch_queue_t serialQ = bru_dispatch_queue_create("some-test-q", DISPATCH_QUEUE_SERIAL);
    BRUConcurrentBox<BRUEitherErrorOrSuccess<NSDate *> *> *box = [BRUConcurrentBox emptyBox];
    BRUTimer *timer;
    timer = [[BRUTimer alloc] initWithInterval:0.1 block:^(BRUTimer *t, NSDate *d) {
        static int no = 0;
        XCTAssertNotNil(d, @"date nil");
        XCTAssertNotNil(t, @"timer nil");
        [box put:[BRUEitherErrorOrSuccess newWithSuccessObject:d]];
        if (0 == no) {
            [t fire];
            [t suspend];
            no++;
        }
    }
                                       onQueue:serialQ
                                       repeats:YES
                                adjustInterval:NULL];
    [timer start];
    BRUEitherErrorOrSuccess *firstTake = [BRUEitherErrorOrSuccess takeFromBox:box
                                                                timeoutAtDate:[NSDate dateWithTimeIntervalSinceNow:2]];
    XCTAssertNotNil(firstTake.object, @"tried to extract from box as a result of timer firing but got nothing");
    BRUEitherErrorOrSuccess *sndTake = [BRUEitherErrorOrSuccess takeFromBox:box
                                                              timeoutAtDate:[NSDate dateWithTimeIntervalSinceNow:2]];
    XCTAssertNotNil(sndTake.object, @"tried to extract from box as a result of timer firing but got nothing");
    BRUEitherErrorOrSuccess *trdTake = [BRUEitherErrorOrSuccess takeFromBox:box
                                                              timeoutAtDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertNil(trdTake.object, @"extracted %@ from box but expected nothing", trdTake.object);
}

- (void)testTimerRestartWithNewInterval
{
    dispatch_queue_t serialQ = bru_dispatch_queue_create("some-test-q", DISPATCH_QUEUE_SERIAL);
    BRUConcurrentBox<BRUEitherErrorOrSuccess<NSDate *> *> *box = [BRUConcurrentBox emptyBox];
    BRUTimer *timer = [[BRUTimer alloc] initWithInterval:123456789.0 block:^(BRUTimer *t, NSDate *d) {
        XCTAssertNotNil(d, @"date nil");
        XCTAssertNotNil(t, @"timer nil");
        [box put:[BRUEitherErrorOrSuccess newWithSuccessObject:d]];
    }
                                                 onQueue:serialQ
                                                 repeats:YES
                                          adjustInterval:NULL];
    [timer start];
    /* the initial interval will never fire, so reset it now */
    [timer restartWithInterval:0.01];
    BRUEitherErrorOrSuccess<NSDate *> *mSuc = [box tryTakeUntil:[NSDate dateWithTimeIntervalSinceNow:10]];
    XCTAssertNotNil(mSuc.object, @"restarted timer didn't fire 1st time in 10s");
    mSuc = [box tryTakeUntil:[NSDate dateWithTimeIntervalSinceNow:10]];
    XCTAssertNotNil(mSuc.object, @"restarted timer didn't fire 2nd time in 10s");
    mSuc = [box tryTakeUntil:[NSDate dateWithTimeIntervalSinceNow:10]];
    XCTAssertNotNil(mSuc.object, @"restarted timer didn't fire 3rd time in 10s");
}

- (void)testTimerRestartWithNewIntervalWorksAndResetSetsItBackToOriginal
{
    dispatch_queue_t serialQ = bru_dispatch_queue_create("some-test-q", DISPATCH_QUEUE_SERIAL);
    BRUConcurrentBox<BRUEitherErrorOrSuccess<NSDate *> *> *box = [BRUConcurrentBox emptyBox];
    BRUTimer *timer = [[BRUTimer alloc] initWithInterval:123456789.0 block:^(BRUTimer *t, NSDate *d) {
        NSLog(@"fire");
        XCTAssertNotNil(d, @"date nil");
        XCTAssertNotNil(t, @"timer nil");
        [box put:[BRUEitherErrorOrSuccess newWithSuccessObject:d]];
        [t restart]; /* this causes us to reset it back to the original (very long) interval */
    }
                                                 onQueue:serialQ
                                                 repeats:YES
                                          adjustInterval:NULL];
    [timer start];
    /* the initial interval will never fire, so reset it now */
    [timer restartWithInterval:0.01];
    BRUEitherErrorOrSuccess<NSDate *> *mSuc = [box tryTakeUntil:[NSDate dateWithTimeIntervalSinceNow:10]];
    XCTAssertNotNil(mSuc.object, @"restarted timer didn't fire time in 10s");
    mSuc = [box tryTakeUntil:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    XCTAssertFalse(mSuc.success, @"timer fired again but it really shouldn't have");
}


@end
