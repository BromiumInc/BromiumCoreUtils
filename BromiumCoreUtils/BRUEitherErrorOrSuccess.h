//
//  BRUEitherErrorOrSuccess.h
//  BromiumUtils
//
//  Created by Johannes Weiß on 01/06/2016.
//  Copyright © 2016 Bromium UK Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "BRUBaseDefines.h"

BRU_restrict_subclassing @interface BRUEitherErrorOrSuccess<T> : NSObject

BRU_DEFAULT_INIT_UNAVAILABLE(null_unspecified)

@property (nonatomic, strong, readonly, nullable) NSError *error;
@property (nonatomic, strong, readonly, nullable) T object;
@property (nonatomic, assign, readonly, getter = isSuccessful) BOOL success;

/**
 * Construct for successful computation without any result object.
 *
 * @return successfor instance.
 */
+ (nonnull instancetype)newWithSuccess;

/**
 * Construct for successful computation with result object.
 *
 * @param obj The object that resulted from the successful computation. `obj` must not be nil.
 *
 * @return successfor instance.
 */
+ (nonnull instancetype)newWithSuccessObject:(nonnull T)obj;

/**
 * Construct for failed computation.
 *
 * @param error The error that resulted from the failed computation. `error` must not be nil.
 */
+ (nonnull instancetype)newWithError:(nonnull NSError *)error;

/**
 * Construct for a computation where the result is determined from the `success` parameter without any result object
 * in the successful case.
 *
 * The following must hold: `(success && obj && !error) || (!success && !obj && error)`.
 *
 * @param success Whether the computation was successful.
 * @param error The error if the computation failed (otherwise `nil`).
 * @return The appropriate instance.
 */
+ (nonnull instancetype)newWithComputationSuccess:(BOOL)success error:(nullable NSError *)error;

/**
 * Construct for a computation where the result is determined from the `success` parameter.
 * The following must hold: `(success && obj && !error) || (!success && !obj && error)`.
 *
 * @param success Whether the computation was successful.
 * @param obj The result if the computation was successful (otherwise `nil`).
 * @param error The error if the computation failed (otherwise `nil`).
 * @return The appropriate instance.
 */
+ (nonnull instancetype)newWithComputationSuccess:(BOOL)success
successObject:(nullable T)obj
error:(nullable NSError *)error;

/**
 * Construct for a computation where the result is determined from the `obj` parameter.
 * If `obj` is `nil`, then `instance.isSuccess` will return `NO`.
 *
 * @param obj The result if the computation was successful (otherwise `nil`).
 * @param error The error if the computation failed (otherwise `nil`).
 * @return The appropriate instance.
 */
+ (nonnull instancetype)newWithSuccessObject:(nullable id)obj
error:(nullable NSError *)error;

/**
 * Return whether the computation was successful and if not, set the error object. This can be very handy
 * when returning from method depending on the state in the BRUEitherErrorOrSuccess object.
 *
 * @param error The error to set if not successful
 * @return `YES` if successful, `NO` otherwise
 */
- (BOOL)returnComputationSuccessAndSetError:(BRUOutError)error;

/**
 * Return the object for successful computations and, if not, set the error object and return nil.
 * This can be very handy when returning from method depending on the state in a BRUEitherErrorOrSuccess object
 * constructed with newWithComputationSuccess:successObject:error:.
 *
 * @param error The error to set if not successful
 * @return The result object if the computation was successful (otherwise `nil`).
 */
- (nullable T)returnComputationSuccessObjectAndSetError:(BRUOutError)error;

@end
