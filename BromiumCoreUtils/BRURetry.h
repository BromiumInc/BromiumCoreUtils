//
//  Copyright (C) 2013-2016, Bromium Inc.
//
//  This software may be modified and distributed under the terms
//  of the BSD license.  See the LICENSE file for details.
//
//  Created by Jason Morley on 09/04/2015.
//

#import <Foundation/Foundation.h>

#import "BRUBaseDefines.h"

/**
 * Describes the nature of the result when performing an action.
 */
typedef NS_ENUM(NSInteger, BRURetryStatus) {

    /**
     * The result is considered transient and subsequent calls may change the result.
     */
    BRURetryStatusTransient,

    /**
     * The reuslt is considered final and subsequent calls will not affect the outcome.
     */
    BRURetryStatusFinal,

};

/**
 * Response from BRURetryPolicyBlock indicating whether the action should be retried.
 */
typedef NS_ENUM(NSInteger, BRURetryPolicyResponse) {

    /**
     * Retry the action by re-calling the action block after the specified timeout.
     */
    BRURetryPolicyResponseRetry,

    /**
     * Do not retry retry the action and propagate the failure to the completion block.
     */
    BRURetryPolicyResponseStop,

};

/**
 * Block to be called at the end of an action to indicate the result to the BRURetry instance.
 *
 * @param success YES if the action was successful, NO otherwise.
 * @param error NSError encountered during failure. Should be nil if the action was successful.
 * @param status The nature of the result: transient or final.
 */
typedef void (^BRURetryContinuationBlock)(BOOL success, NSError *__nullable error, BRURetryStatus status);

/**
 * Block to perform the action.
 *
 * @param continuationBlock Completion block to call with the results of the action attempt.
 */
typedef void (^BRURetryActionBlock)(BRURetryContinuationBlock __nonnull continuationBlock);

/**
 * Block to be called with the final result from a given retry operation.
 *
 * @param success YES if the action was successful, NO otherwise.
 * @param error NSError encountered in the case of a failure, nil otherwise.
 */
typedef void (^BRURetryCompletionBlock)(BOOL success, NSError *__nullable error);

/**
 * Called once for each retry attempt with the results of the attempt.
 *
 * In the first run delay is initialized to the delay the class was constructed with. In subsequent runs, it is
 * initializted with the previous delay used. e.g. To implement exponential back-off, simply multiply the delay returned
 * by two each time.
 *
 * @param error NSError containing the error reported by the action block (in the case of failure), NO otherwise.
 * @param attempt The number of the current action attempt.
 * @param delay The delay to wait before the next attempt. Initialized with the delay from the prevoius action phase.
 *
 * @return BRURetryPolicyResponseRetry to continue iterations, BRURetryPolicyResponseStop to stop.
 */
typedef BRURetryPolicyResponse (^BRURetryPolicyBlock)(NSError *__nullable error,
                                                      NSUInteger attempt,
                                                      NSTimeInterval *__nullable delay);

BRURetryPolicyBlock __nonnull BRURetryPolicyBlockWithMaxRetries(NSUInteger retries);

/**
 * Utility class for managing the lifecycle of retryable actions.
 *
 * ## Overview
 *
 * Managing operations which may need retrying more than once before they succeed is difficult. `BRURetry` attempts to
 * make that somewhat easier, abstracting away some of the complexity by providing a flexible framework for performing
 * the various steps required.
 *
 * The `BRURetry` API splits a retryable operation into three separate steps:
 *
 * 1. **Action** -- the operation itself which may need to be repeated more than once
 * 2. **Policy** -- the policy to apply when deciding what to do next in the case of a failure to perform the action
 *                  step
 * 3. **Completion** -- anything that needs to be done to handle a final result, be it a success or a failure
 *
 * ### Action
 *
 * - Implemented as a `BRURetryActionBlock`.
 * - May be called multiple times.
 * - Should do nothing more than attempt to perform the operation to be retried and report the result. The action block
 *   is completely unaware of any retry policy: it simply performs the operation and returns the results by calling the
 *   `completionBlock`.
 * - Results can be reported synchronously or asynchronously by calling the `BRURetryContinuationBlock` provided.
 * - Calls to the continuation block are thread-safe and can be made from any thread.
 * - An action block can indicate the nature of a failure by calling the completion block a `BRURetryStatus` of either
 *   `BRURetryStatusTransient` or `BRURetryStatusFinal`. If `BRURetryStatusFinal` is passed, no retry attempt will be
 *   made irrespective of policy.
 *
 * ### Policy
 *
 * - Implemented as a `BRURetryPolicyBlock`.
 * - Called once for each _transient_ action failure (as indicated by a call to the `BRURetryContinuationBlock` provided
 *   to `BRURetryActionBlock`).
 * - Determines whether or not, and when, a subsequent action attempt should be made.
 * - Some default implementations are provided: for example `BRURetryPolicyBlockWithMaxRetries` constructs a policy
 *   block which will try a given number of times.
 *
 * ### Completion
 *
 * - Implemented as a `BRURetryCompletionBlock`.
 * - New completion block added for each successful call to `startWithCompletionBlock:`.
 * - Each completion block is guaranteed to be called only once, either when the operation has completed successfully,
 *   or when the maximum number of retries has been reached.
 *
 * ## Example
 *
 * ### Without BRURetry
 *
 * Consider some code which attempts to make a connection using `self.connection` which connects using the
 * `connectWithError:` selector:
 *
 * ```
 * NSError *error = nil;
 * BOOL success = [self.connection connectWithError:&error];
 * if (!success) {
 *     DDLogError(@"Failed to connect with error %@", error);
 * }
 * ```
 *
 * A naive approach to retrying this API call might look something like this:
 *
 * ```
 * #define MAX_CONNECTION_ATTEMPTS 10
 *
 * NSError *error = nil;
 * BOOL success = NO;
 * NSUInteger count = 0;
 *
 * while (YES) {
 *
 *     // Perform the next operation.
 *     success = [connection connectWithError:&error];
 *
 *     // Exit on success or if we've reached the maximum number of retries.
 *     if (success || count >= MAX_CONNECTION_ATTEMPTS) {
 *         break;
 *     }
 *
 *     // Sleep for 1 second.
 *     sleep(1);
 * }
 *
 * if (!success) {
 *     DDLogError(@"Failed to connect with error %@", error);
 * }
 * ```
 *
 * Obviously this suffers from the following problems:
 *
 * - Blocks the current thread.
 * - No mechanism to cancel.
 *
 * ### With BRURetry
 *
 * The above example can be implemented using `BRURetry` by implementing the `BRURetryActionBlock` and
 * `BRURetryCompletionBlock`, along with a standard `BRURetryPolicyBlock` as follows:
 *
 * #### BRURetryActionBlock
 *
 * ```
 * BRURetryActionBlock actionBlock = ^(BRURetryContinuationBlock continuationBlock) {
 *     NSError *error = nil;
 *     BOOL success = [connection connectWithError:&error];
 *     continuationBlock(success, error, BRURetryStatusTransient);
 * };
 *
 * BRURetryPolicyBlock policyBlock =
 * BRURetryPolicyBlockWithMaxRetries(MAX_CONNECTION_ATTEMPTS);
 *
 * BRURetry *retry = [BRURetry alloc] initWithActionBlock:actionBlock
 *                                            policyBlock:policyBlock
 *                                                  delay:1.0];
 *
 * [retry startWithCompletionBlock:^(BOOL success, NSError *error) {
 *     if (!success) {
 *         DDLogError(@"Failed to connect with error %@", error);
 *     }
 * }];
 *
 * ```
 *
 * ## Cancellation
 *
 * `BRURetry` offers a mechanism for cancelling an ongoing operation:
 *
 * - Each call to `startWithCompletionBlock:` returns an `NSUUID` which uniquely identifies the requested operation.
 * - If a retry attempt is already in progress the `NSUUID` will be the identifier of the ongoing operation and will be
 *   the same as the one returned to the `startWithCompletionBlock:` call which initiated the operation.
 * - An operation can be cancelled by calling `cancel:` with the corresponding identifier.
 */
BRU_restrict_subclassing
@interface BRURetry : NSObject

BRU_DEFAULT_INIT_UNAVAILABLE(nonnull)

/**
 * Initialise BRURetry.
 *
 * By default the actionBlock and targetBlock will be dispatched to a random dispatch queue.
 *
 * @param actionBlock The block which will perform the retryable action.
 * @param policyBlock The block to be called after each retry attempt (and upon completion). Responsible for determining
 *                    whether and when to retry.
 * @param delay The initial time to wait between retries (can be adjusted within the policy block).
 */
- (nonnull instancetype)initWithActionBlock:(nonnull BRURetryActionBlock)actionBlock
                                policyBlock:(nonnull BRURetryPolicyBlock)policyBlock
                                      delay:(NSTimeInterval)delay;

/**
 * Initialise BRURetry.
 *
 * @param actionBlock The block which will perform the retryable action.
 * @param policyBlock The block to be called after each retry attempt (and upon completion). Responsible for determining
 *                    whether and when to retry.
 * @param delay The initial time to wait between retries (can be adjusted within the policy block).
 * @param targetQueue The dispatch queue on which to dispatch the actionBlock and policyBlock and completionBlock.
 */
- (nonnull instancetype)initWithActionBlock:(nonnull BRURetryActionBlock)actionBlock
                                policyBlock:(nonnull BRURetryPolicyBlock)policyBlock
                                      delay:(NSTimeInterval)delay
                                targetQueue:(nullable dispatch_queue_t)targetQueue NS_DESIGNATED_INITIALIZER;

/**
 * Start a retry operation with a completion block to be called when the operation completes.
 *
 * If a retry operation is already in progress the completion block will be associated with the current retry attempt
 * and the identifier returned will be for the current retry attempt.
 *
 * @param completionBlock Completion block to be called with the resutls of the retry operation.
 *
 * @return Identifier assocaited with the new (or current) retry attempt.
 */
- (nonnull NSUUID *)startWithCompletionBlock:(nullable BRURetryCompletionBlock)completionBlock;

/**
 * Calls to cancel are ignored if the retry attempt is already being cancelled, is not running, or if the identifier
 * doesn't match the retry attempt in progress.
 *
 * @param identifier The identifier for the retry attempt to cancel.
 *
 * @return YES if the cancel resulted in an internal state change (from running to cancelling), NO otherwise.
 */
- (BOOL)cancel:(nonnull NSUUID *)identifier;


@end
