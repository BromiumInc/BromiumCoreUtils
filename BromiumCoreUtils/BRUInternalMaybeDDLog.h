//
//  Copyright (C) 2013-2016, Bromium Inc.
//
//  This software may be modified and distributed under the terms
//  of the BSD license.  See the LICENSE file for details.
//
//  Created by Johannes Weiß on 16/04/2015.
//

#import <Foundation/Foundation.h>

@interface _BRUInternalMaybeDDLog : NSObject

+ (BOOL)maybeDDLogErrorWithFile:(const char *)file
                           line:(NSUInteger)line
                       function:(const char *)function
                        message:(NSString *)message;

+ (void)tryDDLogErrorOrElseNSLogWithFile:(const char *)file
                                    line:(NSUInteger)line
                                function:(const char *)function
                                 message:(NSString *)message;

@end
