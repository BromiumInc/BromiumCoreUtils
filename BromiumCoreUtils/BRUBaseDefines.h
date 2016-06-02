//
//  BRUBaseDefines.h
//  BromiumUtils
//
//  Created by Johannes Weiß on 01/06/2016.
//  Copyright © 2016 Bromium UK Ltd. All rights reserved.
//

@class NSError;

#define BRUErrorReasonKey @"reason"
#define BRU_assume_nonnull_begin _Pragma("clang assume_nonnull begin")
#define BRU_assume_nonnull_end _Pragma("clang assume_nonnull end")

#define BRU_likely(x) __builtin_expect((x),1)
#define BRU_unlikely(x) __builtin_expect((x),0)

#define BRU_restrict_subclassing __attribute__((objc_subclassing_restricted))

typedef NSError * _Nullable __autoreleasing * _Nullable BRUOutError;

#define BRU_DEFAULT_INIT_UNAVAILABLE(nullability) /*
*/+ (nullability instancetype)new __attribute__((unavailable("new not available"))); /*
*/- (nullability instancetype)init __attribute__((unavailable("init not available"))); /*
*/

#define BRU_DEFAULT_INIT_UNAVAILABLE_IMPL /*
*/- (instancetype)init/*
*/{/*
*/    BRU_ASSERT_NOT_REACHED(@"default init unavailable");/*
*/}/*
*/

#define BRU_ASSIGN_OUT_PTR(_var, ...) do { if ((_var)) { *(_var) = (__VA_ARGS__); } } while (false)
