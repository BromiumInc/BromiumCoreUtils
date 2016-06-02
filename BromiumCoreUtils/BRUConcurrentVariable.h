//
//  BRUConcurrentVariable.h
//  BromiumUtils
//
//  Created by Johannes Weiß on 25/03/2015.
//  Copyright (c) 2015 Bromium UK Ltd. All rights reserved.
//

#import "BRUBaseDefines.h"

BRU_assume_nonnull_begin

/**
 * A BRUConcurrentVariable is a shared memory location that supports atomic memory transactions.
 * The value inside a BRUConcurrentVariable can never be `nil`.
 *
 * BRUConcurrentVariable really works like a normal variable except that it's thread-safe, similar to an
 * `@property (nonnull, atomic, readwrite, strong)` in Objective-C.
 *
 * This class is modelled after Haskell STM's TVar (https://hackage.haskell.org/package/stm-2.4.4/docs/Control-Concurrent-STM-TVar.html)
 */
BRU_restrict_subclassing @interface BRUConcurrentVariable<T> : NSObject

BRU_DEFAULT_INIT_UNAVAILABLE()

/**
 * Create a new BRUConcurrentVariable with a value which cannot be `nil`.
 *
 * @param value The value to initialise the variable with.
 * @return A new BRUConcurrentVariable instance set to `value`.
 */
+ (instancetype)newWithValue:(T)value;

/**
 * Read the stored value.
 *
 * @return The stored value.
 */
- (T)readVariable;

/**
 * Write a new value.
 *
 * @param newValue The new value to write (cannot be `nil`).
 */
- (void)writeVariableWithValue:(T)newValue;

/**
 * Swap the current value with `newValue`.
 *
 * @param newValue The new value to write (non-nil).
 * @return The old value (before the swap).
 */
- (T)swapVariableWithValue:(T)newValue;

/**
 * Atomically change the current value to the value returned by `modifyBlock`. This method is for example useful to
 * implement "compare and set".
 *
 * @param modifyBlock `modifyBlock` gets passed the current value and is supposed to return a new non-nil value.
 * @return The old, overridden value.
 */
- (T)modifyVariableWithBlock:(T(^)(T))modifyBlock;

@end

BRU_assume_nonnull_end
