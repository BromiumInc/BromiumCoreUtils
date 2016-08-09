//
//  Copyright (C) 2013-2016, Bromium Inc.
//
//  This software may be modified and distributed under the terms
//  of the BSD license.  See the LICENSE file for details.
//
//  Created by Jason Morley on 19/02/2015.
//

#import "BRUDispatchUtils.h"
#import "BRUAsserts.h"
#import "BRUDeferred.h"

typedef NS_ENUM(NSUInteger, BRUPromiseState) {
    BRUPromiseStatePending = 1,
    BRUPromiseStateResolved = 2,
};

@interface BRUDeferred () <BRUPromise>

@property (nonatomic, strong, readonly) dispatch_queue_t syncQueue;
@property (nonatomic, strong, readonly) dispatch_queue_t completionQueue;

/**
 * Accessed on syncQueue.
 */
@property (nonatomic, strong, readonly) NSMutableArray *thenBlocks;

/**
 * Accessed on syncQueue.
 */
@property (nonatomic, strong, readwrite) id value;

/**
 * Accessed on syncQueue.
 */
@property (nonatomic, assign, readwrite) BRUPromiseState state;

@end

@implementation BRUDeferred

+ (nonnull instancetype)deferred
{
    return [self new];
}

+ (nonnull instancetype)deferredWithTargetQueue:(nullable dispatch_queue_t)targetQueue
{
    return [[self alloc] initWithTargetQueue:targetQueue];
}

- (nonnull instancetype)init
{
    return [self initWithTargetQueue:nil];
}

- (nonnull instancetype)initWithTargetQueue:(nullable dispatch_queue_t)targetQueue
{
    self = [super init];
    if (self) {

        _syncQueue = bru_dispatch_queue_create("com.bromium.BromiumUtils.BRUPromise.syncQueue",
                                               DISPATCH_QUEUE_SERIAL);
        if (targetQueue) {
            _completionQueue = targetQueue;
        } else {
            _completionQueue = bru_dispatch_queue_create("com.bromium.BromiumUtils.BRUPromise.completionQueue",
                                                         DISPATCH_QUEUE_CONCURRENT);
        }
        _thenBlocks = [NSMutableArray array];
        _value = nil;
        _state = BRUPromiseStatePending;
    }
    return self;
}

+ (NSString *)stringForState:(BRUPromiseState)state
{
    if (state == BRUPromiseStatePending) {
        return @"pending";
    } else if (state == BRUPromiseStateResolved) {
        return @"resolved";
    } else {
        return @"unknown";
    }
}

- (void)resolve:(nullable id)value
{
    dispatch_async(self.syncQueue, ^{

        BRUAssert(self.state == BRUPromiseStatePending,
                  @"Attempt to resolve a %@ promise", [BRUDeferred stringForState:self.state]);

        self.state = BRUPromiseStateResolved;
        self.value = value;
        [self processBlocks];

    });
}

- (nonnull id<BRUPromise>)promise
{
    return self;
}

#pragma mark - BRUPromise

- (void)then:(nonnull BRUPromiseThenBlock)block
{
    BRUParameterAssert(block);

    dispatch_async(self.syncQueue, ^{

        [self.thenBlocks addObject:[block copy]];
        [self processBlocks];

    });
}

- (void)processBlocks
{
    BRU_ASSERT_ON_QUEUE(self.syncQueue);

    if (self.state == BRUPromiseStatePending) {

        return;

    } else if (self.state == BRUPromiseStateResolved) {

        for (BRUPromiseThenBlock block in self.thenBlocks) {

            dispatch_async(self.completionQueue, ^{

                block(self.value);

            });

        }
        [self.thenBlocks removeAllObjects];

    } else {

        BRU_ASSERT_NOT_REACHED(@"Unknown state %ld", self.state);

    }
}

@end
