//
//  Copyright (C) 2013-2016, Bromium Inc.
//
//  This software may be modified and distributed under the terms
//  of the BSD license.  See the LICENSE file for details.
//
//  Created by Johannes Weiß on 01/06/2016.
//

#include <stdio.h>
#include <assert.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSThread.h>

#import "BRUInternalMaybeDDLog.h"
#import "BRUAsserts.h"

void _bru_bold_complain(const char * __nonnull msg,
                        const char * __nonnull file,
                        unsigned int line,
                        const char * __nonnull fun) {
    [_BRUInternalMaybeDDLog tryDDLogErrorOrElseNSLogWithFile:file
                                                        line:line
                                                    function:fun
                                                     message:[NSString stringWithFormat:@"%s", msg]];
    fprintf(stderr, "ERROR: %s\n", msg);
    fflush(stderr);
}


__attribute__((noreturn)) void _bru_bold_complain_and_die(const char * __nonnull msg,
                                                          const char * __nonnull file,
                                                          unsigned int line,
                                                          const char * __nonnull fun) {
    _bru_bold_complain(msg, file, line, fun);
    NSArray *css = [NSThread callStackSymbols];
    [_BRUInternalMaybeDDLog tryDDLogErrorOrElseNSLogWithFile:file
                                                        line:line
                                                    function:fun
                                                     message:[NSString stringWithFormat:@"%@", css]];
    fprintf(stderr, "%s\n", [[css description] UTF8String]);
    fflush(stderr);
    __assert(msg, file, line);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunreachable-code"
    abort(); /* just to be absolutely sure */
#pragma clang diagnostic pop
}
