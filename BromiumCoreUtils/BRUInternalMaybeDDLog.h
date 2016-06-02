//
//  BRUInternalMaybeDDLog.h
//  BromiumUtils
//
//  Created by Johannes Weiß on 16/04/2015.
//  Copyright (c) 2015 Bromium UK Ltd. All rights reserved.
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
