//
//  BRUConcurrentVariable.m
//  BromiumUtils
//
//  Created by Johannes Weiß on 25/03/2015.
//  Copyright (c) 2015 Bromium UK Ltd. All rights reserved.
//

#import "BRUAsserts.h"
#import "BRUDispatchUtils.h"
#import "BRUConcurrentVariable.h"

@interface BRUConcurrentVariable<T> ()

@property (nonatomic, strong, readwrite, nonnull) T currentValue;
@property (nonatomic, strong, readonly, nonnull) dispatch_queue_t syncQ;

@end

@implementation BRUConcurrentVariable

BRU_DEFAULT_INIT_UNAVAILABLE_IMPL

- (instancetype)initWithValue:(id)value
{
    BRUParameterAssert(value);

    if ((self = [super init])) {
        self->_syncQ = bru_dispatch_queue_create("com.bromium.BRUConcurrentVariable.SyncQ",
                                                 DISPATCH_QUEUE_SERIAL);
        self->_currentValue = value;
    }

    return self;
}

+ (instancetype)newWithValue:(id)value
{
    BRUParameterAssert(value);

    return [[BRUConcurrentVariable alloc] initWithValue:value];
}

- (id)readVariable
{
    __block id value = nil;
    dispatch_sync(self.syncQ, ^{
        value = self.currentValue;
    });
    BRUAssertAlwaysFatal(value, @"BRUConcurrentVariable consistency error: stored value nil");
    return value;
}

- (void)writeVariableWithValue:(id)newValue
{
    BRUParameterAssert(newValue);
    dispatch_sync(self.syncQ, ^{
        self.currentValue = newValue;
    });
}

- (id)swapVariableWithValue:(id)newValue
{
    BRUParameterAssert(newValue);
    return [self modifyVariableWithBlock:^id(__unused id __nonnull uuOldValue) {
        return newValue;
    }];
}

- (id)modifyVariableWithBlock:(id(^)(id))modifyBlock
{
    __block id oldValue = nil;
    dispatch_sync(self.syncQ, ^{
        oldValue = self.currentValue;
        id newValue = modifyBlock(oldValue);
        BRUAssertAlwaysFatal(newValue, @"programmer error: value returned from modifyBlock nil");
        self.currentValue = newValue;
    });
    BRUAssertAlwaysFatal(oldValue, @"BRUConcurrentVariable consistency error: stored value nil");
    return oldValue;
}

@end
