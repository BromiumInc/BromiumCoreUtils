//
//  Copyright (C) 2013-2016, Bromium Inc.
//
//  This software may be modified and distributed under the terms
//  of the BSD license.  See the LICENSE file for details.
//
//  Created by Jason Barrie Morley on 06/10/2015.
//

#import <Foundation/Foundation.h>

typedef void (^BRURateLimiterCompletionBlock)(void);
typedef void (^BRURateLimiterResultBlock)(__nonnull id result, __nonnull BRURateLimiterCompletionBlock completionBlock);

@interface BRURateLimiter<T> : NSObject

BRU_DEFAULT_INIT_UNAVAILABLE(null_unspecified)

- (nonnull instancetype)initWithTargetQueue:(nonnull dispatch_queue_t)targetQueue
                                resultBlock:(nonnull BRURateLimiterResultBlock)resultBlock;
- (void)setResult:(nonnull T)result;

@end
