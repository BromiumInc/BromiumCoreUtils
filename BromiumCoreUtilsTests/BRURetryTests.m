//
//  Copyright (C) 2013-2016, Bromium Inc.
//
//  This software may be modified and distributed under the terms
//  of the BSD license.  See the LICENSE file for details.
//
//  Created by Jason Morley on 10/04/2015.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

#import "BRUAsserts.h"
#import "BRUDispatchUtils.h"
#import "BRURetry.h"

/**
 * The time after which an asynchronous action will complete.
 */
static NSTimeInterval BRURetryTestsAsyncActionTimeInterval = 0.02;

static NSTimeInterval BRURetryTestsInitialDelayTimeInterval = 0.02;
static NSTimeInterval BRURetryTestsDelayTimeInterval = 0.01;

static NSUInteger BRURetryResultNever = NSUIntegerMax;

@interface BRURetryTests : XCTestCase

@end

typedef void (^BRURetryTestsCompletionBlock)(void);

@implementation BRURetryTests

+ (void)performSoakTest:(void (^)(void))actionBlock
{
    for (int i=0; i<100; i++) {
        actionBlock();
    }
}

+ (BRURetry *)retryWithActionBlock:(BRURetryActionBlock)actionBlock
                       policyBlock:(BRURetryPolicyBlock)policyBlock
                       targetQueue:(dispatch_queue_t)targetQueue
{
    return [[BRURetry alloc] initWithActionBlock:actionBlock
                                     policyBlock:policyBlock
                                           delay:BRURetryTestsInitialDelayTimeInterval
                                     targetQueue:targetQueue];
}

- (BRURetry *)retryWithActionBlock:(BRURetryActionBlock)actionBlock
                           retries:(NSUInteger)retries
                       targetQueue:(dispatch_queue_t)targetQueue
{
    return [BRURetryTests retryWithActionBlock:actionBlock
                                   policyBlock:[self policyBlockWithRetries:retries]
                                   targetQueue:targetQueue];
}

+ (NSInteger)defaultErrorCode
{
    return EACCES;
}

+ (NSError *)defaultError
{
    return [NSError errorWithDomain:NSPOSIXErrorDomain code:[self defaultErrorCode] userInfo:@{}];
}

+ (NSInteger)transientErrorCode
{
    return EAGAIN;
}

+ (NSError *)transientError
{
    return [NSError errorWithDomain:NSPOSIXErrorDomain code:[self transientErrorCode] userInfo:@{}];
}

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)waitOnSemaphore:(dispatch_semaphore_t)semaphore
{
    long success = dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 60.0));
    XCTAssert(success == 0, "Semaphore timed out during test");
}


- (void)dispatchBlocking:(void (^)(dispatch_queue_t currentQueue, BRURetryTestsCompletionBlock completionBlock))block
{
    dispatch_semaphore_t completionSem = dispatch_semaphore_create(0);
    dispatch_queue_t targetQueue = bru_dispatch_queue_create("com.bromium.BromiumUtils.BRURetryTests.targetQueue",
                                                             DISPATCH_QUEUE_SERIAL);
    dispatch_async(targetQueue, ^{
        block(targetQueue, ^{
            dispatch_semaphore_signal(completionSem);
        });
    });
    long success = dispatch_semaphore_wait(completionSem, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 60.0));
    XCTAssert(success == 0, "Semaphore timed out during test");
}

- (BRURetryActionBlock)actionBlockWithResult:(BOOL)result error:(NSError *)error onAttempt:(NSUInteger)attempt
{
    __block NSUInteger try = 0;
    BRURetryActionBlock action = ^(BRURetryContinuationBlock continuationBlock) {

        try++;

        if (try < attempt || attempt == BRURetryResultNever) {

            continuationBlock(NO, [BRURetryTests transientError], BRURetryStatusTransient);

        } else if (try == attempt) {

            continuationBlock(result, error, BRURetryStatusFinal);

        } else {

            XCTAssert(NO, @"Action block called too many times (%lu).", (unsigned long)try);

        }
    };
    return action;
}

- (BRURetryActionBlock)actionBlockWithSuccessOnAttempt:(NSUInteger)attempt
{
    return [self actionBlockWithResult:YES error:nil onAttempt:attempt];
}

- (BRURetryActionBlock)actionBlockWithFailureOnAttempt:(NSUInteger)attempt
{
    return [self actionBlockWithResult:NO
                                 error:[BRURetryTests defaultError]
                             onAttempt:attempt];
}

- (BRURetryActionBlock)asyncActionBlockWithActionBlock:(BRURetryActionBlock)actionBlock
                                         dispatchQueue:(dispatch_queue_t)dispatchQueue
                                                 delay:(NSTimeInterval)delay
{
    BRURetryActionBlock action = ^(BRURetryContinuationBlock continuationBlock) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatchQueue, ^{
            actionBlock(continuationBlock);
        });
    };
    return action;
}

- (BRURetryActionBlock)asyncActionBlockWithActionBlock:(BRURetryActionBlock)actionBlock
                                                 delay:(NSTimeInterval)delay
{
    return [self asyncActionBlockWithActionBlock:actionBlock
                                   dispatchQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
                                           delay:delay];
}


- (BRURetryActionBlock)asyncActionBlockWithActionBlock:(BRURetryActionBlock)actionBlock
{
    return [self asyncActionBlockWithActionBlock:actionBlock
                                   dispatchQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
                                           delay:BRURetryTestsAsyncActionTimeInterval];
}

- (BRURetryCompletionBlock)completionBlockWithSuccess:(BOOL)success
                                            errorCode:(NSInteger)errorCode
                                      completionBlock:(BRURetryTestsCompletionBlock)completion
{
    BRURetryCompletionBlock completionBlock = ^(BOOL s, NSError *e) {

        XCTAssertEqual(s, success);
        if (errorCode) {
            XCTAssertEqual(e.code, errorCode);
        } else {
            XCTAssertNil(e);
        }

        completion();
    };
    return completionBlock;
}

- (BRURetryCompletionBlock)completionBlockWithSuccessAndCompletionBlock:(BRURetryTestsCompletionBlock)completionBlock
{
    return [self completionBlockWithSuccess:YES errorCode:0 completionBlock:completionBlock];
}

- (BRURetryCompletionBlock)completionBlockWithFailureAndCompletionBlock:(BRURetryTestsCompletionBlock)completionBlock
{
    return [self completionBlockWithSuccess:NO
                                  errorCode:[BRURetryTests defaultErrorCode]
                            completionBlock:completionBlock];
}

- (BRURetryCompletionBlock)completionBlockWithTransientFailureAndCompletionBlock:(BRURetryTestsCompletionBlock)completionBlock
{
    return [self completionBlockWithSuccess:NO
                                  errorCode:[BRURetryTests transientErrorCode]
                            completionBlock:completionBlock];
}

- (BRURetryCompletionBlock)completionBlockWithCancellationAndCompletionBlock:(BRURetryTestsCompletionBlock)completionBlock
{
    return [self completionBlockWithSuccess:NO errorCode:ECANCELED completionBlock:completionBlock];
}

- (BRURetryPolicyBlock)policyBlockWithRetries:(NSUInteger)retries
{
    __block NSUInteger callback = 0;
    return ^BRURetryPolicyResponse (NSError *e, NSUInteger a, NSTimeInterval *d) {

        callback++;
        XCTAssertEqual(a, callback);

        if (a <= retries || retries == BRURetryResultNever) {

            XCTAssertNotNil(e);
            XCTAssertEqualObjects(e, [BRURetryTests transientError]);
            XCTAssert(d);

            *d = BRURetryTestsDelayTimeInterval;

        } else {

            XCTFail(@"Result block called too many times (%lu)", (unsigned long)a);

        }

        return BRURetryPolicyResponseRetry;

    };
}

- (BRURetryPolicyBlock)resultBlockWithEarlyTerminationOnAttempt:(NSUInteger)attempt
                                                completionBlock:(BRURetryTestsCompletionBlock)completionBlock
{
    __block NSUInteger callback = 0;
    return ^BRURetryPolicyResponse (NSError *e, NSUInteger a, NSTimeInterval *d) {

        callback++;
        XCTAssertEqual(a, callback);

        if (a <= attempt) {

            XCTAssertNotNil(e);
            XCTAssertEqualObjects(e, [BRURetryTests transientError]);
            XCTAssert(d);

            *d = BRURetryTestsDelayTimeInterval;

            if (a == attempt) {

                completionBlock();

                return BRURetryPolicyResponseStop;

            } else {

                return BRURetryPolicyResponseRetry;

            }

        } else {

            XCTAssert(NO, @"Result block called too many times (%lu)", (unsigned long)a);

            return BRURetryPolicyResponseRetry;

        }
    };
}

- (void)expectSuccessWithSyncQueue:(dispatch_queue_t)syncQueue
                       targetQueue:(dispatch_queue_t)targetQueue
                   completionBlock:(BRURetryTestsCompletionBlock)completionBlock
{
    BRU_ASSERT_ON_QUEUE(syncQueue);

    BRURetry *retry = [self retryWithActionBlock:[self actionBlockWithSuccessOnAttempt:1]
                                         retries:0
                                     targetQueue:targetQueue];
    __block NSUUID *identifier =
    [retry startWithCompletionBlock:[self completionBlockWithSuccessAndCompletionBlock:^{
        // Syncronization for identifier.
        dispatch_async(syncQueue, ^{
            XCTAssertFalse([retry cancel:identifier]);
            completionBlock();
        });
    }]];
}

- (void)testSuccess
{
    [BRURetryTests performSoakTest:^{
        [self dispatchBlocking:^(dispatch_queue_t currentQueue, BRURetryTestsCompletionBlock completionBlock) {
            [self expectSuccessWithSyncQueue:currentQueue targetQueue:nil completionBlock:completionBlock];
        }];
    }];
}

- (void)testSuccessWithSameSyncQueueAndTargetQueue
{
    [BRURetryTests performSoakTest:^{
        [self dispatchBlocking:^(dispatch_queue_t currentQueue, BRURetryTestsCompletionBlock completionBlock) {
            [self expectSuccessWithSyncQueue:currentQueue targetQueue:currentQueue completionBlock:completionBlock];
        }];
    }];
}

- (void)expectFailureWithSyncQueue:(dispatch_queue_t)syncQueue
                       targetQueue:(dispatch_queue_t)targetQueue
                   completionBlock:(BRURetryTestsCompletionBlock)completionBlock
{
    BRU_ASSERT_ON_QUEUE(syncQueue);

    BRURetry *retry = [self retryWithActionBlock:[self actionBlockWithFailureOnAttempt:1] retries:0 targetQueue:nil];
    __block NSUUID *identifier = [retry startWithCompletionBlock:[self completionBlockWithFailureAndCompletionBlock:^{
        // Syncronization for identifier.
        dispatch_async(syncQueue, ^{
            XCTAssertFalse([retry cancel:identifier]);
            completionBlock();
        });
    }]];
}

- (void)testFailure
{
    [BRURetryTests performSoakTest:^{
        [self dispatchBlocking:^(dispatch_queue_t currentQueue, BRURetryTestsCompletionBlock completionBlock) {
            [self expectFailureWithSyncQueue:currentQueue targetQueue:nil completionBlock:completionBlock];
        }];
    }];
}

- (void)testFailureWithSameSyncQueueAndTargetQueue
{
    [BRURetryTests performSoakTest:^{
        [self dispatchBlocking:^(dispatch_queue_t currentQueue, BRURetryTestsCompletionBlock completionBlock) {
            [self expectFailureWithSyncQueue:currentQueue targetQueue:currentQueue completionBlock:completionBlock];
        }];
    }];
}


- (void)expectSuccessAsyncWithSyncQueue:(dispatch_queue_t)syncQueue
                            targetQueue:(dispatch_queue_t)targetQueue
                        completionBlock:(BRURetryTestsCompletionBlock)completionBlock
{
    BRU_ASSERT_ON_QUEUE(syncQueue);

    BRURetryActionBlock actionBlock = [self asyncActionBlockWithActionBlock:[self actionBlockWithSuccessOnAttempt:1]];
    BRURetry *retry = [BRURetryTests retryWithActionBlock:actionBlock
                                              policyBlock:[self policyBlockWithRetries:0]
                                              targetQueue:nil];
    __block NSUUID *identifier = [retry startWithCompletionBlock:[self completionBlockWithSuccessAndCompletionBlock:^{
        XCTAssertFalse([retry cancel:identifier]);
        completionBlock();
    }]];
}

- (void)testSuccessAsync
{
    [BRURetryTests performSoakTest:^{
        [self dispatchBlocking:^(dispatch_queue_t currentQueue, BRURetryTestsCompletionBlock completionBlock) {
            [self expectSuccessAsyncWithSyncQueue:currentQueue targetQueue:nil completionBlock:completionBlock];
        }];
    }];
}

- (void)testSuccessAsyncWithSameSyncQueueAndTargetQueue
{
    [BRURetryTests performSoakTest:^{
        [self dispatchBlocking:^(dispatch_queue_t currentQueue, BRURetryTestsCompletionBlock completionBlock) {
            [self expectSuccessAsyncWithSyncQueue:currentQueue targetQueue:currentQueue completionBlock:completionBlock];
        }];
    }];
}

- (void)expectFailureAsyncWithSyncQueue:(dispatch_queue_t)syncQueue
                            targetQueue:(dispatch_queue_t)targetQueue
                        completionBlock:(BRURetryTestsCompletionBlock)completionBlock
{
    BRU_ASSERT_ON_QUEUE(syncQueue);

    BRURetryActionBlock actionBlock = [self asyncActionBlockWithActionBlock:[self actionBlockWithFailureOnAttempt:1]];

    BRURetry *retry = [BRURetryTests retryWithActionBlock:actionBlock
                                              policyBlock:[self policyBlockWithRetries:0]
                                              targetQueue:nil];
    __block NSUUID *identifier = [retry startWithCompletionBlock:[self completionBlockWithFailureAndCompletionBlock:^{
        // Syncronization for identifier.
        dispatch_async(syncQueue, ^{
            XCTAssertFalse([retry cancel:identifier]);
            completionBlock();
        });
    }]];
}

- (void)testFailureAsync
{
    [BRURetryTests performSoakTest:^{
        [self dispatchBlocking:^(dispatch_queue_t currentQueue, BRURetryTestsCompletionBlock completionBlock) {
            [self expectFailureWithSyncQueue:currentQueue targetQueue:nil completionBlock:completionBlock];
        }];
    }];
}

- (void)testFailureAsyncWithSameSyncQueueAndTargetQueue
{
    [BRURetryTests performSoakTest:^{
        [self dispatchBlocking:^(dispatch_queue_t currentQueue, BRURetryTestsCompletionBlock completionBlock) {
            [self expectFailureWithSyncQueue:currentQueue targetQueue:currentQueue completionBlock:completionBlock];
        }];
    }];
}

- (void)expectSuccessAfterRetryWithSyncQueue:(dispatch_queue_t)syncQueue
                                 targetQueue:(dispatch_queue_t)targetQueue
                             completionBlock:(BRURetryTestsCompletionBlock)completionBlock
{
    BRU_ASSERT_ON_QUEUE(syncQueue);

    BRURetry *retry = [self retryWithActionBlock:[self actionBlockWithSuccessOnAttempt:2] retries:1 targetQueue:nil];
    __block NSUUID *identifier = [retry startWithCompletionBlock:[self completionBlockWithSuccessAndCompletionBlock:^{
        // Syncronization for identifier.
        dispatch_async(syncQueue, ^{
            XCTAssertFalse([retry cancel:identifier]);
            completionBlock();
        });
    }]];
}

- (void)testSuccessAfterRetry
{
    [BRURetryTests performSoakTest:^{
        [self dispatchBlocking:^(dispatch_queue_t currentQueue, BRURetryTestsCompletionBlock completionBlock) {
            [self expectSuccessAfterRetryWithSyncQueue:currentQueue targetQueue:nil completionBlock:completionBlock];
        }];
    }];
}

- (void)testSuccessAfterRetryWithSameSyncQueueAndTargetQueue
{
    [BRURetryTests performSoakTest:^{
        [self dispatchBlocking:^(dispatch_queue_t currentQueue, BRURetryTestsCompletionBlock completionBlock) {
            [self expectSuccessAfterRetryWithSyncQueue:currentQueue
                                           targetQueue:currentQueue
                                       completionBlock:completionBlock];
        }];
    }];
}

- (void)expectFailureAfterRetryWithSyncQueue:(dispatch_queue_t)syncQueue
                                 targetQueue:(dispatch_queue_t)targetQueue
                             completionBlock:(BRURetryTestsCompletionBlock)completionBlock
{
    BRU_ASSERT_ON_QUEUE(syncQueue);

    BRURetry *retry = [self retryWithActionBlock:[self actionBlockWithFailureOnAttempt:2] retries:1 targetQueue:nil];
    [retry startWithCompletionBlock:[self completionBlockWithFailureAndCompletionBlock:completionBlock]];
}

- (void)testFailureAfterRetry
{
    [BRURetryTests performSoakTest:^{
        [self dispatchBlocking:^(dispatch_queue_t currentQueue, BRURetryTestsCompletionBlock completionBlock) {
            [self expectFailureAfterRetryWithSyncQueue:currentQueue targetQueue:nil completionBlock:completionBlock];
        }];
    }];
}

- (void)testFailureAfterRetryWithSameSyncQueueAndTargetQueue
{
    [BRURetryTests performSoakTest:^{
        [self dispatchBlocking:^(dispatch_queue_t currentQueue, BRURetryTestsCompletionBlock completionBlock) {
            [self expectFailureAfterRetryWithSyncQueue:currentQueue
                                           targetQueue:currentQueue
                                       completionBlock:completionBlock];
        }];
    }];
}

- (void)expectSuccessAferRetryAsyncWithSyncQueue:(dispatch_queue_t)syncQueue
                                     targetQueue:(dispatch_queue_t)targetQueue
                                 completionBlock:(BRURetryTestsCompletionBlock)completionBlock
{
    BRU_ASSERT_ON_QUEUE(syncQueue);

    BRURetryActionBlock actionBlock = [self asyncActionBlockWithActionBlock:[self actionBlockWithSuccessOnAttempt:2]];
    BRURetry *retry = [self retryWithActionBlock:actionBlock retries:1 targetQueue:nil];
    __block NSUUID *identifier = [retry startWithCompletionBlock:[self completionBlockWithSuccessAndCompletionBlock:^{
        // Synchronization for identifier.
        dispatch_async(syncQueue, ^{
            XCTAssertFalse([retry cancel:identifier]);
            completionBlock();
        });
    }]];
}

- (void)testSuccessAfterRetryAsync
{
    [BRURetryTests performSoakTest:^{
        [self dispatchBlocking:^(dispatch_queue_t currentQueue, BRURetryTestsCompletionBlock completionBlock) {
            [self expectSuccessAferRetryAsyncWithSyncQueue:currentQueue targetQueue:nil completionBlock:completionBlock];
        }];
    }];
}

- (void)testSuccessAfterRetryAsyncWithSameSyncQueueAndTargetQueue
{
    [BRURetryTests performSoakTest:^{
        [self dispatchBlocking:^(dispatch_queue_t currentQueue, BRURetryTestsCompletionBlock completionBlock) {
            [self expectSuccessAferRetryAsyncWithSyncQueue:currentQueue
                                               targetQueue:currentQueue
                                           completionBlock:completionBlock];
        }];
    }];
}

- (void)expectFailureAfterRetryAsyncWithSyncQueue:(dispatch_queue_t)syncQueue
                                      targetQueue:(dispatch_queue_t)targetQueue
                                  completionBlock:(BRURetryTestsCompletionBlock)completionBlock
{
    BRU_ASSERT_ON_QUEUE(syncQueue);

    BRURetryActionBlock actionBlock = [self asyncActionBlockWithActionBlock:[self actionBlockWithFailureOnAttempt:2]];
    BRURetry *retry = [self retryWithActionBlock:actionBlock retries:1 targetQueue:nil];
    __block NSUUID *identifier = [retry startWithCompletionBlock:[self completionBlockWithFailureAndCompletionBlock:^{
        // Synchronization for identifier.
        dispatch_async(syncQueue, ^{
            XCTAssertFalse([retry cancel:identifier]);
            completionBlock();
        });
    }]];
}

- (void)testFailureAfterRetryAsync
{
    [BRURetryTests performSoakTest:^{
        [self dispatchBlocking:^(dispatch_queue_t currentQueue, BRURetryTestsCompletionBlock completionBlock) {
            [self expectFailureAfterRetryAsyncWithSyncQueue:currentQueue
                                                targetQueue:nil
                                            completionBlock:completionBlock];
        }];
    }];
}

- (void)testFailureAfterRetryAsyncWithSameSyncQueueAndTargetQueue
{
    [BRURetryTests performSoakTest:^{
        [self dispatchBlocking:^(dispatch_queue_t currentQueue, BRURetryTestsCompletionBlock completionBlock) {
            [self expectFailureAfterRetryAsyncWithSyncQueue:currentQueue
                                                targetQueue:currentQueue
                                            completionBlock:completionBlock];
        }];
    }];
}

- (BRURetryPolicyBlock)policyBlockWithEarlyTermination
{
    __block NSUInteger count = 0;
    return ^BRURetryPolicyResponse(NSError *__nullable error,
                                   NSUInteger attempt,
                                   NSTimeInterval *__nullable delay) {
        count++;
        XCTAssert(count == 1);
        XCTAssert(attempt == 1);
        return BRURetryPolicyResponseStop;
    };
}

- (void)testEarlyTermination
{
    [BRURetryTests performSoakTest:^{

        dispatch_semaphore_t sem = dispatch_semaphore_create(0);
        BRURetry *retry = [BRURetryTests retryWithActionBlock:[self actionBlockWithFailureOnAttempt:10]
                                                  policyBlock:[self policyBlockWithEarlyTermination]
                                                  targetQueue:nil];
        NSUUID *identifier =
        [retry startWithCompletionBlock:[self completionBlockWithTransientFailureAndCompletionBlock:^{
            dispatch_semaphore_signal(sem);
        }]];
        [self waitOnSemaphore:sem];
        XCTAssertFalse([retry cancel:identifier]);

    }];
}

- (void)testEarlyTerminationAsync
{
    [BRURetryTests performSoakTest:^{

        BRURetryActionBlock actionBlock = [self asyncActionBlockWithActionBlock:[self actionBlockWithFailureOnAttempt:10]];
        dispatch_semaphore_t sem = dispatch_semaphore_create(0);
        BRURetry *retry = [BRURetryTests retryWithActionBlock:actionBlock
                                                  policyBlock:[self policyBlockWithEarlyTermination]
                                                  targetQueue:nil];
        NSUUID *identifier =
        [retry startWithCompletionBlock:[self completionBlockWithTransientFailureAndCompletionBlock:^{
            dispatch_semaphore_signal(sem);
        }]];
        [self waitOnSemaphore:sem];
        XCTAssertFalse([retry cancel:identifier]);

    }];
}

- (void)testCancelRandom
{
    [BRURetryTests performSoakTest:^{

        BRURetry *retry = [self retryWithActionBlock:[self actionBlockWithFailureOnAttempt:2] retries:1 targetQueue:nil];
        XCTAssertFalse([retry cancel:[NSUUID UUID]]);

    }];
}

- (void)testCancelWhenRunningSuccessfulAction
{
    [BRURetryTests performSoakTest:^{

        dispatch_semaphore_t actionSem = dispatch_semaphore_create(0);
        dispatch_semaphore_t completionSem = dispatch_semaphore_create(0);

        BRURetryActionBlock actionBlock = ^(BRURetryContinuationBlock continuationBlock) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                dispatch_semaphore_wait(actionSem, DISPATCH_TIME_FOREVER);
                continuationBlock(YES, nil, YES);
            });
        };

        BRURetry *retry = [BRURetryTests retryWithActionBlock:actionBlock
                                                  policyBlock:[self policyBlockWithRetries:0]
                                                  targetQueue:nil];
        NSUUID *identifier = [retry startWithCompletionBlock:[self completionBlockWithSuccessAndCompletionBlock:^{
            dispatch_semaphore_signal(completionSem);
        }]];
        XCTAssertTrue([retry cancel:identifier]);
        dispatch_semaphore_signal(actionSem);
        XCTAssertFalse([retry cancel:identifier]);
        [self waitOnSemaphore:completionSem];

    }];
}

- (void)testCancelWhenRunningUnsuccessfulAction
{
    [BRURetryTests performSoakTest:^{

        dispatch_semaphore_t actionSem = dispatch_semaphore_create(0);
        dispatch_semaphore_t completionSem = dispatch_semaphore_create(0);

        BRURetryActionBlock actionBlock = ^(BRURetryContinuationBlock continuationBlock) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                dispatch_semaphore_wait(actionSem, DISPATCH_TIME_FOREVER);
                continuationBlock(NO, [BRURetryTests defaultError], YES);
            });
        };

        BRURetry *retry = [BRURetryTests retryWithActionBlock:actionBlock
                                                  policyBlock:[self policyBlockWithRetries:0]
                                                  targetQueue:nil];
        NSUUID *identifier = [retry startWithCompletionBlock:[self completionBlockWithCancellationAndCompletionBlock:^{
            dispatch_semaphore_signal(completionSem);
        }]];
        XCTAssertTrue([retry cancel:identifier]);
        dispatch_semaphore_signal(actionSem);
        XCTAssertFalse([retry cancel:identifier]);
        [self waitOnSemaphore:completionSem];

    }];
}

- (void)testCancelDuringActionPhase
{
    [BRURetryTests performSoakTest:^{

        dispatch_semaphore_t actionSem = dispatch_semaphore_create(0);
        dispatch_semaphore_t completionSem = dispatch_semaphore_create(0);

        BRURetryActionBlock actionBlock = ^(BRURetryContinuationBlock continuationBlock) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                continuationBlock(NO, [BRURetryTests transientError], NO);
                dispatch_semaphore_signal(actionSem);
            });
        };

        BRURetry *retry = [[BRURetry alloc] initWithActionBlock:actionBlock
                                                    policyBlock:[self policyBlockWithRetries:1]
                                                          delay:10.0];

        NSUUID *identifier =
        [retry startWithCompletionBlock:[self completionBlockWithCancellationAndCompletionBlock:^{
            dispatch_semaphore_signal(completionSem);
        }]];
        [self waitOnSemaphore:actionSem];
        XCTAssertTrue([retry cancel:identifier]);
        [self waitOnSemaphore:completionSem];
        XCTAssertFalse([retry cancel:identifier]);

    }];
}

- (void)testCancelDuringDelayPhase
{
    [BRURetryTests performSoakTest:^{

        dispatch_semaphore_t actionSem = dispatch_semaphore_create(0);
        dispatch_semaphore_t completionSem = dispatch_semaphore_create(0);

        BRURetryActionBlock actionBlock = ^(BRURetryContinuationBlock continuationBlock) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                continuationBlock(NO, [BRURetryTests transientError], BRURetryStatusTransient);
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.02 * NSEC_PER_SEC)),
                               dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                   dispatch_semaphore_signal(actionSem);
                               });
            });
        };

        BRURetryPolicyBlock policyBlock = ^BRURetryPolicyResponse(NSError *__nullable error,
                                                                  NSUInteger attempt,
                                                                  NSTimeInterval *__nullable delay) {
            XCTAssertEqual(attempt, 1);
            *delay = 10.0;
        };


        BRURetry *retry = [BRURetryTests retryWithActionBlock:actionBlock
                                                  policyBlock:policyBlock
                                                  targetQueue:nil];
        NSUUID *identifier =
        [retry startWithCompletionBlock:[self completionBlockWithCancellationAndCompletionBlock:^{
            dispatch_semaphore_signal(completionSem);
        }]];
        [self waitOnSemaphore:actionSem];
        XCTAssertTrue([retry cancel:identifier]);
        [self waitOnSemaphore:completionSem];
        XCTAssertFalse([retry cancel:identifier]);

    }];
}

- (void)expectCancelSuccessDuringStartWithSyncQueue:(dispatch_queue_t)syncQueue
                                        targetQueue:(dispatch_queue_t)targetQueue
                                    completionBlock:(BRURetryTestsCompletionBlock)completionBlock
{
    BRU_ASSERT_ON_QUEUE(syncQueue);

    BRURetryActionBlock actionBlock = ^(BRURetryContinuationBlock continuationBlock) {
        sleep(0.1);
        continuationBlock(YES, nil, BRURetryStatusFinal);
    };

    // If no targetQueue is specified (aka. we would like to use the internal queue created by BRURetry, we need to
    // simulate this queue to allow us to start it suspended. Otherwise we can't keep BRURetry in the 'just started'
    // state.
    dispatch_queue_t simulatedTargetQueue = nil;
    if (targetQueue == nil) {
        simulatedTargetQueue = bru_dispatch_queue_create("com.bromium.BromiumUtils.BRURetryTests.targetQueue",
                                                         DISPATCH_QUEUE_CONCURRENT);
        dispatch_suspend(simulatedTargetQueue);
    }

    BRURetry *retry = [self retryWithActionBlock:actionBlock
                                         retries:0
                                     targetQueue:targetQueue ? targetQueue : simulatedTargetQueue];
    NSUUID *identifier =
    [retry startWithCompletionBlock:[self completionBlockWithSuccessAndCompletionBlock:completionBlock]];

    XCTAssertTrue([retry cancel:identifier]);

    if (simulatedTargetQueue) {
        dispatch_resume(simulatedTargetQueue);
    }
}

- (void)testCancelSucceedsDuringStart
{
    [BRURetryTests performSoakTest:^{
        [self dispatchBlocking:^(dispatch_queue_t currentQueue, BRURetryTestsCompletionBlock completionBlock) {
            [self expectCancelSuccessDuringStartWithSyncQueue:currentQueue
                                                  targetQueue:nil
                                              completionBlock:completionBlock];
        }];
    }];
}

- (void)testCancelSucceedsDuringStartWithSameSyncQueueAndTargetQueue
{
    [BRURetryTests performSoakTest:^{
        [self dispatchBlocking:^(dispatch_queue_t currentQueue, BRURetryTestsCompletionBlock completionBlock) {
            [self expectCancelSuccessDuringStartWithSyncQueue:currentQueue
                                                  targetQueue:currentQueue
                                              completionBlock:completionBlock];
        }];
    }];
}



- (void)expectCancelSuccessDuringPolicyDecisionWithSyncQueue:(dispatch_queue_t)syncQueue
                                                 targetQueue:(dispatch_queue_t)targetQueue
                                             completionBlock:(BRURetryTestsCompletionBlock)completionBlock
{
    BRU_ASSERT_ON_QUEUE(syncQueue);

    __block NSUUID *identifier = nil;
    __block BRURetry *retry = nil;

    BRURetryActionBlock actionBlock = ^(BRURetryContinuationBlock __nonnull continuationBlock) {
        continuationBlock(NO, [BRURetryTests transientError], BRURetryStatusTransient);
    };

    dispatch_semaphore_t policySem = dispatch_semaphore_create(0);
    BRURetryPolicyBlock policyBlock = ^BRURetryPolicyResponse (NSError *__nullable error,
                                                               NSUInteger attempt,
                                                               NSTimeInterval *__nullable delay) {

        // Actually perform the test.
        dispatch_block_t testBlock = ^{
            XCTAssertTrue([retry cancel:identifier]);
            dispatch_semaphore_signal(policySem);
        };

        // We ensure that the test is performed on the syncQueue.
        if (syncQueue == targetQueue) {
            testBlock();
        } else {
            BRU_ASSERT_OFF_QUEUE(syncQueue);
            dispatch_async(syncQueue, testBlock);
        }

        [self waitOnSemaphore:policySem];

        return BRURetryPolicyResponseRetry;
    };

    retry = [BRURetryTests retryWithActionBlock:actionBlock
                                    policyBlock:policyBlock
                                    targetQueue:targetQueue];
    identifier =
    [retry startWithCompletionBlock:[self completionBlockWithCancellationAndCompletionBlock:completionBlock]];

}

- (void)testCancelSuccessDuringPolicyDecision
{
    [BRURetryTests performSoakTest:^{
        [self dispatchBlocking:^(dispatch_queue_t currentQueue, BRURetryTestsCompletionBlock completionBlock) {
            [self expectCancelSuccessDuringPolicyDecisionWithSyncQueue:currentQueue
                                                           targetQueue:nil
                                                       completionBlock:completionBlock];
        }];
    }];
}

- (void)testCancelSuccessDuringPolicyDecisionWithSameSyncQueueAndTargetQueue
{
    [BRURetryTests performSoakTest:^{
        [self dispatchBlocking:^(dispatch_queue_t currentQueue, BRURetryTestsCompletionBlock completionBlock) {
            [self expectCancelSuccessDuringPolicyDecisionWithSyncQueue:currentQueue
                                                           targetQueue:currentQueue
                                                       completionBlock:completionBlock];
        }];
    }];
}

@end
