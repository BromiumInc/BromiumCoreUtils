//
//  BRUDeferredTests.m
//  BromiumUtils
//
//  Created by Michael Dales on 19/03/2015.
//  Copyright (c) 2015 Bromium UK Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

#import <BRUDispatchUtils.h>
#import <BRUDeferred.h>

#define TEST_SEMAPHORE_WAIT_SUCCESS(_x,_msg) { /*
*/  long rv = dispatch_semaphore_wait(_x, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC))); /*
*/  XCTAssertEqual(rv, (long)0, _msg); /*
*/}

#define TEST_SEMAPHORE_WAIT_FAIL(_x,_msg) { /*
*/  long rv = dispatch_semaphore_wait(_x, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC))); /*
*/  XCTAssertNotEqual(rv, (long)0, _msg); /*
*/}

@interface BRUDeferredTests : XCTestCase

@end


@implementation BRUDeferredTests

- (void)testCreateAndImmediateResolveWithValue
{
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    BRUDeferred *deferred = [[BRUDeferred alloc] init];
    [deferred resolve:@"hello"];

    id<BRUPromise> promise = [deferred promise];
    [promise then:^(NSString *val) {
        XCTAssertNotNil(val, @"Expected value");
        XCTAssertTrue([val isEqualToString:@"hello"], @"Failed to get expected value contents");
        dispatch_semaphore_signal(sem);
    }];

    TEST_SEMAPHORE_WAIT_SUCCESS(sem, @"Failed to get value");
}

- (void)testCreateAndDeferredResolveWithValue
{
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    BRUDeferred *deferred = [[BRUDeferred alloc] init];

    id<BRUPromise> promise = [deferred promise];
    [promise then:^(NSString *val) {
        XCTAssertNotNil(val, @"Expected value");
        XCTAssertTrue([val isEqualToString:@"hello"], @"Failed to get expected value contents");
        dispatch_semaphore_signal(sem);
    }];

    TEST_SEMAPHORE_WAIT_FAIL(sem, @"Failed to get value");
    [deferred resolve:@"hello"];

    TEST_SEMAPHORE_WAIT_SUCCESS(sem, @"Failed to get value");
}

- (void)testCreateAndImmediateResolveWithValueWithNil
{
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    BRUDeferred *deferred = [[BRUDeferred alloc] init];
    [deferred resolve:nil];

    id<BRUPromise> promise = [deferred promise];
    [promise then:^(NSString *val) {
        XCTAssertNil(val, @"Expected value");
        dispatch_semaphore_signal(sem);
    }];

    TEST_SEMAPHORE_WAIT_SUCCESS(sem, @"Failed to get value");
}

- (void)testCreateAndDeferredResolveWihtNil
{
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    BRUDeferred *deferred = [[BRUDeferred alloc] init];

    id<BRUPromise> promise = [deferred promise];
    [promise then:^(NSString *val) {
        XCTAssertNil(val, @"Expected value");
        dispatch_semaphore_signal(sem);
    }];

    TEST_SEMAPHORE_WAIT_FAIL(sem, @"Failed to get value");
    [deferred resolve:nil];

    TEST_SEMAPHORE_WAIT_SUCCESS(sem, @"Failed to get value");
}

- (void)testCreateAndMultipleDeferredResolveWithValue
{
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    BRUDeferred *deferred = [[BRUDeferred alloc] init];

    id<BRUPromise> promise = [deferred promise];
    for (int i = 0; i < 10; i++) {
        [promise then:^(NSString *val) {
            XCTAssertNotNil(val, @"Expected value");
            XCTAssertTrue([val isEqualToString:@"hello"], @"Failed to get expected value contents");
            dispatch_semaphore_signal(sem);
        }];
    }

    TEST_SEMAPHORE_WAIT_FAIL(sem, @"Failed to get value");
    [deferred resolve:@"hello"];

    for (int i = 0; i < 10; i++) {
        TEST_SEMAPHORE_WAIT_SUCCESS(sem, @"Failed to get value");
    }
}

- (void)testResolveWhenOutOfScope
{
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    @autoreleasepool {
        __attribute__((objc_precise_lifetime)) BRUDeferred *deferred = [BRUDeferred deferred];
        [[deferred promise] then:^(NSString *result) {
            XCTAssertEqual(result, @"cheese");
            dispatch_semaphore_signal(sem);
        }];
        [deferred resolve:@"cheese"];
    }

    TEST_SEMAPHORE_WAIT_SUCCESS(sem, @"Failed to get value");
}

- (void)testResolveWhenOutOfScopeTargetQueue
{
    dispatch_queue_t queue = bru_dispatch_queue_create("com.bromium.BromiumUtilsTests.BRUDeferredTests.queue",
                                                       DISPATCH_QUEUE_SERIAL);
    dispatch_suspend(queue);

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    @autoreleasepool {
        __attribute__((objc_precise_lifetime)) BRUDeferred *deferred = [BRUDeferred deferredWithTargetQueue:queue];
        [[deferred promise] then:^(NSString *result) {
            XCTAssertEqual(result, @"cheese");
            dispatch_semaphore_signal(sem);
        }];
        [deferred resolve:@"cheese"];
    }

    dispatch_resume(queue);

    TEST_SEMAPHORE_WAIT_SUCCESS(sem, @"Failed to get value");
}

@end
