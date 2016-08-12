//
//  Copyright (C) 2013-2016, Bromium Inc.
//
//  This software may be modified and distributed under the terms
//  of the BSD license.  See the LICENSE file for details.
//
//  Created by Johannes Weiß on 01/06/2016.
//

#ifndef BRUEqualityUtils_h
#define BRUEqualityUtils_h

#define BRUBoolIsEqualToBool(_b1, _b2) ((_b1) && (_b2) || !(_b1) && !(_b2))

/**
 * Compare two floating point numbers.
 *
 * @param x First float to compare.
 *
 * @param y Second float to compare.
 *
 * @param epsilon Comparison threshold.
 *
 * @return true if the numbers are equal within the threshold epsilon, false otherwise.
 */
static inline bool BRUFloatEquals(float x, float y, float epsilon) {
    return fabsf( x - y ) < epsilon;
}

/**
 * Compare two double-precision floating point numbers.
 *
 * @param x First double to compare.
 *
 * @param y Second double to compare.
 *
 * @param epsilon Comparison threshold.
 *
 * @return true if the numbers are equal within the threshold epsilon, false otherwise.
 */
static inline bool BRUDoubleEquals(double x, double y, double epsilon) {
    return fabs( x - y ) < epsilon;
}

#define BRUTimeIntervalEquals(_x, _y) BRUDoubleEquals(_x, _y, DBL_EPSILON)

#endif /* BRUEqualityUtils_h */
