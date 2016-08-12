//
//  Copyright (C) 2013-2016, Bromium Inc.
//
//  This software may be modified and distributed under the terms
//  of the BSD license.  See the LICENSE file for details.
//
//  Created by Jason Barrie Morley on 06/10/2015.
//

#import "BRUConcurrentBox.h"
#import "BRUDispatchUtils.h"
#import "BRUAsserts.h"
#import "BRUARCUtils.h"

#import "BRURateLimiter.h"

@interface BRURateLimiter<T> ()

@property (nonatomic, readonly, strong) dispatch_queue_t targetQueue;
@property (nonatomic, readonly, strong) dispatch_queue_t syncQueue;
@property (nonatomic, readonly, strong) BRUConcurrentBox<T> *concurrentBox;
@property (nonatomic, readonly, strong) BRURateLimiterResultBlock resultBlock;

/**
 * Synchronized on self.
 */
@property (nonatomic, readwrite, strong) void (^completionBlock)(BRURateLimiter *);

@end

@implementation BRURateLimiter

BRU_DEFAULT_INIT_UNAVAILABLE_IMPL

- (instancetype)initWithTargetQueue:(dispatch_queue_t)targetQueue
                        resultBlock:(BRURateLimiterResultBlock)resultBlock
{
    BRUParameterAssert(targetQueue);
    BRUParameterAssert(resultBlock);
    
    self = [super init];
    if (self) {
        self->_targetQueue = targetQueue;
        self->_resultBlock = resultBlock;
        self->_syncQueue = bru_dispatch_queue_create("com.bromium.BromiumUtils.BRURateLimiter.syncQueue",
                                                     DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(self->_syncQueue, self->_targetQueue);
        self->_concurrentBox = [BRUConcurrentBox emptyBox];
    }
    return self;
}

- (void)dealloc
{
    if (_completionBlock) {
        _completionBlock(self);
    }
    BRUAssertAlwaysFatal(_completionBlock == nil, @"Completion block should be nil at destruction.");
}

- (void)setResult:(id)result
{
    BRUParameterAssert(result);
    BRU_weakify(self);
    if (![self.concurrentBox trySwapWithValue:result]) {
        dispatch_async(self.syncQueue, ^{
            BRU_strongify(self);
            if (self == nil) {
                return;
            }
            [self performSetResult:[self.concurrentBox take]];
        });
    }
}

- (void)performSetResult:(id)result
{
    // Suspend the syncQueue to ensure that no further operations are performed until the delegate has
    // informed us that the current operation is complete by means of the completionBlock.
    // This is resumed in the completion block. We are guaranteed that we are never released during the completion.
    // Should the block be deallocated without being called it will be called in the class destructor through the
    // completionBlock property.
    void (^completionBlock)(BRURateLimiter *);
    @synchronized(self) {
        
        BRUAssertAlwaysFatal(self.completionBlock == nil, @"Rate limiter completion block should be non-nil.");
        
        __block BOOL completionBlockDidRun = NO;
        
        // Since this block is retained by self for cleanup purposes, it's super important that the completion block
        // does not retain self as this will lead to retain cycles.
        completionBlock = ^(BRURateLimiter *rateLimiter) {
            @synchronized(rateLimiter) {
                
                BRUAssertAlwaysFatal(completionBlockDidRun == NO,
                                     @"Rate limiter completion block cannot be called more than once.");
                completionBlockDidRun = YES;
                rateLimiter.completionBlock = nil;
                dispatch_resume(rateLimiter.syncQueue);
                
            }
        };
        
        self.completionBlock = completionBlock;
        
        dispatch_suspend(self.syncQueue);
        
    }
    
    self.resultBlock(result, ^{
        completionBlock(self);
    });
}

@end
