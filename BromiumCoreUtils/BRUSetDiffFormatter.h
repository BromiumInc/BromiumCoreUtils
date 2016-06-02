//
//  BRUSetDiffFormatter.h
//  BromiumUtils
//
//  Created by Johannes Weiß on 01/06/2016.
//  Copyright © 2016 Bromium UK Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString const *kBRUSetDiffFormatterOptionMaxDiffPrints;

@interface BRUSetDiffFormatter : NSObject

+ (NSString *)formatDiffWithSet:(NSSet *)orig andSet:(NSSet *)new options:(NSDictionary *)options;

@end
