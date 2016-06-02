//
//  BRUTemporaryFiles.m
//  BromiumUtils
//
//  Created by Johannes Weiß on 15/04/2013.
//  Copyright (c) 2013 Bromium UK Ltd. All rights reserved.
//

#import "BRUAsserts.h"
#import "BRUTemporaryFiles.h"

#define DEFAULT_TMP_BASENAME_TEMPLATE @"BRUTemporaryFiles.XXXXXX"

@implementation BRUTemporaryFiles

#pragma mark - Open temporary file

+ (NSFileHandle *)openTemporaryFileWithBasenameTemplate:(NSString *)basenameTemplate
                                                 suffix:(NSString *)suffix
                                            inDirectory:(NSString *)dir
                                            outFilename:(NSString **)outFilename
                                                  error:(NSError **)error
{
    BRUParameterAssert(basenameTemplate);

    if (![basenameTemplate hasSuffix:@"XXXXXX"] ||
        [basenameTemplate rangeOfString:@"/"].location != NSNotFound) {
        if (error) {
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain
                                         code:EINVAL
                                     userInfo:@{NSLocalizedDescriptionKey:
                      NSLocalizedString(@"Template for template file must not be nil or contain '/' and has to end in 'XXXXXX'",
                                        nil)}];
        }
        return nil;
    }

    /* Check and convert from `NSUInteger` (unsigned long) to `int` now, so that we don't have a random cast somewhere
       else lost in the code. */
    if (suffix.length > INT_MAX || (suffix != nil && [suffix rangeOfString:@"/"].location != NSNotFound)) {
        NSError *e;
        e = [NSError errorWithDomain:NSPOSIXErrorDomain
                                code:EINVAL
                            userInfo:@{ NSLocalizedDescriptionKey: @"Suffix is too long or contains '/'" }];
        BRU_ASSIGN_OUT_PTR(error, e);
        return nil;
    }
    int suffix_length = (int)suffix.length;

    {
        NSString *template = [(dir ?: NSTemporaryDirectory()) stringByAppendingPathComponent:basenameTemplate];
        if (suffix != nil) {
            template = [template stringByAppendingString:suffix];
        }
        char *tmpPath = strdup([template fileSystemRepresentation]);
        int fd = mkstemps(tmpPath, suffix_length);

        if (fd < 0) {
            int errno_save = errno;
            BRU_ASSIGN_OUT_PTR(error,
                               [NSError errorWithDomain:NSPOSIXErrorDomain
                                                   code:errno_save
                                               userInfo:@{NSFilePathErrorKey:template?:@"<NULL>"}]);
            free(tmpPath);
            return nil;
        } else {
            NSFileHandle *fh = [[NSFileHandle alloc] initWithFileDescriptor:fd closeOnDealloc:NO];
            BRU_ASSIGN_OUT_PTR(outFilename,
                               [[NSFileManager defaultManager] stringWithFileSystemRepresentation:tmpPath
                                                                                           length:strlen(tmpPath)]);
            free(tmpPath);
            return fh;
        }
    }
}

+ (NSFileHandle *)openTemporaryFileWithBasenameTemplate:(NSString *)basenameTemplate
                                            inDirectory:(NSString *)dir
                                            outFilename:(NSString **)outFilename
                                                  error:(NSError **)error
{
    BRUParameterAssert(basenameTemplate);

    return [BRUTemporaryFiles openTemporaryFileWithBasenameTemplate:basenameTemplate
                                                             suffix:nil
                                                        inDirectory:dir
                                                        outFilename:outFilename
                                                              error:error];
}

+ (NSFileHandle *)openTemporaryFileInDirectory:(NSString *)dir
                                   outFilename:(NSString **)outFilename
                                         error:(NSError **)error
{
    return [BRUTemporaryFiles openTemporaryFileWithBasenameTemplate:DEFAULT_TMP_BASENAME_TEMPLATE
                                                             suffix:nil
                                                        inDirectory:dir
                                                        outFilename:outFilename
                                                              error:error];
}

+ (NSFileHandle *)openTemporaryFileInDirectory:(NSString *)dir
                                         error:(NSError **)error
{
    return [BRUTemporaryFiles openTemporaryFileInDirectory:dir
                                               outFilename:nil
                                                     error:error];
}

+ (NSFileHandle *)openTemporaryFileWithSuffix:(NSString *)suffix
                                  outFilename:(NSString **)outFilename
                                        error:(BRUOutError)error
{
    return [BRUTemporaryFiles openTemporaryFileWithBasenameTemplate:DEFAULT_TMP_BASENAME_TEMPLATE
                                                             suffix:suffix
                                                        inDirectory:nil
                                                        outFilename:outFilename
                                                              error:error];
}

+ (NSFileHandle *)openTemporaryFileWithSuffix:(NSString *)suffix
                                        error:(BRUOutError)error
{
    return [BRUTemporaryFiles openTemporaryFileWithSuffix:suffix
                                              outFilename:nil
                                                    error:error];
}

+ (NSFileHandle *)openTemporaryFileError:(NSError **)error
{
    return [BRUTemporaryFiles openTemporaryFileInDirectory:nil
                                               outFilename:nil
                                                     error:error];
}

#pragma mark - Create temporary file

+ (NSString *)createTemporaryFileWithBasenameTemplate:(NSString *)basenameTemplate
                                               suffix:(NSString *)suffix
                                          inDirectory:(NSString *)dir
                                                error:(NSError **)error
{
    BRUParameterAssert(basenameTemplate);

    NSString *filename = nil;
    NSFileHandle *fh = [BRUTemporaryFiles openTemporaryFileWithBasenameTemplate:basenameTemplate
                                                                         suffix:suffix
                                                                    inDirectory:dir
                                                                    outFilename:&filename
                                                                          error:error];
    if (fh != nil) {
        [fh closeFile];
        return filename;
    } else {
        return nil;
    }
}

+ (NSString *)createTemporaryFileWithBasenameTemplate:(NSString *)basenameTemplate
                                          inDirectory:(NSString *)dir
                                                error:(NSError **)error
{
    BRUParameterAssert(basenameTemplate);

    return [BRUTemporaryFiles createTemporaryFileWithBasenameTemplate:basenameTemplate
                                                               suffix:nil
                                                          inDirectory:dir
                                                                error:error];
}

+ (NSString *)createTemporaryFileInDirectory:(NSString *)dir error:(NSError **)error
{
    return [BRUTemporaryFiles createTemporaryFileWithBasenameTemplate:DEFAULT_TMP_BASENAME_TEMPLATE
                                                               suffix:nil
                                                          inDirectory:dir
                                                                error:error];
}

+ (NSString *)createTemporaryFileWithSuffix:(NSString *)suffix error:(NSError **)error
{
    return [BRUTemporaryFiles createTemporaryFileWithBasenameTemplate:DEFAULT_TMP_BASENAME_TEMPLATE
                                                               suffix:suffix
                                                          inDirectory:nil
                                                                error:error];
}

+ (NSString *)createTemporaryFileError:(NSError **)error
{
    return [BRUTemporaryFiles createTemporaryFileInDirectory:nil error:error];
}

#pragma mark - Create temporary directory

+ (NSString *)createTemporaryDirectoryInDirectory:(NSString *)dir error:(NSError **)error
{
    return [BRUTemporaryFiles createTemporaryDirectoryWithBasenameTemplate:DEFAULT_TMP_BASENAME_TEMPLATE
                                                               inDirectory:dir
                                                                     error:error];
}

+ (NSString *)createTemporaryDirectoryWithBasenameTemplate:(NSString *)basenameTemplate
                                               inDirectory:(NSString *)dir
                                                     error:(NSError **)error
{
    BRUParameterAssert(basenameTemplate);

    NSString *template = [(dir?dir:NSTemporaryDirectory()) stringByAppendingPathComponent:basenameTemplate];

    if (![basenameTemplate hasSuffix:@"XXXXXX"] ||
        [basenameTemplate rangeOfString:@"/"].location != NSNotFound) {
        if (error) {
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain
                                         code:EINVAL
                                     userInfo:@{NSLocalizedDescriptionKey:
                      NSLocalizedString(@"template template must not be nil or contain '/' and has to end in 'XXXXXX'",
                                        nil)}];
        }
        return nil;
    }

    char *tmpPath = strdup([template fileSystemRepresentation]);
    char *ret = mkdtemp(tmpPath);
    if (NULL == ret) {
        int errno_save = errno;
        BRU_ASSIGN_OUT_PTR(error,
                           [NSError errorWithDomain:NSPOSIXErrorDomain
                                               code:errno_save
                                           userInfo:@{NSFilePathErrorKey: template ?: @"<NULL>"}]);
        free(tmpPath);
        return nil;
    }

    NSString *r = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:tmpPath length:strlen(tmpPath)];
    free(tmpPath);
    return r;
}


+ (NSString *)createTemporaryDirectoryError:(NSError **)error
{
    return [BRUTemporaryFiles createTemporaryDirectoryInDirectory:nil error:error];
}


@end
