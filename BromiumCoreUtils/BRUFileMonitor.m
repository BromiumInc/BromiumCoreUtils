//
//  Copyright (C) 2013-2016, Bromium Inc.
//
//  This software may be modified and distributed under the terms
//  of the BSD license.  See the LICENSE file for details.
//
//  Created by Steve Flack on 27/02/2013.
//

#include <sys/stat.h>

#import "BRUAsserts.h"
#import "BRUDispatchUtils.h"
#import "BRUARCUtils.h"
#import "BRUBaseDefines.h"
#import "BRUNullabilityUtils.h"
#import "BRUFileMonitor.h"

@interface BRUFileMonitor ()

@property (nonatomic, strong, readonly) dispatch_queue_t syncQueue;
@property (nonatomic, strong, readonly) dispatch_queue_t monitorQueue;
@property (nonatomic, strong, readonly) dispatch_queue_t completionQueue;

// Only accesses on syncQueue
@property (nonatomic, strong, readwrite) NSArray *dispatch_source_list;
@property (nonatomic, assign, readwrite) BOOL isStatValid;
@property (nonatomic, assign, readwrite) struct stat stat;
@property (nonatomic, strong, readwrite) void (^eventCallback)(BRUFileMonitor *monitor);

@end

@implementation BRUFileMonitor

#pragma mark - public interface

- (instancetype)initWithPath:(NSString *)path
{
    BRUParameterAssert(path);
    return [self initWithPath:path completionQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
}

- (instancetype)initWithPath:(NSString *)path
             completionQueue:(dispatch_queue_t)completionQueue
{
    BRUParameterAssert(path);
    BRUParameterAssert(completionQueue);
    self = [super init];
    if (nil != self) {
        _path = [path copy];
        _syncQueue = bru_dispatch_queue_create("com.bromium.BRUFileMonitor.syncQueue", DISPATCH_QUEUE_SERIAL);
        _monitorQueue = bru_dispatch_queue_create("com.bromium.BRUFileMonitor.monitorQueue", DISPATCH_QUEUE_SERIAL);
        _completionQueue = completionQueue;
        _dispatch_source_list = nil;
    }
    return self;
}

- (BOOL)startWithError:(NSError **)error
              callback:(void (^)(BRUFileMonitor* monitor))callback
{
    BRU_ASSERT_OFF_QUEUE(self.syncQueue);
    BRU_ASSERT_OFF_QUEUE(self.monitorQueue);

    if (!BRUParameterNotNil(callback, error)) {
        return NO;
    }

    __block BOOL success = YES;
    dispatch_sync(self.syncQueue, ^(){

        struct stat pre;
        if (0 != lstat([self.path fileSystemRepresentation], &pre)) {
            self.isStatValid = NO;
        } else {
            self.isStatValid = YES;
            self.stat = pre;
        }

        if (nil != self.dispatch_source_list) {
            BRU_ASSIGN_OUT_PTR(error, [NSError errorWithDomain:NSPOSIXErrorDomain
                                                          code:ENOTSUP
                                                      userInfo:@{BRUErrorReasonKey:
                                                                     @"Can't start already started monitor."}]);
            success = NO;
            return;
        }

        self.eventCallback = callback;
        [self buildMonitors];

        [self evaluateForPath:nil];
    });
    
    return success;
}

- (BOOL)stop:(NSError**)error
{
    BRU_ASSERT_OFF_QUEUE(self.syncQueue);
    BRU_ASSERT_OFF_QUEUE(self.monitorQueue);

    __block BOOL success = YES;
    dispatch_sync(self.syncQueue, ^(){

        if (nil == self.dispatch_source_list) {
            BRU_ASSIGN_OUT_PTR(error, [NSError errorWithDomain:NSPOSIXErrorDomain
                                                          code:ENOTSUP
                                                      userInfo:@{BRUErrorReasonKey:
                                                                     @"Can't stop already stopped monitor."}]);
            success = NO;
            return;
        }

        [self destroyMonitors];
        self.eventCallback = nil;
        self.isStatValid = NO;
    });

    return success;
}

- (BOOL)isMonitoring
{
    BRU_ASSERT_OFF_QUEUE(self.monitorQueue);

    __block BOOL rv;
    dispatch_sync(self.syncQueue, ^() {
        rv = self.dispatch_source_list != nil;
    });
    return rv;
}

- (void)dealloc
{
    BRUAssert(nil == self.dispatch_source_list, @"Monitor still running when dealloced");
}


#pragma mark - internal

- (void)buildMonitors
{
    BRU_ASSERT_ON_QUEUE(self.syncQueue);
    BRU_ASSERT_OFF_QUEUE(self.monitorQueue);

    BRUAssert(nil == self.dispatch_source_list, @"building monitors whilst already built");

    dispatch_group_t syncgroup = dispatch_group_create();

    NSMutableArray *srcs = [NSMutableArray array];
    NSString *subPath = @"";
    for (NSString *subPathComponent in [self.path pathComponents]) {
        subPath = [subPath stringByAppendingPathComponent:subPathComponent];
        int fd = open([subPath fileSystemRepresentation], O_EVTONLY | O_SYMLINK);
        if (fd >= 0) {
            dispatch_source_t src = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE,
                                                           (uintptr_t)fd,
                                                           DISPATCH_VNODE_DELETE |
                                                           DISPATCH_VNODE_EXTEND |
                                                           DISPATCH_VNODE_WRITE |
                                                           DISPATCH_VNODE_ATTRIB |
                                                           DISPATCH_VNODE_LINK |
                                                           DISPATCH_VNODE_RENAME |
                                                           DISPATCH_VNODE_REVOKE,
                                                           self.monitorQueue);
            BRUAssert(NULL != src, @"Failed to create dispatch src");

            BRU_weakify(self);
            dispatch_source_set_event_handler(src, ^{
                BRU_strongify(self);
                if (nil == self) {
                    return;
                }

                dispatch_async(self.syncQueue, ^() {
                    BRU_strongify(self);
                    if ((nil == self) || (nil == self.dispatch_source_list)) {
                        return;
                    }
                    [self evaluateForPath:subPath];
                });
            });
            dispatch_source_set_cancel_handler(src, ^{
                close(fd);
            });

            dispatch_group_enter(syncgroup);
            dispatch_source_set_registration_handler(src, ^{
                dispatch_group_leave(syncgroup);
            });

            [srcs addObject:src];
            dispatch_resume(src);
        }
    }
    dispatch_group_wait(syncgroup, DISPATCH_TIME_FOREVER);

    self.dispatch_source_list = srcs;
}

- (void)destroyMonitors
{
    BRU_ASSERT_ON_QUEUE(self.syncQueue);

    BRUAssert(nil != self.dispatch_source_list, @"destroying monitors when already destroyed");

    for (dispatch_source_t src in self.dispatch_source_list) {
        dispatch_source_cancel(src);
    }
    self.dispatch_source_list = nil;
}

- (void)invokeCallback
{
    BRU_ASSERT_ON_QUEUE(self.syncQueue);

    void (^eventCallback)(BRUFileMonitor *monitor) = self.eventCallback;

    BRU_weakify(self);
    dispatch_async(self.completionQueue, ^{
        BRU_strongify(self);
        if (nil == self) {
            return;
        }
        if (eventCallback) {
            eventCallback(self);
        }
    });
}

- (void)evaluateForPath:(NSString *)path
{
    BRU_ASSERT_ON_QUEUE(self.syncQueue);

    BRU_weakify(self);
    void (^resyncBlock)() = ^() {
        BRU_strongify(self);
        if ((nil == self) || (nil == self.dispatch_source_list)) {
            return;
        }
        BRU_ASSERT_ON_QUEUE(self.syncQueue);
        [self evaluateForPath:nil];
    };

    void (^rebuildBlock)() = ^() {
        [self destroyMonitors];
        [self buildMonitors];
        dispatch_async(self.syncQueue, resyncBlock);
    };

    struct stat post;
    if (0 != lstat([self.path fileSystemRepresentation], &post)) {

        if (self.isStatValid) {
            // no stat data now, but was stat data before, so file probably deleted
            [self invokeCallback];
            self.isStatValid = NO;
            rebuildBlock();
        } else {
            // no stat data now, not stat data before, so do nothing
        }

    } else {

        if (self.isStatValid) {
            // file was valid before, and now, so check if inode has changed
            if (post.st_ino != self.stat.st_ino) {

                [self invokeCallback];
                self.stat = post;

                rebuildBlock();
            } else {
                // or, if inode hasn't changed, react to fill path events, as we assume
                // dispatch_io had a reason to notify us
                if ([path isEqualToString:self.path]) {
                    [self invokeCallback];
                }
            }
        } else {
            // no stat data before, and now we have some, so file was probably created
            [self invokeCallback];

            self.isStatValid = YES;
            self.stat = post;

            rebuildBlock();
        }
    }
}


@end
