//
//  Copyright (C) 2013-2016, Bromium Inc.
//
//  This software may be modified and distributed under the terms
//  of the BSD license.  See the LICENSE file for details.
//
//  Created by Johannes Weiß on 01/06/2016.
//

#include <stdlib.h>
#import <Foundation/NSString.h>

#import "BRUBaseDefines.h"

#ifdef __cplusplus
extern "C" {
#endif

void _bru_bold_complain(const char * __nonnull msg, const char * __nonnull file, unsigned int line, const char * __nonnull fun);
__attribute__((noreturn)) void _bru_bold_complain_and_die(const char * __nonnull msg, const char * __nonnull file, unsigned int line, const char * __nonnull fun);

#ifdef __cplusplus
}
#endif

#define _bru_assert_flavoured(flavour, c, c_str, msg) /*
*/if (BRU_unlikely(!c)) { /*
*/    flavour([[NSString stringWithFormat:@"%s:%u: failed assertion: %s (`%s')", /*
*/    __FILE__, __LINE__, (msg)?(msg):"", c_str] UTF8String] ?: "<n/a>", __FILE__, __LINE__, __PRETTY_FUNCTION__); /*
*/}

#define _bru_ASSERT_ALWAYS_FATAL(__c, __c_str, __msg) _bru_assert_flavoured(_bru_bold_complain_and_die, __c, __c_str, (__msg));

#ifdef DEBUG
#define _bru_ASSERT_DEBUG_LOG(__c, __c_str, __msg) _bru_assert_flavoured(_bru_bold_complain, __c, __c_str, (__msg));
#define _bru_ASSERT(__c, __c_str, __msg) _bru_ASSERT_ALWAYS_FATAL(__c, __c_str, (__msg))
#define _bru_ASSERT_DEBUG(__c, __c_str, __msg) _bru_ASSERT_ALWAYS_FATAL(__c, __c_str, (__msg))
#else
#define _bru_ASSERT_DEBUG_LOG(__c, __c_str, __msg) ((void)0);
#define _bru_ASSERT(__c, __c_str, __msg) _bru_ASSERT_ALWAYS_FATAL(__c, __c_str, (__msg))
#define _bru_ASSERT_DEBUG(__c, __c_str, __msg) ((void)0)
#endif

#define BRU_ASSERT_NOT_REACHED(...) do { BRUAssertAlwaysFatal(NO, __VA_ARGS__); abort(); } while (0)


/* Top-level BRUAsserts */
#pragma mark - Top-level BRUAsserts

#define BRUAssertDebugLog(_cond, ...) /*
*/do { /*
*/    bool _boolCondition = !!(_cond); /*
*/    const char *_strCondition = #_cond; /*
*/    (void)_strCondition; /*
*/    (void)_boolCondition; /*
*/    _bru_ASSERT_DEBUG_LOG(_boolCondition, _strCondition, ([[NSString stringWithFormat:__VA_ARGS__] UTF8String])); /*
*/} while(0)

#define BRUAssertAlwaysFatal(_cond, ...) /*
*/do { /*
*/    bool _boolCondition = !!(_cond); /*
*/    const char *_strCondition = #_cond; /*
*/    (void)_strCondition; /*
*/    (void)_boolCondition; /*
*/    _bru_ASSERT_ALWAYS_FATAL(_boolCondition, _strCondition, ([[NSString stringWithFormat:__VA_ARGS__] UTF8String])); /*
*/} while(0)

#define BRUAssertDebugFatal(_cond, ...) /*
*/do { /*
*/    bool _boolCondition = !!(_cond); /*
*/    const char *_strCondition = #_cond; /*
*/    (void)_strCondition; /*
*/    (void)_boolCondition; /*
*/    _bru_ASSERT_DEBUG(_boolCondition, _strCondition, ([[NSString stringWithFormat:__VA_ARGS__] UTF8String])); /*
*/} while(0)

#define BRUAssert(_cond, ...) /*
*/do { /*
*/    bool _boolCondition = !!(_cond); /*
*/    const char *_strCondition = #_cond; /*
*/    (void)_strCondition; /*
*/    (void)_boolCondition; /*
*/    _bru_ASSERT(_boolCondition, _strCondition, ([[NSString stringWithFormat:__VA_ARGS__] UTF8String])); /*
*/} while(0)

#define BRU_ASSERT_ON_MAIN_THREAD BRUAssert([NSThread isMainThread], @"not running on main thread");

#define BRU_ASSERT_ACTIVE_RUN_LOOP /*
*/    BRUAssert([[NSRunLoop currentRunLoop] currentMode] != nil || /*
*/              [NSRunLoop currentRunLoop] == [NSRunLoop mainRunLoop], @"not on active run loop")

#define BRUParameterAssert(_cond) /*
*/do { /*
*/    bool _boolCondition = !!(_cond); /*
*/    const char * _Nonnull _strCondition = #_cond; /*
*/    (void)_strCondition; /*
*/    (void)_boolCondition; /*
*/    _bru_ASSERT(_boolCondition, _strCondition, ([[NSString stringWithFormat:@"Invalid parameter not satisfying: %s", _strCondition] UTF8String])); /*
*/} while(0)
