//
//  BRUPromise.h
//  BromiumUtils
//
//  Created by Jason Morley on 19/02/2015.
//  Copyright (c) 2015 Bromium UK Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^BRUPromiseThenBlock)(id __nullable value);

@protocol BRUPromise <NSObject>

- (void)then:(nonnull BRUPromiseThenBlock)block;

@end

@interface BRUDeferred : NSObject

+ (nonnull instancetype)deferred;
+ (nonnull instancetype)deferredWithTargetQueue:(nullable dispatch_queue_t)targetQueue;
- (nonnull instancetype)initWithTargetQueue:(nullable dispatch_queue_t)targetQueue;
- (void)resolve:(nullable id)value;
- (nonnull id<BRUPromise>)promise;

@end
