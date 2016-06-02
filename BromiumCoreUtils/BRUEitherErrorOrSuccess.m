//
//  BRUEitherErrorOrSuccess.m
//  BromiumUtils
//
//  Created by Johannes Weiß on 01/06/2016.
//  Copyright © 2016 Bromium UK Ltd. All rights reserved.
//

#import "BRUAsserts.h"
#import "BRUEitherErrorOrSuccess.h"

@interface BRUEitherErrorOrSuccess ()

@end

@implementation BRUEitherErrorOrSuccess

BRU_DEFAULT_INIT_UNAVAILABLE_IMPL

- (instancetype)initWithSuccess:(BOOL)success object:(id)object error:(NSError *)error
{
    if ((self = [super init])) {
        self->_success = success;
        if (success) {
            BRUAssert(object, @"Trying to construct successful BRUEitherErrorOrSuccess without success object");
            BRUAssert(!error, @"Trying to construct successful BRUEitherErrorOrSuccess with non-nil error object");
            self->_error = nil;
            self->_object = object;
        } else {
            BRUAssert(!object, @"Trying to construct errorneous BRUEitherErrorOrSuccess with non-nil success object");
            BRUAssert(error, @"Trying to construct errornesous BRUEitherErrorOrSuccess with nil error object");
            self->_object = nil;
            self->_error = error;
        }
    }
    return self;
}

+ (instancetype)newWithSuccess
{
    return [[BRUEitherErrorOrSuccess alloc] initWithSuccess:YES object:[NSNull null] error:nil];
}

+ (instancetype)newWithSuccessObject:(id)obj
{
    return [[BRUEitherErrorOrSuccess alloc] initWithSuccess:YES object:obj error:nil];
}

+ (instancetype)newWithError:(NSError *)error
{
    return [[BRUEitherErrorOrSuccess alloc] initWithSuccess:NO object:nil error:error];
}

+ (instancetype)newWithComputationSuccess:(BOOL)success error:(NSError *)error
{
    return [BRUEitherErrorOrSuccess newWithComputationSuccess:success successObject:[NSNull null] error:error];
}

+ (instancetype)newWithComputationSuccess:(BOOL)success successObject:(id)obj error:(NSError *)error
{
    if (success) {
        return [BRUEitherErrorOrSuccess newWithSuccessObject:obj];
    } else {
        return [BRUEitherErrorOrSuccess newWithError:error];
    }
}

+ (nonnull instancetype)newWithSuccessObject:(id)obj error:(NSError *)error
{
    if (obj) {
        return [BRUEitherErrorOrSuccess newWithSuccessObject:obj];
    } else {
        return [BRUEitherErrorOrSuccess newWithError:error];
    }
}

- (BOOL)returnComputationSuccessAndSetError:(NSError **)error
{
    if (self.success) {
        return YES;
    } else {
        BRU_ASSIGN_OUT_PTR(error, self.error);
        return NO;
    }
}

- (id)returnComputationSuccessObjectAndSetError:(NSError **)error
{
    if (self.success) {
        return self.object;
    } else {
        BRU_ASSIGN_OUT_PTR(error, self.error);
        return nil;
    }
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"BRUEitherErrorOrSuccess: %@(%@)",
            self.isSuccessful ? @"Success" : @"Error",
            self.isSuccessful ? [self.object description] : [self.error description]];
}

- (BOOL)isEqual:(id)object
{
    if ([self class] != [object class]) {
        return NO;
    }
    BRUEitherErrorOrSuccess *typedObject = object;
    return self.isSuccessful == typedObject.isSuccessful &&
    /**/((self.isSuccessful && [self.object isEqualTo:typedObject.object]) ||
         (!self.isSuccessful && [self.error isEqualTo:typedObject.error]));
}

- (NSUInteger)hash
{
    if (self.isSuccessful) {
        return [self.object hash];
    } else {
        return [self.error hash];
    }
}

@end
