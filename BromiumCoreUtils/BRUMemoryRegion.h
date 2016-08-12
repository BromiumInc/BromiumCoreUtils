//
//  Copyright (C) 2013-2016, Bromium Inc.
//
//  This software may be modified and distributed under the terms
//  of the BSD license.  See the LICENSE file for details.
//
//  Created by Jason Barrie Morley on 14/01/2016.
//

#import <Foundation/Foundation.h>

#import "BRUArithmetic.h"

/**
 * The error domain for BRUMemoryRegion.
 */
extern NSString * __nonnull const BRUMemoryRegionErrorDomain;

/**
 * Used to indicate errors.
 */
typedef NS_ENUM(NSInteger, BRUMemoryRegionErrorCode) {

    /**
     * Attempt to create a memory region would result in an out-of-bounds error.
     */
    BRUMemoryRegionErrorOutOfBounds = 1,

};


/**
 * Constant for indicating that a sub-memory region should have a length equal to the remainder of its parent memory
 * region.
 */
extern const size_t BRUMemoryRegionRemainder;

/**
 * Structure containing the base address and length of a memory region.
 */
typedef struct {

    /**
     * Base address of the memory region.
     */
    void * const __nullable bytes;

    /**
     * Length of the memory region.
     */
    const size_t length;

} BRUMemoryRegion;

/**
 * Memory region representing a null memory region with 0 bytes and 0 length.
 */
extern const BRUMemoryRegion BRUMemoryRegionNull;

/**
 * Return a memory region with the specified base address, bytes, and length, length.
 *
 * @param bytes The base address of the memory region.
 * @param length The length of the memory region.
 *
 * @return Memory region with the specified base address and length.
 */
inline static BRUMemoryRegion BRUMemoryRegionMake(void * __nullable bytes, size_t length) {
    BRUMemoryRegion region = { bytes, length };
    return region;
}

inline static bool BRUMemoryRegionIsNull(BRUMemoryRegion region) {
    return region.bytes == NULL && region.length == 0;
}

/**
 * Return a string formatted to represent a memory region.
 *
 * @param region Memory region to examine.
 *
 * @return String representing region.
 */
inline static NSString * __nonnull NSStringFromBRUMemoryRegion(BRUMemoryRegion region) {
    return [NSString stringWithFormat:@"{bytes=%p, length=%zu}", region.bytes, region.length];
}

/**
 * Calculate the end address of the memory region, region, assigning the result to result.
 *
 * Since it's possible for the operation to overflow, this returns a BOOL indicating success or failure.
 *
 * @param region Memory region to examine.
 * @param result Out-param for the resulting address.
 *
 * @return YES if the operation was successful; otherwise, NO.
 */
inline static BOOL BRUMemoryRegionGetEnd(BRUMemoryRegion region, void * __nonnull * __nonnull result) {
    uintptr_t end = 0;
    if (!bru_unsigned_long_add_2((uintptr_t)region.bytes, region.length, &end)) {
        return NO;
    }
    *result = (void *)end;
    return YES;
}

/**
 * Return a BOOL indicating whether the first memory region, region1, is contained in the second memory region,
 * region2.
 *
 * @param region1 Memory region to examine for containment of region2.
 * @param region2 Memory region to examine for being contained in region1.
 *
 * @return YES if the memory region specified by region2 is fully contained in the memory region specified by region1;
 *         otherwise, NO.
 */
inline static BOOL BRUMemoryRegionContainsRegion(BRUMemoryRegion region1, BRUMemoryRegion region2) {

    if (region2.bytes < region1.bytes) {
        return NO;
    }

    void *end1 = 0;
    void *end2 = 0;
    if (!BRUMemoryRegionGetEnd(region1, &end1) ||
        !BRUMemoryRegionGetEnd(region2, &end2)) {
        return NO;
    }

    if (end2 > end1) {
        return NO;
    }

    return YES;
}

/**
 * Safely construct a new memory region contained within a memory region, region, at offset, offset, with length,
 * length.
 *
 * The operation will fail (indicated by a return of NO) if the specified memory region (offset or requested length) is
 * not fully contained within the parent memory region, region.
 *
 * @param region Parent memory region for which to create a sub-region.
 * @param offset Offset into the parent memory region, region. Used to calculate the base address of the new region.
 * @param length Length of the new memory region. If the special value, BRUMemoryRegionRemainder is passed, the newly
 *               created memory region will have a length equal to the remainder of region (region.length - offset).
 * @param result Out-param for the resulting region.
 *
 * @return YES if the sub-region specified by offset and length is fully contianed in the memory region specified by
 *         region; otherwise, NO.
 */
__attribute__((warn_unused_result))
inline static BOOL BRUMemoryRegionSubRegionWithOffset(BRUMemoryRegion region,
                                                      ptrdiff_t offset,
                                                      size_t length,
                                                      BRUMemoryRegion * __nonnull result) {
    // Check that the offset is greater than, or equal to, zero.
    if (offset < 0) {
        return NO;
    }

    // Calculate the new base.
    void *newBytes = 0;
    if (!bru_offset_pointer(region.bytes, offset, &newBytes)) {
        return NO;
    }

    // Cast the offset to a size_t.
    size_t offsetSize = 0;
    if (!bru_ptrdiff_to_size(offset, &offsetSize)) {
        return NO;
    }

    // Calculate the new length if required.
    size_t newLength = length;
    if (newLength == BRUMemoryRegionRemainder) {
        if (!bru_size_subtract_2(region.length, offsetSize, &newLength)) {
            return NO;
        }
    }

    // Create the new region.
    BRUMemoryRegion newRegion = BRUMemoryRegionMake(newBytes, newLength);

    // Double-check that the new region is contained within the existing region.
    if (!BRUMemoryRegionContainsRegion(region, newRegion)) {
        return NO;
    }

    // Update the result.
    *result = newRegion;

    return YES;
}


/**
 * Safely convert a CGRect to a BGLUInt32Rect, assigning the result to result.
 * Safely construct a new memory region contained within a memory region, region, at offset, offset, with length,
 * length.
 *
 * The operation will fail (indicated by a return of NO) if the specified memory region (offset or requested length) is
 * not fully contained within the parent memory region, region.
 *
 * @param region Parent memory region for which to create a sub-region.
 * @param offset Offset into the parent memory region, region. Used to calculate the base address of the new region.
 * @param length Length of the new memory region. If the special value, BRUMemoryRegionRemainder is passed, the newly
 *               created memory region will have a length equal to the remainder of region (region.length - offset).
 * @param result Out-param for the resulting region.
 * @param error On input, a pointer to an error object. If an error occurs, this pointer is set to an actual error
 *              object containing information about the error. Specify nil for this parameter if you do not want to
 *              receive error information.

 *
 * @return YES if the sub-region specified by offset and length is fully contianed in the memory region specified by
 *         region; otherwise, NO.
 */
__attribute__((warn_unused_result))
inline static BOOL BRUMemoryRegionSubRegionWithOffsetAndError(BRUMemoryRegion region,
                                                              ptrdiff_t offset,
                                                              size_t length,
                                                              BRUMemoryRegion * __nonnull result,
                                                              BRUOutError error) {
    BRUParameterAssert(result);

    if (!BRUMemoryRegionSubRegionWithOffset(region, offset, length, result)) {
        NSString *description = [NSString stringWithFormat:
                                 @"Failed to create memory sub-region from region (region=%@, offset=%td, length=%zu).",
                                 NSStringFromBRUMemoryRegion(region), offset, length];
        BRU_ASSIGN_OUT_PTR(error, [NSError errorWithDomain:BRUMemoryRegionErrorDomain
                                                      code:BRUMemoryRegionErrorOutOfBounds
                                                  userInfo:@{@"description": description}]);
        return false;
    }
    return true;
}
