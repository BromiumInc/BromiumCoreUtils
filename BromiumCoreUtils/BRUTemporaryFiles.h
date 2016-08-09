//
//  Copyright (C) 2013-2016, Bromium Inc.
//
//  This software may be modified and distributed under the terms
//  of the BSD license.  See the LICENSE file for details.
//
//  Created by Johannes Weiß on 15/04/2013.
//

#import <Foundation/Foundation.h>

#import "BRUBaseDefines.h"

/**
 * Easily and safely generating temporary files.
 *
 * Besides the documented functions below, this module also contains similar convenience methods having less parameters.
 */
@interface BRUTemporaryFiles : NSObject

/**
 * Create and open a temporary file.
 *
 * You should prefer this method over createTemporaryFileInDirectory:error: whenever possible.
 *
 * @param basenameTemplate Template for the basename of the new temporary file (must end in `XXXXXX`).
 * @param suffix Suffix string to append to basenameTemplate. May be `nil` if no suffix is required.
 * @param dir Directory in which to create the temporary file (may be `Nil` meaning standard temporary directory).
 * @param outFilename If successful, the filename of the opened temporary file will be written there.
 * @param error If unsuccessful, an appropriate error will be written there.
 * @return A file handle opened for reading and writing or `Nil` on failure.
 */
+ (nullable NSFileHandle *)openTemporaryFileWithBasenameTemplate:(nonnull NSString *)basenameTemplate
                                                          suffix:(nullable NSString *)suffix
                                                     inDirectory:(nullable NSString *)dir
                                                     outFilename:(NSString * _Nullable __autoreleasing * _Nullable)outFilename
                                                           error:(BRUOutError)error;

+ (nullable NSFileHandle *)openTemporaryFileWithBasenameTemplate:(nonnull NSString *)basenameTemplate
                                                     inDirectory:(nullable NSString *)dir
                                                     outFilename:(NSString * _Nullable __autoreleasing * _Nullable)outFilename
                                                           error:(BRUOutError)error;

+ (nullable NSFileHandle *)openTemporaryFileInDirectory:(nullable NSString *)dir
                                            outFilename:(NSString * _Nullable __autoreleasing * _Nullable)outFilename
                                                  error:(BRUOutError)error;

+ (nullable NSFileHandle *)openTemporaryFileInDirectory:(nullable NSString *)dir
                                                  error:(BRUOutError)error;

+ (nullable NSFileHandle *)openTemporaryFileWithSuffix:(nullable NSString *)suffix
                                           outFilename:(NSString * _Nullable __autoreleasing * _Nullable)outFilename
                                                 error:(BRUOutError)error;

+ (nullable NSFileHandle *)openTemporaryFileWithSuffix:(nullable NSString *)suffix
                                                 error:(BRUOutError)error;

+ (nullable NSFileHandle *)openTemporaryFileError:(BRUOutError)error;

/**
 * Create a temporary file.
 *
 * @param basenameTemplate Template for the basename of the new temporary file (must end in `XXXXXX`).
 * @param suffix Suffix string to append to basenameTemplate. May be `nil` if no suffix is required.
 * @param dir Directory in which to create the temporary file (may be `Nil` meaning standard temporary directory).
 * @param error If unsuccessful, an appropriate error will be written there.
 * @return The file name of the temporary file or `Nil` on failure.
 *
 * @warning There is a small race condition when using file names. The file could already be unlinked by someone else
 * or worse: Be symlinked to another path. Whenever possible, prefer openTemporaryFileInDirectory:outFilename:error:
 */
+ (nullable NSString *)createTemporaryFileWithBasenameTemplate:(nonnull NSString *)basenameTemplate
                                                        suffix:(nullable NSString *)suffix
                                                   inDirectory:(nullable NSString *)dir
                                                         error:(BRUOutError)error;

+ (nullable NSString *)createTemporaryFileWithBasenameTemplate:(nonnull NSString *)basenameTemplate
                                                   inDirectory:(nullable NSString *)dir
                                                         error:(BRUOutError)error;

+ (nullable NSString *)createTemporaryFileInDirectory:(nullable NSString *)dir
                                               error:(BRUOutError)error;

+ (nullable NSString *)createTemporaryFileWithSuffix:(nullable NSString *)suffix
                                               error:(BRUOutError)error;

+ (nullable NSString *)createTemporaryFileError:(BRUOutError)error;

/**
 * Create a temporary directory. Internally uses `mkdtemp()`.
 *
 * @param basenameTemplate Template for the basename of the new directory (must end in `XXXXXX`).
 * @param dir Directory in which to create the temporary directory (may be `Nil` meaning standard temporary directory).
 * @param error If unsuccessful, an appropriate error will be written there.
 * @return The file name of the temporary directory or `Nil` on failure.
 */
+ (nullable NSString *)createTemporaryDirectoryWithBasenameTemplate:(nonnull NSString *)basenameTemplate
                                                        inDirectory:(nullable NSString *)dir
                                                              error:(BRUOutError)error;

+ (nullable NSString *)createTemporaryDirectoryInDirectory:(nullable NSString *)dir
                                                     error:(BRUOutError)error;

+ (nullable NSString *)createTemporaryDirectoryError:(BRUOutError)error;

@end
