//
//  Copyright (C) 2013-2016, Bromium Inc.
//
//  This software may be modified and distributed under the terms
//  of the BSD license.  See the LICENSE file for details.
//
//  Created by Johannes Weiß on 01/06/2016.
//

#import <Foundation/Foundation.h>

#import "BRUBaseDefines.h"
#import "BRUAsserts.h"

/**
 * Forces a value to be not `nil`. In case it's `nil`, we'll crash the program.
 * @param value The value
 * @return The value iff non-`nil`.
 */
static inline id _Nonnull BRUForceNonnull(id _Nullable value)
{
    if (value) {
        id nonnullValue = value;
        return nonnullValue;
    } else {
        BRU_ASSERT_NOT_REACHED(@"value was unexpectedly null");
    }
}

/**
 * Converts a `nullable` value into a `nonnull` one by providng a default value.
 *
 * @param maybeValue The potential value.
 * @param defaultValue The default value in case `maybeValue == nil`.
 * @return `maybeValue` iff `maybeValue != nil`, otherwise `defaultValue`
 */
static inline id _Nonnull BRUNonnull(id _Nullable maybeValue, id _Nonnull defaultValue)
{
    BRUParameterAssert(defaultValue);
    id _Null_unspecified maybeValueUnspec = maybeValue;
    return maybeValueUnspec ?: defaultValue;
}

/**
 * Check that the parameter param is not nil.
 *
 * If param is nil, error is assigned to the NSPosixErrorDomain error EINVAL.
 *
 * @param param The parameter to check.
 *
 * @param error Error pointer. Valid only when return is false.
 *
 * @return true if param is non-nil, false otherwise.
 */
#define BRUParameterNotNil(_param, ...) _BRUParameterNotNil(@"" # _param, __FUNCTION__, (_param), __VA_ARGS__)
static inline bool _BRUParameterNotNil(NSString * __nonnull name,
                                       const char * __nonnull fun,
                                       __nullable id param,
                                       BRUOutError error) {
    if (param == nil) {
        BRU_ASSIGN_OUT_PTR(error,
                           [NSError errorWithDomain:NSPOSIXErrorDomain
                                               code:EINVAL
                                           userInfo:@{BRUErrorReasonKey:
                                                          [NSString stringWithFormat:@"Parameter '%@' in '%s' should be non-nil",
                                                           name, fun]}]);
        return false;
    }
    return true;
}
