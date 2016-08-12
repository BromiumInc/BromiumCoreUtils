//
//  Copyright (C) 2013-2016, Bromium Inc.
//
//  This software may be modified and distributed under the terms
//  of the BSD license.  See the LICENSE file for details.
//
//  Created by Jason Morley on 09/04/2015.
//

#import "BRURetry.h"

#import "BRUAsserts.h"
#import "BRUDispatchUtils.h"
#import "BRUTimer.h"
#import "BRUEqualityUtils.h"
#import "BRUARCUtils.h"
#import "BRUDeferred.h"

BRURetryPolicyBlock __nonnull BRURetryPolicyBlockWithMaxRetries(NSUInteger retries) {

    BRURetryPolicyBlock resultBlock = ^BRURetryPolicyResponse (__unused NSError *error,
                                                               NSUInteger attempt,
                                                               __unused NSTimeInterval *delay) {

        if (attempt >= retries) {
            return BRURetryPolicyResponseStop;
        }

        return BRURetryPolicyResponseRetry;

    };

    return resultBlock;
}

typedef NS_ENUM(NSInteger, BRURetryState) {

    BRURetryStateIdle = 1,
    BRURetryStateDelay = 2,
    BRURetryStateActiveWaiting = 3,
    BRURetryStateActiveCancelling = 4,

};

@interface BRURetryResult : NSObject

@property (nonatomic, assign, readonly) BOOL success;
@property (nonatomic, strong, readonly) NSError *error;

BRU_DEFAULT_INIT_UNAVAILABLE(nonnull)

- (nonnull instancetype)initWithSuccess:(BOOL)success error:(nullable NSError *)error;

@end

@implementation BRURetryResult

BRU_DEFAULT_INIT_UNAVAILABLE_IMPL

- (nonnull instancetype)initWithSuccess:(BOOL)success error:(nullable NSError *)error
{
    self = [super init];
    if (self) {
        self->_success = success;
        self->_error = [error copy];
    }
    return self;
}

@end

@interface BRURetry ()

@property (nonatomic, strong, readonly) BRURetryActionBlock actionBlock;
@property (nonatomic, strong, readonly) BRURetryPolicyBlock policyBlock;
@property (nonatomic, assign, readonly) NSTimeInterval delay;

@property (nonatomic, strong, readonly) dispatch_queue_t syncQueue;
@property (nonatomic, strong, readonly) dispatch_queue_t targetQueue;

/**
 * Synchronized on syncQueue.
 */
@property (nonatomic, strong, readwrite) BRUTimer *timer;

/**
 * Synchronized on syncQueue.
 */
@property (nonatomic, assign, readwrite) NSUInteger attempt;

/**
 * Synchronized on syncQueue.
 */
@property (nonatomic, assign, readwrite) BRURetryState state;

/**
 * Synchronzied on syncQueue.
 */
@property (nonatomic, assign, readwrite) NSTimeInterval currentDelay;

/**
 * The identifier for the current action block.
 *
 * Synchronized on syncQueue.
 */
@property (nonatomic, strong, readwrite) NSUUID *identifier;

/**
 * Deferred for returning the results of the final action.
 *
 * Synchronized on syncQueue.
 */
@property (nonatomic, strong, readwrite) BRUDeferred *deferred;

@end

@implementation BRURetry

BRU_DEFAULT_INIT_UNAVAILABLE_IMPL

+ (NSError *)cancellationErrorWithIdentifier:(NSUUID *)identifier
{
    NSString *description = [NSString stringWithFormat:
                             @"Retry attempt with identifier %@ cancelled.",
                             identifier];
    NSError *error = [NSError errorWithDomain:NSPOSIXErrorDomain
                                         code:ECANCELED
                                     userInfo:@{BRUErrorReasonKey: description}];
    return error;
}

- (instancetype)initWithActionBlock:(nonnull BRURetryActionBlock)actionBlock
                        policyBlock:(nonnull BRURetryPolicyBlock)policyBlock
                              delay:(NSTimeInterval)delay
{
    BRUParameterAssert(actionBlock);
    BRUParameterAssert(policyBlock);

    return [self initWithActionBlock:actionBlock policyBlock:policyBlock delay:delay targetQueue:nil];
}

- (instancetype)initWithActionBlock:(nonnull BRURetryActionBlock)actionBlock
                        policyBlock:(nonnull BRURetryPolicyBlock)policyBlock
                              delay:(NSTimeInterval)delay
                        targetQueue:(nullable dispatch_queue_t)targetQueue
{
    BRUParameterAssert(actionBlock);
    BRUParameterAssert(policyBlock);

    self = [super init];
    if (self) {

        self->_actionBlock = actionBlock;
        self->_policyBlock = policyBlock;
        self->_delay = delay;

        self->_targetQueue = bru_dispatch_queue_create("com.bromium.BromiumUtils.BRURetry.targetQueue",
                                                       DISPATCH_QUEUE_SERIAL);
        if (targetQueue) {
            dispatch_set_target_queue(self->_targetQueue, targetQueue);
        }

        self->_syncQueue = bru_dispatch_queue_create("com.bromium.BromiumUtils.BRURetry.syncQueue",
                                                     DISPATCH_QUEUE_SERIAL);

        self->_timer = nil;
        self->_attempt = 0;
        self->_state = BRURetryStateIdle;
        self->_deferred = nil;

    }
    return self;
}

- (void)checkInvariants
{
    BRU_ASSERT_ON_QUEUE(self.syncQueue);

    BRUAssert((self.state == BRURetryStateIdle
               && self.timer == nil
               && self.attempt == 0
               && self.identifier == nil
               && BRUDoubleEquals(self.currentDelay, self.delay, DBL_EPSILON)
               && self.deferred == nil) ||
              (self.state == BRURetryStateDelay
               && self.timer != nil
               && self.attempt > 0
               && self.identifier != nil
               && self.deferred) ||
              (self.state == BRURetryStateActiveWaiting
               && self.timer == nil
               && self.attempt > 0
               && self.identifier != nil
               && self.deferred) ||
              (self.state == BRURetryStateActiveCancelling
               && self.timer == nil
               && self.attempt > 0
               && self.identifier != nil
               && self.deferred),
              @"Invalid state (state=%ld, timer=%@, identifier=%@, currentDelay=%f, deferred=%@, attempt=%lu, delay=%f",
              self.state, self.timer, self.identifier, self.currentDelay, self.deferred, self.attempt, self.delay);
}

- (void)scheduleNextAction
{
    BRU_ASSERT_ON_QUEUE(self.syncQueue);

    BRUAssert(self.timer == nil, @"Invalid attempt to schedule the action when already scheduled.");

    NSUUID *identifier = [self.identifier copy];

    BRU_weakify(self);
    void (^action)(BRUTimer *timer, NSDate *date) = ^(__unused BRUTimer *timer, __unused NSDate *date) {

        BRU_strongify(self);
        if (!self) {
            return;
        }

        BRU_ASSERT_ON_QUEUE(self.syncQueue);

        BRUAssert([identifier isEqual:self.identifier], @"Unexpected callback (got '%@', expected '%@') from BRUTimer",
                  identifier, self.identifier);

        self.timer = nil;
        self.state = BRURetryStateActiveWaiting;

        [self performAction];

    };

    self.timer = [BRUTimer scheduledTimerWithInterval:self.currentDelay
                                                block:action
                                              onQueue:self.syncQueue
                                              repeats:NO
                                                 mode:BRUTimerModeIntervalBetweenBlockExecutions
                                       adjustInterval:nil];

    self.state = BRURetryStateDelay;
}

- (nonnull NSUUID *)startWithCompletionBlock:(nullable BRURetryCompletionBlock)completionBlock
{
    __block NSUUID *identifier = nil;

    dispatch_sync(self.syncQueue, ^{

        if (self.state == BRURetryStateIdle) {

            self.deferred = [BRUDeferred deferredWithTargetQueue:self.targetQueue];
            self.identifier = [NSUUID UUID];
            self.state = BRURetryStateActiveWaiting;

            [self performAction];

            identifier = self.identifier;

        } else if (self.state == BRURetryStateDelay) {

            // Already running. Nothing to do.

        } else if (self.state == BRURetryStateActiveWaiting) {

            // Already running. Nothing to do.

        } else if (self.state == BRURetryStateActiveCancelling) {

            // Running but cancelling. Restore the current action.
            self.state = BRURetryStateActiveWaiting;
            identifier = self.identifier;

        } else {
            BRU_ASSERT_NOT_REACHED(@"Invalid state %lu", (unsigned long)self.state);
        }

        if (completionBlock) {

            BRU_weakify(self);
            [[self.deferred promise] then:^(BRURetryResult *result) {

                BRU_ASSERT_ON_QUEUE(self.targetQueue);

                BRU_strongify(self);
                if (!self) {
                    return;
                }

                if (completionBlock) {
                    completionBlock(result.success, result.error);
                }

            }];
        }

        [self checkInvariants];

    });

    BRUAssert(identifier, @"Unexpected nil identifer following call to start.");

    return identifier;
}

- (BOOL)cancel:(nonnull NSUUID *)identifier
{
    BRUParameterAssert(identifier);

    __block BOOL success = NO;
    BRU_ASSERT_OFF_QUEUE(self.syncQueue);
    dispatch_sync(self.syncQueue, ^{

        if (![self.identifier isEqual:identifier]) {
            return;
        }

        if (self.state == BRURetryStateIdle) {

            // Already stopped. Nothing to do.
            // This state should never happen as we're guarding against this scenario by checking the identifier.

        } else if (self.state == BRURetryStateDelay) {

            // Delay phase. Cancel immediately.

            NSUUID *previousIdentifier = self.identifier;

            [self.timer suspend];
            self.timer = nil;

            self.state = BRURetryStateIdle;

            BRUDeferred *deferred = self.deferred;

            self.identifier = nil;
            self.attempt = 0;
            self.currentDelay = self.delay;
            self.deferred = nil;

            NSError *error = [BRURetry cancellationErrorWithIdentifier:previousIdentifier];
            [deferred resolve:[[BRURetryResult alloc] initWithSuccess:NO error:error]];

            success = YES;

        } else if (self.state == BRURetryStateActiveWaiting) {

            // Indicate that we wish to cancel at the end of the next action.

            self.state = BRURetryStateActiveCancelling;

            success = YES;

        } else if (self.state == BRURetryStateActiveCancelling) {

            // Already cancelling. Nothing to do.

        } else {
            BRU_ASSERT_NOT_REACHED(@"Invalid state %lu", (unsigned long)self.state);
        }

        [self checkInvariants];

    });
    return success;
}

- (void)handleResult:(BOOL)success
               error:(NSError *)error
      policyResponse:(BRURetryPolicyResponse)policyResponse
           nextDelay:(NSTimeInterval)nextDelay
{
    BRU_ASSERT_ON_QUEUE(self.syncQueue);

    // Check if we should terminate.
    BOOL terminate = success ||
                     self.state == BRURetryStateActiveCancelling ||
                     policyResponse == BRURetryPolicyResponseStop;

    if (terminate) {

        BRUDeferred *deferred = self.deferred;

        if (!success && self.state == BRURetryStateActiveCancelling) {
            error = [BRURetry cancellationErrorWithIdentifier:self.identifier];
        }

        self.state = BRURetryStateIdle;
        self.attempt = 0;
        self.currentDelay = self.delay;
        self.identifier = nil;
        self.deferred = nil;

        [deferred resolve:[[BRURetryResult alloc] initWithSuccess:success error:error]];

    } else {

        self.currentDelay = nextDelay;
        [self scheduleNextAction];

    }

    [self checkInvariants];

}


- (void)performAction
{
    BRU_ASSERT_ON_QUEUE(self.syncQueue);

    self.attempt++;
    NSUInteger attempt = self.attempt;

    BRUAssert(self.state == BRURetryStateActiveWaiting,
              @"Perform action block called when not running (state=%ld).", self.state);

    BRU_weakify(self);
    BRURetryContinuationBlock continuationBlock = ^(BOOL success,
                                                    NSError *error,
                                                    BRURetryStatus status) {

        BRU_strongify(self);
        if (!self) {
            return;
        }

        dispatch_async(self.syncQueue, ^{

            BRU_strongify(self);
            if (!self) {
                return;
            }

            BOOL final = success || self.state == BRURetryStateActiveCancelling || status == BRURetryStatusFinal;

            BRUAssert((success && error == nil) || (!success && error),
                      @"Continuation block called with inconsistent results (success=%@, error=%@.",
                      success ? @"YES" : @"NO", error);

            if (!final) {

                __block NSTimeInterval nextDelay = self.currentDelay;
                dispatch_async(self.targetQueue, ^{
                    BRURetryPolicyResponse response = self.policyBlock(error, attempt, &nextDelay);
                    dispatch_async(self.syncQueue, ^{
                        [self handleResult:success error:error policyResponse:response nextDelay:nextDelay];
                    });
                });

            } else {

                [self handleResult:success
                             error:error
                    policyResponse:BRURetryPolicyResponseStop
                         nextDelay:self.currentDelay];

            }

        });

    };

    dispatch_async(self.targetQueue, ^{

        self.actionBlock(continuationBlock);

    });
}

@end
