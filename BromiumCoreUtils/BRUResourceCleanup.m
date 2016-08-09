//
//  Copyright (C) 2013-2016, Bromium Inc.
//
//  This software may be modified and distributed under the terms
//  of the BSD license.  See the LICENSE file for details.
//
//  Created by Johannes Weiß on 03/08/2015.
//

#import "BRUDispatchUtils.h"
#import "BRUAsserts.h"
#import "BRUResourceCleanup.h"

@interface BRUResourceCleanup ()

/* thread-safe */
@property (nonatomic, nonnull, readonly, strong) dispatch_queue_t syncQueue;

/* mutable but protected by syncQueue */
@property (nonatomic, nonnull, readonly, strong) NSMutableArray *cleanupBlocks;
@property (nonatomic, readwrite, assign) BOOL active;

@end

@implementation BRUResourceCleanup

#pragma mark - Public API

#pragma mark Public API Helpers

- (void)addCleanupBlockForDeletingFileSystemItemAtPath:(nonnull NSString *)path
{
    [self addResourceCleanupBlock:^BOOL(BRUOutError error) {
        return [[NSFileManager defaultManager] removeItemAtPath:path error:error];
    }];
}

- (void)addCleanupBlockForClosingFileDescriptor:(int)fd
{
    [self addResourceCleanupBlock:^BOOL(BRUOutError blockOutError) {
        int err = close(fd);
        int errno_save = errno;
        if (err) {
            BRU_ASSIGN_OUT_PTR(blockOutError, [NSError errorWithDomain:NSPOSIXErrorDomain
                                                                  code:errno_save
                                                              userInfo:@{BRUErrorReasonKey:
                                                                             @"closing file descriptor failed"}]);
            return NO;
        } else {
            return YES;
        }
    }];

}

#pragma mark Main Public API

- (nonnull instancetype)init
{
    if ((self = [super init])) {
        self->_syncQueue = bru_dispatch_queue_create("com.bromium.BRUResourceCleanups", DISPATCH_QUEUE_SERIAL);
        self->_cleanupBlocks = [NSMutableArray new];
        self->_active = YES;
    }
    return self;
}

- (void)addResourceCleanupBlock:(BOOL(^ __nonnull)(BRUOutError))cleanupBlock
{
    BRUParameterAssert(cleanupBlock);
    dispatch_sync(self.syncQueue, ^{
        BRUAssert(self.active, @"BRUResourceCleanup not active anymore");
        [self.cleanupBlocks addObject:cleanupBlock];
    });
}

- (void)addResourceNonFallibleCleanupBlock:(void(^ __nonnull)(void))cleanupBlock
{
    [self addResourceCleanupBlock:^BOOL(__unused BRUOutError uuE) {
        cleanupBlock();
        return YES;
    }];
}

- (BOOL)runAllCleanupsWithError:(BRUOutError)outError
{
    __block BOOL success = YES;
    dispatch_sync(self.syncQueue, ^{
        BRUAssert(self.active, @"BRUResourceCleanup not active anymore");
        NSError *error = nil;
        for (BOOL(^cleanup)(BRUOutError) in [self.cleanupBlocks reverseObjectEnumerator]) {
            success = cleanup(&error) && success;
        }
        BRU_ASSIGN_OUT_PTR(outError, error);
        self.active = NO;
        [self.cleanupBlocks removeAllObjects];
    });
    return success;
}

- (void)discardAllCleanups
{
    dispatch_sync(self.syncQueue, ^{
        self.active = NO;
        [self.cleanupBlocks removeAllObjects];
    });
}

- (void)dealloc
{
    BRUAssert(!self->_active, @"BRUResourceCleanup still active, you must either call -runAllCleanupsWithError: "
              @"or -discardAllCleanups");
}

@end
