//
//  Copyright (C) 2013-2016, Bromium Inc.
//
//  This software may be modified and distributed under the terms
//  of the BSD license.  See the LICENSE file for details.
//
//  Created by Johannes Weiß on 16/04/2015.
//

#import "BRUInternalMaybeDDLog.h"

@implementation _BRUInternalMaybeDDLog

+ (BOOL)isDDLogPresentAndHasRegisteredLoggers
{
    SEL sel = NSSelectorFromString(@"allLoggers");
    Class clazz = NSClassFromString(@"DDLog");
    IMP imp = [clazz methodForSelector:sel];
    NSArray *(*allLoggersFunc)(id, SEL) = (NSArray *(*)(id a , SEL b))imp;
    if (allLoggersFunc) {
        NSArray *allLoggers = allLoggersFunc(clazz, sel);
        if (allLoggers && allLoggers.count > 0) {
            return YES;
        } else {
            return NO;
        }
    } else {
        return NO;
    }
}

+ (BOOL)maybeDDLogErrorWithFile:(const char *)file
                           line:(NSUInteger)line
                       function:(const char *)function
                        message:(NSString *)message
{
    if (![_BRUInternalMaybeDDLog isDDLogPresentAndHasRegisteredLoggers]) {
        return NO;
    }
    SEL selLog = NSSelectorFromString(@"log:level:flag:context:file:function:line:tag:format:");
    Class clazz = NSClassFromString(@"DDLog");
    IMP impLog = [clazz methodForSelector:selLog];
    void (*funcLog)(id,
                    SEL,
                    BOOL,
                    NSUInteger, /* DDLogLevel */
                    NSUInteger, /* DDLogFlag */
                    NSInteger,
                    const char *,
                    const char *,
                    NSUInteger,
                    id,
                    NSString *,
                    ...) = (void (*)(__unused id a,
                                     __unused SEL b,
                                     __unused BOOL c ,
                                     __unused NSUInteger d,
                                     __unused NSUInteger e,
                                     __unused NSInteger f,
                                     __unused const char *g,
                                     __unused const char *h,
                                     __unused NSUInteger i,
                                     __unused id j,
                                     __unused NSString *k,
                                     ...))impLog;
    if ([clazz respondsToSelector:selLog]) {
        funcLog(clazz,
                selLog,
                YES,
                1 /* DDLogLevel Error */,
                1 /* DDLogFlagError */,
                0,
                file,
                function,
                line,
                NULL,
                message);
        return YES;
    } else {
        NSLog(@"ERROR: BRUInternalMaybeDDLog: DDLog initialised but selector not found!");
        return NO;
    }
}

+ (void)tryDDLogErrorOrElseNSLogWithFile:(const char *)file
                                    line:(NSUInteger)line
                                function:(const char *)function
                                 message:(NSString *)message
{
    if (![_BRUInternalMaybeDDLog maybeDDLogErrorWithFile:file
                                                    line:line
                                                function:function
                                                 message:message]) {
        NSLog(@"ERROR in file '%s', function '%s', line %lu: %@", file, function, line, message);
    }
}



@end
