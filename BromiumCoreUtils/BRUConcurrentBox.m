//
//  Copyright (C) 2013-2016, Bromium Inc.
//
//  This software may be modified and distributed under the terms
//  of the BSD license.  See the LICENSE file for details.
//
//  Created by Johannes Weiß on 04/11/2013.
//

/* Standard Library */
#import <assert.h>

/* Local Imports */
#import "BRUAsserts.h"
#import "BRUConcurrentBox.h"

@interface BRUConcurrentBox<T> ()

@property (nonatomic, strong, readonly, nonnull) NSCondition *cond;
@property (nonatomic, strong) T value;

@end

@implementation BRUConcurrentBox

+ (instancetype)emptyBox
{
    BRUConcurrentBox *box = [[BRUConcurrentBox alloc] init];
    return box;
}

+ (instancetype)boxWithValue:(id)value
{
    BRUParameterAssert(value);

    BRUConcurrentBox *box = [BRUConcurrentBox emptyBox];
    [box put:value];
    return box;
}

- (instancetype)init
{
    if ((self = [super init])) {
        self->_cond = [[NSCondition alloc] init];
        self->_value = nil;
    }
    return self;
}

- (void)put:(id)value
{
    BRUParameterAssert(value);
    @try
    {
        [self.cond lock];
        while (self.value != nil) {
            [self.cond wait];
        }
        self.value = value;
        [self.cond broadcast];
    }
    @finally {
        [self.cond unlock];
    }
}

- (BOOL)tryPut:(id)value
{
    BRUParameterAssert(value);
    @try
    {
        [self.cond lock];
        if (self.value != nil) {
            return NO;
        }
        self.value = value;
        [self.cond broadcast];

        return YES;
    }
    @finally {
        [self.cond unlock];
    }
}

- (id)take
{
    id thing = [self tryTakeUntil:[NSDate distantFuture]];
    assert(thing);
    return thing;
}

- (id)tryTakeUntil:(NSDate *)date
{
    BRUParameterAssert(date);
    @try
    {
        id value = nil;
        [self.cond lock];
        while (self.value == nil) {
            BOOL signalled = [self.cond waitUntilDate:date];
            if (!signalled) {
                return nil;
            }
        }
        value = self.value;
        self.value = nil;
        [self.cond broadcast];

        assert(value);
        return value;
    }
    @finally {
        [self.cond unlock];
    }
}

- (id)tryTake
{
    @try
    {
        id value = nil;
        [self.cond lock];
        if (self.value == nil) {
            return nil;
        }
        value = self.value;
        self.value = nil;
        [self.cond broadcast];

        assert(value);
        return value;
    }
    @finally {
        [self.cond unlock];
    }
}

- (id)swapWithValue:(id)newValue
{
    BRUParameterAssert(newValue);
    @try
    {
        id oldValue = nil;
        [self.cond lock];
        while (self.value == nil) {
            [self.cond wait];
        }
        oldValue = self.value;
        self.value = newValue;
        [self.cond broadcast];

        assert(oldValue);
        return oldValue;
    }
    @finally {
        [self.cond unlock];
    }
}

- (id)trySwapWithValue:(id)newValue
{
    BRUParameterAssert(newValue);
    @try
    {
        id oldValue = nil;
        [self.cond lock];
        oldValue = self.value;
        self.value = newValue;
        [self.cond broadcast];

        return oldValue;
    }
    @finally {
        [self.cond unlock];
    }
}

- (BOOL)isEmpty
{
    @try
    {
        [self.cond lock];

        return self.value == nil;
    }
    @finally {
        [self.cond unlock];
    }
}

@end

@implementation BRUEitherErrorOrSuccess (BRUConcurrentBox)

+ (BRUEitherErrorOrSuccess *)takeFromBox:(BRUConcurrentBox<BRUEitherErrorOrSuccess<id> *> *)box
                           timeoutAtDate:(NSDate *)date
                             description:(NSString *)description
{
    BRUParameterAssert(box);
    BRUParameterAssert(date);
    BRUEitherErrorOrSuccess *obj = [box tryTakeUntil:date];
    if (obj) {
        BRUAssert([obj isKindOfClass:[BRUEitherErrorOrSuccess class]],
                  @"object %@ of wrong class %@ put into box but", obj, [obj class]);
        return obj;
    } else {
        NSError *error = [NSError errorWithDomain:NSPOSIXErrorDomain
                                             code:ETIMEDOUT
                                         userInfo:@{BRUErrorReasonKey:
                                                        [NSString stringWithFormat:@"%@ timed out",
                                                         description ? description : @"a computation"],
                                                    @"timeout-date":date?:@"<NULL>"}];
        return [BRUEitherErrorOrSuccess newWithError:error];
    }
}


+ (BRUEitherErrorOrSuccess *)takeFromBox:(BRUConcurrentBox<BRUEitherErrorOrSuccess<id> *> *)box timeoutAtDate:(NSDate *)date
{
    return [BRUEitherErrorOrSuccess takeFromBox:box timeoutAtDate:date description:nil];
}


@end
