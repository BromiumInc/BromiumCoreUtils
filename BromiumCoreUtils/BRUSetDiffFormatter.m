//
//  Copyright (C) 2013-2016, Bromium Inc.
//
//  This software may be modified and distributed under the terms
//  of the BSD license.  See the LICENSE file for details.
//
//  Created by Johannes Weiß on 01/06/2016.
//

#import "BRUSetDiffFormatter.h"

NSString const *kBRUSetDiffFormatterOptionMaxDiffPrints = @"kBRUSetDiffFormatterOptionMaxDiffPrints";

@implementation BRUSetDiffFormatter

+ (NSString *)formatDiffWithSet:(NSSet *)orig andSet:(NSSet *)new options:(NSDictionary *)options
{
    NSMutableString *ret = [NSMutableString stringWithFormat:@"DIFF (%lu elements%@ --> %lu elements%@)",
                            [orig count], orig == nil ? @" <NULL>" : @"", [new count], new == nil ? @" <NULL>" : @""];
    NSMutableSet *onlyInOrig = [NSMutableSet setWithSet:orig ?: [NSSet set]];
    NSMutableSet *onlyInNew = [NSMutableSet setWithSet:new ?: [NSSet set]];
    NSNumber *maxDiffPrints = (options && options[kBRUSetDiffFormatterOptionMaxDiffPrints]) ?
    options[kBRUSetDiffFormatterOptionMaxDiffPrints] :
    @25;

    [onlyInOrig minusSet:new];
    [onlyInNew minusSet:orig];

    [ret appendFormat:@" -%lu +%lu: <", [onlyInOrig count], [onlyInNew count]];

    __block int prints = 0;
    [onlyInOrig enumerateObjectsUsingBlock:^(NSObject *obj, BOOL *stop) {
        if (++prints > [maxDiffPrints integerValue]) {
            [ret appendString:@"-... "];
            *stop = YES;
        } else {
            [ret appendFormat:@"-'%@' ", obj];
        }
    }];
    prints = 0;
    [onlyInNew enumerateObjectsUsingBlock:^(NSObject *obj, BOOL *stop) {
        if (++prints > [maxDiffPrints integerValue]) {
            [ret appendString:@"+... "];
            *stop = YES;
        } else {
            [ret appendFormat:@"+'%@' ", obj];
        }
    }];
    if (0 != [onlyInOrig count] || 0 != [onlyInNew count]) {
        [ret deleteCharactersInRange:NSMakeRange([ret length]-1, 1)];
    }
    [ret appendString:@">"];
    return ret;
}

@end
