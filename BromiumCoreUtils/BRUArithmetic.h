//
//  BRUArithmetic.h
//  BromiumUtils
//
//  Created by Jason Barrie Morley on 07/01/2016.
//  Copyright © 2016 Bromium UK Ltd. All rights reserved.
//

#include <stdbool.h>
#include <float.h>
#include <OpenGL/CGLTypes.h>
#include <OpenGL/gl.h>
#include <CoreGraphics/CoreGraphics.h>

#import "BRUAsserts.h"

_Static_assert((sizeof(int32_t) * 8) - 1 > FLT_MANT_DIG, "Unable to represent the float mantissa in int32_t");
_Static_assert((sizeof(int64_t) * 8) - 1 > DBL_MANT_DIG, "Unable to represent the double mantissa in int64_t");

/**
 * The largest int32_t that can be perfectly represented within a float.
 */
#define BRU_SAFE_FLOAT_MAX (((int32_t)1 << FLT_MANT_DIG) - 1)

/**
 * The smallest int32_t that can be perfectly represented within a float.
 */
#define BRU_SAFE_FLOAT_MIN (BRU_SAFE_FLOAT_MAX * -1)

/**
 * The largest int64_t that can be perfectly represented within a double.
 */
#define BRU_SAFE_DOUBLE_MAX (((int64_t)1 << DBL_MANT_DIG) - 1)

/**
 * The smallest int64_t that can be perfectly represented within a double.
 */
#define BRU_SAFE_DOUBLE_MIN (BRU_SAFE_DOUBLE_MAX * -1)

/**
 * Convert a double, a, to a uint32_t, storing the result in result.
 *
 * The return value indivates whether the operation could be completed safely.
 *
 * Safe input values of a are bounded by 0.0f and UINT32_MAX.
 *
 * true if the operation was successful; otherwise, false.
 */
__attribute__((warn_unused_result))
inline static bool bru_double_to_uint32(double a, uint32_t * __nonnull result) {
    BRUParameterAssert(result);
    if (a < 0.0 || a > (double)UINT32_MAX) {
        return false;
    }

    *result = (uint32_t)a;
    return true;
}

/**
 * Convert a CGFloat, a, to a uint32_t, storing the result in result.
 *
 * The return value indivates whether the operation could be completed safely.
 *
 * Safe input values of a are bounded by 0.0f and UINT32_MAX.
 *
 * true if the operation was successful; otherwise, false.
 */
__attribute__((warn_unused_result))
inline static bool bru_cgfloat_to_uint32(CGFloat a, uint32_t * __nonnull result) {
    _Static_assert(__builtin_types_compatible_p(CGFloat, double),
                   "CGFloat and double are incompatible");
    BRUParameterAssert(result);
    return bru_double_to_uint32(a, result);
}

/**
 * Convert a size_t, a, to an int32_t, storing the result in result.
 *
 * The return value indivates whether the operation could be completed safely.
 *
 * Safe input values of a are bounded by 0 and INT32_MAX.
 *
 * true if the operation was successful; otherwise, false.
 */
__attribute__((warn_unused_result))
inline static bool bru_size_to_int32(size_t a, int32_t * __nonnull result) {
    _Static_assert(sizeof(size_t) > sizeof(int32_t),
                   "size_t and int32_t are incompatible");
    BRUParameterAssert(result);
    if (a > (size_t)INT32_MAX) {
        return false;
    }
    *result = (int32_t)a;
    return true;
}

/**
 * Convert a float, a, to an int32_t, storing the result in result.
 *
 * The return value indivates whether the operation could be completed safely.
 *
 * Safe input values of a are bounded by BRU_SAFE_FLOAT_MIN and BRU_SAFE_FLOAT_MAX.
 *
 * true if the operation was successful; otherwise, false.
 */
__attribute__((warn_unused_result))
inline static bool bru_float_to_int32(float a, int32_t * __nonnull result) {
    BRUParameterAssert(result);
    if (a < (float)BRU_SAFE_FLOAT_MIN ||
        a > (float)BRU_SAFE_FLOAT_MAX) {
        return false;
    }
    *result = (int32_t)a;
    return true;
}

/**
 * Convert a double, a, to an int32_t, storing the result in result.
 *
 * The return value indivates whether the operation could be completed safely.
 *
 * Safe input values of a are bounded by INT32_MIN and INT32_MAX.
 *
 * true if the operation was successful; otherwise, false.
 */
__attribute__((warn_unused_result))
inline static bool bru_double_to_int32(double a, int32_t * __nonnull result) {
    BRUParameterAssert(result);
    if (a < (double)INT32_MIN ||
        a > (double)INT32_MAX) {
        return false;
    }
    *result = (int32_t)a;
    return true;
}

/**
 * Convert a CGFloat, a, to an int32_t, storing the result in result.
 *
 * The return value indivates whether the operation could be completed safely.
 *
 * Safe input values of a are bounded by INT32_MIN and INT32_MAX.
 *
 * true if the operation was successful; otherwise, false.
 */
__attribute__((warn_unused_result))
inline static bool bru_cgfloat_to_int32(CGFloat a, int32_t * __nonnull result) {
    _Static_assert(__builtin_types_compatible_p(CGFloat, double),
                   "CGFloat and double are incompatible");
    BRUParameterAssert(result);
    return bru_double_to_int32(a, result);
}

/**
 * Convert a size_t, a, to a GLsizei, storing the result in result.
 *
 * The return value indivates whether the operation could be completed safely.
 *
 * Safe input values of a are bounded by 0 and INT32_MAX.
 *
 * true if the operation was successful; otherwise, false.
 */
__attribute__((warn_unused_result))
inline static bool bru_size_to_glsizei(size_t a, GLsizei * __nonnull result) {
    _Static_assert(__builtin_types_compatible_p(GLsizei, int32_t),
                   "GLsizei and int32_t are incompatible");
    BRUParameterAssert(result);
    return bru_size_to_int32(a, result);
}

/**
 * Convert a CGFloat, a, to a GLsizei, storing the result in result.
 *
 * The return value indivates whether the operation could be completed safely.
 *
 * Safe input values of a are bounded by INT32_MIN and INT32_MAX.
 *
 * true if the operation was successful; otherwise, false.
 */
__attribute__((warn_unused_result))
inline static bool bru_cgfloat_to_glsizei(CGFloat a, int32_t * __nonnull result) {
    _Static_assert(__builtin_types_compatible_p(CGFloat, double),
                   "CGFloat and double are incompatible");
    _Static_assert(__builtin_types_compatible_p(GLsizei, int32_t),
                   "GLsizei and int32_t are incompatible");
    BRUParameterAssert(result);
    return bru_double_to_int32(a, result);
}

/**
 * Convert a GLsizei, a, to a size_t, storing the result in result.
 *
 * The return value indivates whether the operation could be completed safely.
 *
 * Safe input values of a are bounded by 0 and INT32_MAX.
 *
 * true if the operation was successful; otherwise, false.
 */
__attribute__((warn_unused_result))
inline static bool bru_glsizei_to_size(GLsizei a, size_t * __nonnull result) {
    _Static_assert(sizeof(size_t) >= sizeof(GLsizei),
                   "size_t and GLsizei are incompatible");
    BRUParameterAssert(result);
    if (a < 0) {
        return false;
    }
    *result = (size_t)a;
    return true;
}

/**
 * Convert a ptrdiff_t, a, to a size_t, storing the result in result.
 *
 * The return value indivates whether the operation could be completed safely.
 *
 * Safe input values of a are bounded by 0 and INT32_MAX.
 *
 * true if the operation was successful; otherwise, false.
 */
__attribute__((warn_unused_result))
inline static bool bru_ptrdiff_to_size(ptrdiff_t a, size_t * __nonnull result) {
    _Static_assert(sizeof(size_t) >= sizeof(ptrdiff_t),
                   "size_t and ptrdiff_t are incompatible");
    BRUParameterAssert(result);
    if (a < 0) {
        return false;
    }
    *result = (size_t)a;
    return true;
}

/**
 * Convert a double, a, to a size_t, storing the result in result.
 *
 * The return value indivates whether the operation could be completed safely.
 *
 * Safe input values of a are bounded by 0.0f and BRU_SAFE_DOUBLE_MAX.
 *
 * true if the operation was successful; otherwise, false.
 */
__attribute__((warn_unused_result))
inline static bool bru_double_to_size(double a, size_t * __nonnull result) {
    BRUParameterAssert(result);
    if (a < 0.0 || a > BRU_SAFE_DOUBLE_MAX) {
        return false;
    }

    *result = (size_t)a;
    return true;
}

/**
 * Convert a CGFloat, a, to a size_t, storing the result in result.
 *
 * The return value indivates whether the operation could be completed safely.
 *
 * Safe input values of a are bounded by 0.0f and BRU_SAFE_DOUBLE_MAX.
 *
 * true if the operation was successful; otherwise, false.
 */
__attribute__((warn_unused_result))
inline static bool bru_cgfloat_to_size(CGFloat a, size_t * __nonnull result) {
    _Static_assert(__builtin_types_compatible_p(CGFloat, double),
                   "CGFloat and double are incompatible");
    BRUParameterAssert(result);
    return bru_double_to_size(a, result);
}

/**
 * Convert a size_t, a, to a ptrdiff_t, storing the result in result.
 *
 * The return value indivates whether the operation could be completed safely.
 *
 * Safe input values of a are bounded by PTRDIFF_MAX.
 *
 * true if the operation was successful; otherwise, false.
 */
__attribute__((warn_unused_result))
inline static bool bru_size_to_ptrdiff(size_t a, ptrdiff_t * __nonnull result) {
    BRUParameterAssert(result);
    if (a > PTRDIFF_MAX) {
        return false;
    }
    *result = (ptrdiff_t)a;
    return true;
}

/**
 * Add a ptrdiff_t offset, offset, to a void * base address, base, storing the void * result in result.
 *
 * The return value indicates whether the operation completed successfully without overflowing.
 *
 * Since the operation can overflow, the return value MUST be checked to ensure safety.
 *
 * true if the operation was successful; false in the case of overflow.
 */
__attribute__((warn_unused_result))
inline static bool bru_offset_pointer(void * __nullable base, ptrdiff_t offset, void * __nonnull * __nullable result) {
    _Static_assert(__builtin_types_compatible_p(intptr_t, long),
                   "intptr_t and long are incompatible");
    _Static_assert(__builtin_types_compatible_p(ptrdiff_t, long),
                   "off_t and long are incompatible");
    BRUParameterAssert(result);

    intptr_t res = 0;

    if (__builtin_saddl_overflow((intptr_t)base, offset, &res)) {
        return false;
    }

    if (res < 0) {
        return false;
    }

    *result = (void *)res;

    return true;
}

/**
 * Add two ptrdiff_ts, a and b, storing the result in result.
 *
 * The return value indicates whether the operation completed successfully without overflowing.
 *
 * Since the operation can overflow, the return value MUST be checked to ensure safety.
 *
 * true if the operation was successful; false in the case of overflow.
 */
__attribute__((warn_unused_result))
inline static bool bru_ptrdiff_add_2(ptrdiff_t a, ptrdiff_t b,
                                     ptrdiff_t * __nonnull result) {
    _Static_assert(__builtin_types_compatible_p(intptr_t, long),
                   "intptr_t and long are incompatible");
    BRUParameterAssert(result);
    return !__builtin_saddl_overflow(a, b, result);
}

/**
 * Add two unsigned longs, a and b, storing the result in result.
 *
 * The return value indicates whether the operation completed successfully without overflowing.
 *
 * Since the operation can overflow, the return value MUST be checked to ensure safety.
 *
 * true if the operation was successful; false in the case of overflow.
 */
__attribute__((warn_unused_result))
inline static bool bru_unsigned_long_add_2(unsigned long a, unsigned long b,
                                           unsigned long * __nonnull result) {
    BRUParameterAssert(result);
    return !__builtin_uaddl_overflow(a, b, result);
}

/**
 * Add two size_ts, a and b, storing the result in result.
 *
 * The return value indicates whether the operation completed successfully without overflowing.
 *
 * Since the operation can overflow, the return value MUST be checked to ensure safety.
 *
 * true if the operation was successful; false in the case of overflow.
 */
__attribute__((warn_unused_result))
inline static bool bru_size_add_2(size_t a, size_t b,
                                  size_t * __nonnull result) {
    _Static_assert(__builtin_types_compatible_p(size_t, unsigned long),
                   "size_t and unsigned long are incompatible");
    BRUParameterAssert(result);
    return !__builtin_uaddl_overflow(a, b, result);
}

/**
 * Subtract one size_t, b, from another, a, storing the result in result.
 *
 * The return value indicates whether the operation completed successfully without overflowing.
 *
 * Since the operation can overflow, the return value MUST be checked to ensure safety.
 *
 * true if the operation was successful; false in the case of overflow.
 */
__attribute__((warn_unused_result))
inline static bool bru_size_subtract_2(size_t a, size_t b,
                                       size_t * __nonnull result) {
    _Static_assert(__builtin_types_compatible_p(size_t, unsigned long),
                   "size_t and unsigned long are incompatible");
    BRUParameterAssert(result);
    return !__builtin_usubl_overflow(a, b, result);
}

/**
 * Subtract two size_ts, b and c, from another, a, storing the result in result.
 *
 * The return value indicates whether the operation completed successfully without overflowing.
 *
 * Since the operation can overflow, the return value MUST be checked to ensure safety.
 *
 * true if the operation was successful; false in the case of overflow.
 */
__attribute__((warn_unused_result))
inline static bool bru_size_subtract_3(size_t a, size_t b, size_t c,
                                       size_t * __nonnull result) {
    _Static_assert(__builtin_types_compatible_p(size_t, unsigned long),
                   "size_t and unsigned long are incompatible");
    BRUParameterAssert(result);
    size_t ab = 0;
    if (!bru_size_subtract_2(a, b, &ab)) {
        return false;
    }
    return bru_size_subtract_2(ab, c, result);
}

/**
 * Multiply two ptrdiff_ts, a and b, storing the result in result.
 *
 * The return value indicates whether the operation completed successfully without overflowing.
 *
 * Since the operation can overflow, the return value MUST be checked to ensure safety.
 *
 * true if the operation was successful; false in the case of overflow.
 */
__attribute__((warn_unused_result))
inline static bool bru_ptrdiff_multiply_2(ptrdiff_t a, ptrdiff_t b,
                                          ptrdiff_t * __nonnull result) {
    _Static_assert(__builtin_types_compatible_p(intptr_t, long),
                   "intptr_t and long are incompatible");
    BRUParameterAssert(result);
    return !__builtin_smull_overflow(a, b, result);
}

/**
 * Multiply three ptrdiff_ts, a, b and c, storing the result in result.
 *
 * The return value indicates whether the operation completed successfully without overflowing.
 *
 * Since the operation can overflow, the return value MUST be checked to ensure safety.
 *
 * true if the operation was successful; false in the case of overflow.
 */
__attribute__((warn_unused_result))
inline static bool bru_ptrdiff_multiply_3(ptrdiff_t a, ptrdiff_t b, ptrdiff_t c,
                                          ptrdiff_t * __nonnull result) {
    BRUParameterAssert(result);
    ptrdiff_t ab = 0;
    if (!bru_ptrdiff_multiply_2(a, b, &ab)) {
        return false;
    }
    return bru_ptrdiff_multiply_2(ab, c, result);
}

/**
 * Multiply two unsigned ints, a and b, storing the result in result.
 *
 * The return value indicates whether the operation completed successfully without overflowing.
 *
 * Since the operation can overflow, the return value MUST be checked to ensure safety.
 *
 * true if the operation was successful; false in the case of overflow.
 */
__attribute__((warn_unused_result))
inline static bool bru_uint_multiply_2(unsigned int a, unsigned int b,
                                       unsigned int * __nonnull result) {
    BRUParameterAssert(result);
    return !__builtin_umul_overflow(a, b, result);
}

/**
 * Multiply three unsigned ints, a, b and c, storing the result in result.
 *
 * The return value indicates whether the operation completed successfully without overflowing.
 *
 * Since the operation can overflow, the return value MUST be checked to ensure safety.
 *
 * true if the operation was successful; false in the case of overflow.
 */
__attribute__((warn_unused_result))
inline static bool bru_uint_multiply_3(unsigned int a, unsigned int b, unsigned int c,
                                       unsigned int * __nonnull result) {
    BRUParameterAssert(result);
    unsigned int ab = 0;
    if (!bru_uint_multiply_2(a, b, &ab)) {
        return false;
    }
    return bru_uint_multiply_2(ab, c, result);
}

/**
 * Multiply two size_ts, a and b, storing the result in result.
 *
 * The return value indicates whether the operation completed successfully without overflowing.
 *
 * Since the operation can overflow, the return value MUST be checked to ensure safety.
 *
 * true if the operation was successful; false in the case of overflow.
 */
__attribute__((warn_unused_result))
inline static bool bru_size_multiply_2(size_t a, size_t b,
                                       size_t * __nonnull result) {
    _Static_assert(__builtin_types_compatible_p(size_t, unsigned long),
                   "size_t and unsigned long are incompatible");
    BRUParameterAssert(result);
    return !__builtin_umull_overflow(a, b, result);
}

/**
 * Multiply three size_ts, a, b and c, storing the result in result.
 *
 * The return value indicates whether the operation completed successfully without overflowing.
 *
 * Since the operation can overflow, the return value MUST be checked to ensure safety.
 *
 * true if the operation was successful; false in the case of overflow.
 */
__attribute__((warn_unused_result))
inline static bool bru_size_multiply_3(size_t a, size_t b, size_t c,
                                       size_t * __nonnull result) {
    _Static_assert(__builtin_types_compatible_p(size_t, unsigned long),
                   "size_t and unsigned long are incompatible");
    BRUParameterAssert(result);
    size_t ab = 0;
    if (!bru_size_multiply_2(a, b, &ab)) {
        return false;
    }
    return bru_size_multiply_2(ab, c, result);
}
