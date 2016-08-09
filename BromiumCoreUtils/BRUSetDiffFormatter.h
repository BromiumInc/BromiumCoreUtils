//
//  Copyright (C) 2013-2016, Bromium Inc.
//
//  This software may be modified and distributed under the terms
//  of the BSD license.  See the LICENSE file for details.
//
//  Created by Johannes Weiß on 01/06/2016.
//

#import <Foundation/Foundation.h>

extern NSString const *kBRUSetDiffFormatterOptionMaxDiffPrints;

@interface BRUSetDiffFormatter : NSObject

+ (NSString *)formatDiffWithSet:(NSSet *)orig andSet:(NSSet *)new options:(NSDictionary *)options;

@end
