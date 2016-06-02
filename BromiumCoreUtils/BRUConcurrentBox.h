//
//  BRUConcurrentBox.h
//  BromiumUtils
//
//  Created by Johannes Weiß on 04/11/2013.
//  Copyright (c) 2013 Bromium UK Ltd. All rights reserved.
//

#import "BRUEitherErrorOrSuccess.h"

BRU_assume_nonnull_begin

@class BRUEitherErrorOrSuccess;

/**
 * A `BRUConcurrentBox` is a synchronising variable, used for communication between concurrent threads.
 * It can be thought of as a box, which may be empty or full.
 *
 * It's modeled after Haskell's STM TMVar
 * http://hackage.haskell.org/package/stm-2.4.2/docs/Control-Concurrent-STM-TMVar.html
 */
BRU_restrict_subclassing @interface BRUConcurrentBox<T> : NSObject

/**
 * Create an empty `BRUConcurrentBox`.
 */
+ (instancetype)emptyBox;

/**
 * Create a `BRUConcurrentBox` which contains the supplied value.
 */
+ (instancetype)boxWithValue:(id)value;

/**
 * Put a value into a `BRUConcurrentBox`. If the `BRUConcurrentBox` is currently full, put will block until the
 * `BRUConcurrentBox` is empty again.
 *
 * @param value The value to put into the box.
 */
- (void)put:(T)value;

/**
 * Try to put a value into a `BRUConcurrentBox`. If the `BRUConcurrentBox` is currently full, `NO` is returned. If
 * the `BRUConcurrentBox` used to be empty, it got filled with `value` and `YES` is returned.
 *
 * @param value The value to put into the box.
 */
- (BOOL)tryPut:(T)value;

/**
 * Takes the value out of the `BRUConcurrentBox`. If the `BRUConcurrentBox` is currently empty, `take` blocks until
 * the `BRUConcurrentBox` is full again.
 *
 * NB: The value is taken out of the `BRUConcurrentBox`. In other words it's empty after taking the value out.
 *
 * @return The value which used to be in the `BRUConcurrentBox`.
 */
- (T)take;

/**
 * Tries to take the value out of the `BRUConcurrentBox`. If the `BRUConcurrentBox` is currently empty `nil` is
 * returned. If the `BRUConcurrentBox` used to be full, the value is returned.
 *
 * @return The value which used to be in the `BRUConcurrentBox`.
 */
- (nullable T)tryTake;

/**
 * Tries to take the value out of the `BRUConcurrentBox`. This method block until the `BRUConcurrentBox` is full
 * or until `date` is reached (whichever happens first).
 *
 * @param date Date until which to block maximally.
 *
 * @return The value if the `BRUConcurrentBox` used to be full or `nil` if the timeout hit.
 */
- (nullable T)tryTakeUntil:(NSDate *)date;

/**
 * Swaps the current value inside the `BRUConcurrentBox` with a new value. Blocks until the `BRUConcurrentBox` is full.
 *
 * @param newValue The new value.
 * @return The old value.
 */
- (T)swapWithValue:(T)newValue;

/**
 * Tries to swap the current value inside the `BRUConcurrentBox` with a new value. Returns the old value is there was
 * one or `nil` if the box was empty.
 *
 * @param newValue The new value which will be put in the `BRUConcurrentBox`.
 *
 * @return The value which used to be in the `BRUConcurrentBox` or `nil` if the box was empty.
 */
- (nullable T)trySwapWithValue:(T)newValue;


/**
 * Returns whether the `BRUConcurrentBox` is currently empty.
 *
 * @return `YES` for `BRUConcurrentBox` currently empty, `NO` for currently full.
 */
- (BOOL)isEmpty;

@end

@interface BRUEitherErrorOrSuccess<T> (BRUConcurrentBox)

/**
 * Try to take a value out of `box` and time out at `date`.
 * Should a timeout occur, a descriptive `NSError` object is returned (domain `NSPOSIXErrorDomain`, code `ETIMEDOUT`).
 *
 * @param box The BRUConcurrentBox to take from.
 * @param date The timeout date.
 * @param description An optional description.
 * @return The result of the computation (might be successful or not (then with error object)), guaranteed not to be nil
 */
+ (BRUEitherErrorOrSuccess<T> *)takeFromBox:(BRUConcurrentBox<BRUEitherErrorOrSuccess<T> *> *)box
                              timeoutAtDate:(NSDate *)date
                                description:(nullable NSString *)description;

/**
 * See `takeFromBox:timeoutAtDate:description:` just without description.
 */
+ (BRUEitherErrorOrSuccess<T> *)takeFromBox:(BRUConcurrentBox<BRUEitherErrorOrSuccess<T> *> *)box
                              timeoutAtDate:(NSDate *)date;

@end


BRU_assume_nonnull_end
