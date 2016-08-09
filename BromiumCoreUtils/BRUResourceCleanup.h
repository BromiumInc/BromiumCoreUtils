//
//  Copyright (C) 2013-2016, Bromium Inc.
//
//  This software may be modified and distributed under the terms
//  of the BSD license.  See the LICENSE file for details.
//
//  Created by Johannes Weiß on 03/08/2015.
//

#import <Foundation/Foundation.h>

#import "BRUBaseDefines.h"

/**
 * This class helps with setting up a series of resources whereby any step can fail. The idea is that after each
 * individual step you perform the following work:
 *  - specify a cleanup block (`addResource*Block`) to destruct the newly successfully acquired resource in case a
 *    subsequent step fails
 *  - call `-runAllCleanupsWithError:` if your resource acquisition fails
 *
 * `-runAllCleanupsWithError:` will run all the previously added resource cleanup blocks in _reverse order_.
 *
 * If all steps succeeded, you must call `-discardAllCleanups` to tell the `BRUResourceCleanups` that it is no longer
 * needed.
 *
 * It is illegal to let a `BRUResourceCleanup` go out of scope without either calling `-discardAllCleanups` (if success)
 * or `-runAllCleanupsWithError:` (on error).
 */
@interface BRUResourceCleanup : NSObject

#pragma mark - Helpers

/**
 * Convienence method to add a resource cleanup block to just delete a file. Use this method if the resource you
 * acquired is a file or directory
 */
- (void)addCleanupBlockForDeletingFileSystemItemAtPath:(nonnull NSString *)path;

/**
 * Convenience method to add a resource cleanup block to close an open file descriptor.
 */
- (void)addCleanupBlockForClosingFileDescriptor:(int)fd;

#pragma mark - Public API

/**
 * Create a new empty resource cleanup
 */
- (nonnull instancetype)init;

/**
 * Add a fallible resource block which destructs a newly successfully acquired resource.
 */
- (void)addResourceCleanupBlock:(BOOL(^ __nonnull)(BRUOutError))cleanupBlock;

/**
 * Add a non-fallible resource block which destructs a newly successfully acquired resource.
 */
- (void)addResourceNonFallibleCleanupBlock:(void(^ __nonnull)(void))cleanupBlock;

/**
 * Runs all the previously added resource cleanup blocks in _reverse order_. This ends the lifetime of a
 * `BRUResourceCleanup` instance.
 */
- (BOOL)runAllCleanupsWithError:(BRUOutError)error;

/**
 * Discards all the resource cleanup blocks, usually because the whole resource acquisition phase was all successful.
 * This ends the lifetime of a
 * `BRUResourceCleanup` instance.
 */
- (void)discardAllCleanups;

@end
