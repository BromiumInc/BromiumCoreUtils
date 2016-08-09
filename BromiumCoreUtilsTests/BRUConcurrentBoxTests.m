//
//  Copyright (C) 2013-2016, Bromium Inc.
//
//  This software may be modified and distributed under the terms
//  of the BSD license.  See the LICENSE file for details.
//
//  Created by Johannes Weiß on 31/05/2016.
//

#import <XCTest/XCTest.h>

#import "BRUDispatchUtils.h"
#import "BRUConcurrentBox.h"

@interface BRUConcurrentBoxTests : XCTestCase

@end

@implementation BRUConcurrentBoxTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}
- (void)testConcurrentBoxTrivialEmpty
{
    BRUConcurrentBox<NSObject *> *box = [BRUConcurrentBox emptyBox];
    XCTAssertTrue(box.isEmpty, @"empty box not empty");
}

- (void)testConcurrentBoxTrivialFull
{
    BRUConcurrentBox<NSString *> *box = [BRUConcurrentBox boxWithValue:@""];
    XCTAssertTrue(!box.isEmpty, @"full box not full");
}

- (void)testConcurrentBoxTakeOut
{
    NSString *expected = @"";
    BRUConcurrentBox<NSString *> *box = [BRUConcurrentBox boxWithValue:expected];
    XCTAssertTrue(!box.isEmpty, @"full box not full");
    NSString *actual = [box take];
    XCTAssertTrue(box.isEmpty, @"box not empty after taking out");
    XCTAssertEqual(expected, actual, @"got wrong object out of box");
}

- (void)testConcurrentBoxTryTakeSucceeds
{
    NSString *expected = @"";
    BRUConcurrentBox<NSString *> *box = [BRUConcurrentBox boxWithValue:expected];
    XCTAssertTrue(!box.isEmpty, @"full box not full");
    NSString *actual = [box tryTake];
    XCTAssertTrue(box.isEmpty, @"box not empty after taking out");
    XCTAssertEqual(expected, actual, @"got wrong object out of box");
}

- (void)testConcurrentBoxTryTakeCanFail
{
    NSString *expected = @"";
    BRUConcurrentBox<NSString *> *box = [BRUConcurrentBox boxWithValue:expected];
    XCTAssertTrue(!box.isEmpty, @"full box not full");
    NSString *actual = [box tryTake];
    XCTAssertTrue(box.isEmpty, @"box not empty after taking out");
    XCTAssertEqual(expected, actual, @"got wrong object out of box");
    NSString *shouldBeNil = [box tryTake];
    XCTAssertTrue(box.isEmpty, @"box not empty after taking out");
    XCTAssertTrue(nil == shouldBeNil, @"try take wrong");
}

- (void)testConcurrentBoxPutWorks
{
    NSString *expected = @"";
    BRUConcurrentBox<NSString *> *box = [BRUConcurrentBox emptyBox];
    XCTAssertTrue(box.isEmpty, @"empty box not empty");
    [box put:expected];
    XCTAssertTrue(!box.isEmpty, @"put didn't work");
    NSString *actual = [box tryTake];
    XCTAssertTrue(box.isEmpty, @"box not empty after taking out");
    XCTAssertEqual(expected, actual, @"got wrong object out of box");
}

- (void)testConcurrentBoxTryPutFailsOnFullBox
{
    NSString *expected = @"";
    BRUConcurrentBox<NSString *> *box = [BRUConcurrentBox emptyBox];
    XCTAssertTrue(box.isEmpty, @"empty box not empty");
    [box put:expected];
    XCTAssertTrue(!box.isEmpty, @"put didn't work");
    BOOL success = [box tryPut:@""];
    XCTAssertFalse(success, @"tryPut succeeded on full box");
    NSString *actual = [box tryTake];
    XCTAssertTrue(box.isEmpty, @"box not empty after taking out");
    XCTAssertEqual(expected, actual, @"got wrong object out of box");
}

- (void)testConcurrentBoxTryPutSucceedsOnEmptyBox
{
    NSString *expected = @"";
    BRUConcurrentBox<NSString *> *box = [BRUConcurrentBox emptyBox];
    XCTAssertTrue(box.isEmpty, @"empty box not empty");
    BOOL success = [box tryPut:@""];
    XCTAssertTrue(success, @"tryPut failed on empty box");
    NSString *actual = [box tryTake];
    XCTAssertTrue(box.isEmpty, @"box not empty after taking out");
    XCTAssertEqual(expected, actual, @"got wrong object out of box");
}

- (void)testConcurrentBoxWorksWithOtherThreadPutting
{
    NSString *expected = @"";
    BRUConcurrentBox<NSString *> *box = [BRUConcurrentBox emptyBox];
    XCTAssertTrue(box.isEmpty, @"empty box not empty");
    double delayInSeconds = 2.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        XCTAssertTrue(box.isEmpty, @"empty box not empty");
        [box put:expected];
    });
    NSString *actual = [box take];
    XCTAssertTrue(box.isEmpty, @"box not empty after taking out");
    XCTAssertEqual(expected, actual, @"got wrong object out of box");
}

- (void)testConcurrentBoxTakeWithTimeoutWorks
{
    NSString *expected = @"";
    BRUConcurrentBox<NSString *> *box = [BRUConcurrentBox emptyBox];
    XCTAssertTrue(box.isEmpty, @"empty box not empty");
    double delayInSeconds = 2.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        XCTAssertTrue(box.isEmpty, @"empty box not empty");
        [box put:expected];
    });
    NSString *actual = [box tryTakeUntil:[NSDate distantPast]];
    XCTAssertTrue(box.isEmpty, @"box not empty after taking out");
    XCTAssertTrue(nil == actual, @"got object out of the box, expected nil");
}

- (void)testConcurrentBoxWorksWithLoadsOfObjectsPutting
{
    const NSUInteger count = 100;
    BRUConcurrentBox<NSNumber *> *box = [BRUConcurrentBox emptyBox];
    XCTAssertTrue(box.isEmpty, @"empty box not empty");
    double delayInSeconds = 2.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        for (int i=0; i<count; i++) {
            [box put:@(i)];
        }
    });
    for (int i=0; i<count; i++) {
        NSNumber *actual = [box tryTakeUntil:[[NSDate alloc] initWithTimeIntervalSinceNow:3]];
        XCTAssertEqualObjects(@(i), actual, @"got wrong object out of box");
    }
}

- (void)testConcurrentBoxWorksWithLoadsOfThreadsAndObjectsPutting
{
    const NSUInteger count = 1000;
    BRUConcurrentBox<NSNumber *> *box = [BRUConcurrentBox emptyBox];
    XCTAssertTrue(box.isEmpty, @"empty box not empty");
    for (int i=0; i<count; i++) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [box put:@(i)];
        });
    }
    NSMutableSet<NSNumber *> *actual = [NSMutableSet setWithCapacity:count];
    NSMutableSet<NSNumber *> *expected = [NSMutableSet setWithCapacity:count];
    for (int i=0; i<count; i++) {
        [expected addObject:@(i)];
        NSNumber *o = [box tryTakeUntil:[[NSDate alloc] initWithTimeIntervalSinceNow:5]];
        XCTAssertNotNil(o, @"got nil object");
        [actual addObject:o];
    }
    XCTAssertEqualObjects(expected, actual, @"got wrong objects out of box");
}

- (void)testConcurrentBoxWorksWithLoadsOfThreadsAndObjectsPuttingAndTaking
{
    const NSUInteger count = 1000;
    BRUConcurrentBox<NSNumber *> *box = [BRUConcurrentBox emptyBox];
    dispatch_queue_t putQueue = bru_dispatch_queue_create("com.bromium.test.putQueue", DISPATCH_QUEUE_CONCURRENT);
    dispatch_queue_t takeQueue = bru_dispatch_queue_create("com.bromium.test.takeQueue", DISPATCH_QUEUE_CONCURRENT);
    dispatch_queue_t syncQueue = bru_dispatch_queue_create("com.bromium.test.syncQueue", DISPATCH_QUEUE_SERIAL);
    XCTAssertTrue(box.isEmpty, @"empty box not empty");
    NSMutableSet<NSNumber *> *actual = [NSMutableSet setWithCapacity:count];
    NSMutableSet<NSNumber *> *expected = [NSMutableSet setWithCapacity:count];
    dispatch_group_t dispatchGroup = dispatch_group_create();
    for (int i=0; i<count; i++) {
        [expected addObject:@(i)];
        dispatch_async(putQueue, ^{
            [box put:@(i)];
        });
        dispatch_group_async(dispatchGroup, takeQueue, ^{
            NSNumber *o = [box tryTakeUntil:[[NSDate alloc] initWithTimeIntervalSinceNow:60]];
            if (o) {
                dispatch_sync(syncQueue, ^{
                    [actual addObject:o];
                });
            }
        });
    }
    long success = dispatch_group_wait(dispatchGroup, dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC));
    XCTAssertTrue(0 == success, @"wait timed out");
    XCTAssertEqualObjects(expected, actual, @"got wrong objects out of box");
}

- (void)testConcurrentBoxSwapWorks
{
    /* This implements normal locks ontop of BRUConcurrentBox */
    const NSUInteger count = 1000;
    BRUConcurrentBox<NSNumber *> *box = [BRUConcurrentBox boxWithValue:@0];
    NSMutableSet<NSNumber *> *actual = [NSMutableSet setWithCapacity:count];
    NSMutableSet<NSNumber *> *expected = [NSMutableSet setWithCapacity:count];
    dispatch_group_t dispatchGroup = dispatch_group_create();
    for (NSUInteger i=1; i<count; i++) {
        [expected addObject:@(i)];
        dispatch_group_async(dispatchGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSNumber *myNumber = @(i);
            while (YES) {
                NSNumber *o = [box swapWithValue:myNumber];
                XCTAssertTrue(o != nil, @"got nil from swap");
                if ([o isEqualToNumber:@0]) {
                    /* Got Lock */
                    [actual addObject:myNumber]; /* works because it should be locked if BRUConcurrentBox works */
                    /* Now hand lock back */
                    NSNumber *o2 = [box swapWithValue:@0];
                    XCTAssertTrue(o2 != nil, @"got nil from swap (hand back)");
                    XCTAssertFalse([o2 isEqualToNumber:@0], @"got lock while releasing");
                    break;
                } else {
                    /* Try again (aka yield) */
                    [NSThread sleepForTimeInterval:0.1];
                }
            }
        });
    }
    long success = dispatch_group_wait(dispatchGroup, dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC));
    XCTAssertTrue(0 == success, @"wait timed out");
    XCTAssertEqualObjects(expected, actual, @"got wrong objects out of box");
}

- (void)testTrySwapReturnsNilForEmptyBox
{
    BRUConcurrentBox<NSNull *> *box = [BRUConcurrentBox emptyBox];
    XCTAssertNil([box trySwapWithValue:[NSNull null]], @"trySwap of empty box didn't return nil");
}

- (void)testTrySwapReturnsObjectForFullBox
{
    NSObject *o = [NSObject new];
    BRUConcurrentBox<NSObject *> *box = [BRUConcurrentBox emptyBox];
    [box put:o];
    XCTAssertEqualObjects(o, [box trySwapWithValue:[NSObject new]], @"trySwap of full box didn't return correct object");
}

- (void)testConcurrentBoxTrySwapWorks
{
    /* this implements a fast producer and a consumer which is supposed to drop values when not needed.
     To make it deterministic, the producer and the consumer are slowed down artificially. The consumer
     should exactly see every tenth number the producer produces. */
    const int maxNum = 100000;
    NSMutableArray<NSNumber *> *expectedNumbers = [NSMutableArray new];
    NSMutableArray<NSNumber *> *seenNumbers = [NSMutableArray new];
    dispatch_semaphore_t slowDownConsumerSem = dispatch_semaphore_create(0);
    dispatch_semaphore_t slowDownProducerSem = dispatch_semaphore_create(0);
    dispatch_semaphore_t readySem = dispatch_semaphore_create(0);
    BRUConcurrentBox<NSNumber *> *box = [BRUConcurrentBox emptyBox];
    dispatch_queue_t otherQ = bru_dispatch_queue_create("otherQ", DISPATCH_QUEUE_SERIAL);
    for (int i=1; i<=maxNum; i++) {
        if (![box trySwapWithValue:@(i)]) {
            dispatch_async(otherQ, ^{
                dispatch_semaphore_wait(slowDownConsumerSem, DISPATCH_TIME_FOREVER);
                NSNumber *o = [box take];
                [seenNumbers addObject:o];
                dispatch_semaphore_signal(slowDownProducerSem);
                if ([o integerValue] == maxNum) {
                    dispatch_semaphore_signal(readySem);
                }
            });
        }
        if (0 == i % 10) {
            [expectedNumbers addObject:@(i)];
            dispatch_semaphore_signal(slowDownConsumerSem);
            dispatch_semaphore_wait(slowDownProducerSem, DISPATCH_TIME_FOREVER);
        }
    }
    dispatch_semaphore_wait(readySem, DISPATCH_TIME_FOREVER);
    XCTAssertEqualObjects(expectedNumbers, seenNumbers, @"seenNumbers not the expected ones: %@ vs %@",
                          seenNumbers, expectedNumbers);
}

@end
