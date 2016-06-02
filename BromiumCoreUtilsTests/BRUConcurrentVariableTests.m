//
//  BRUConcurrentVariableTests.m
//  BromiumUtils
//
//  Created by Johannes Weiß on 25/03/2015.
//  Copyright (c) 2015 Bromium UK Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

#import "BRUConcurrentVariable.h"

@interface BRUConcurrentVariableTests : XCTestCase

@end

@implementation BRUConcurrentVariableTests

- (void)testBRUCVSimpleSetGet
{
    NSObject *o = [[NSObject alloc] init];
    BRUConcurrentVariable<NSObject *> *cv = [BRUConcurrentVariable newWithValue:o];
    XCTAssertEqual(o, [cv readVariable]);
}

- (void)testBRUCVSimpleSetGetTwice
{
    NSObject *o = [[NSObject alloc] init];
    BRUConcurrentVariable<NSObject *> *cv = [BRUConcurrentVariable newWithValue:o];
    XCTAssertEqual(o, [cv readVariable]);
    XCTAssertEqual(o, [cv readVariable]);
}

- (void)testBRUCVSimpleOverwrite
{
    NSObject *o1 = [[NSObject alloc] init];
    NSObject *o2 = [[NSObject alloc] init];
    BRUConcurrentVariable<NSObject *> *cv = [BRUConcurrentVariable newWithValue:o1];
    XCTAssertEqual(o1, [cv readVariable]);
    [cv writeVariableWithValue:o2];
    XCTAssertEqual(o2, [cv readVariable]);
}

- (void)testBRUCVSimpleModify
{
    NSObject *o1 = [[NSObject alloc] init];
    NSObject *o2 = [[NSObject alloc] init];
    BRUConcurrentVariable<NSObject *> *cv = [BRUConcurrentVariable newWithValue:o1];
    XCTAssertEqual(o1, [cv readVariable]);
    id expectO1asWell = [cv modifyVariableWithBlock:^id  (id __nonnull expectO1) {
        XCTAssertEqual(o1, expectO1);
        return o2;
    }];
    XCTAssertEqual(o1, expectO1asWell);
    XCTAssertEqual(o2, [cv readVariable]);
}


- (void)testBRUCVSimpleSwap
{
    NSObject *o1 = [[NSObject alloc] init];
    NSObject *o2 = [[NSObject alloc] init];
    BRUConcurrentVariable<NSObject *> *cv = [BRUConcurrentVariable newWithValue:o1];
    XCTAssertEqual(o1, [cv readVariable]);
    id expectO1 = [cv swapVariableWithValue:o2];
    XCTAssertEqual(o1, expectO1);
    XCTAssertEqual(o2, [cv readVariable]);
}


- (void)testBRUCVSwapWorks
{
    /* This implements normal locks ontop of BRUConcurrentVariable */
    const NSUInteger count = 1000;
    BRUConcurrentVariable<NSNumber *> *var = [BRUConcurrentVariable newWithValue:@0];
    NSMutableSet *actual = [NSMutableSet setWithCapacity:count];
    NSMutableSet *expected = [NSMutableSet setWithCapacity:count];
    dispatch_group_t dispatchGroup = dispatch_group_create();
    for (NSUInteger i=1; i<count; i++) {
        [expected addObject:@(i)];
        dispatch_group_async(dispatchGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSNumber *myNumber = @(i);
            while (YES) {
                NSNumber *o = [var swapVariableWithValue:myNumber];
                XCTAssertTrue(o != nil, @"got nil from swap");
                if ([o isEqualToNumber:@0]) {
                    /* Got Lock */
                    [actual addObject:myNumber]; /* works because it should be locked if BRUConcurrentVariable works */
                    /* Now hand lock back */
                    NSNumber *o2 = [var swapVariableWithValue:@0];
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
    XCTAssertEqualObjects(expected, actual, @"got wrong objects out of variable");
}

@end
