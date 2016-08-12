//
//  Copyright (C) 2013-2016, Bromium Inc.
//
//  This software may be modified and distributed under the terms
//  of the BSD license.  See the LICENSE file for details.
//
//  Created by Steve Flack on 27/02/2013.
//

#import <Foundation/Foundation.h>

#import "BRUBaseDefines.h"

@interface BRUFileMonitor : NSObject

@property (nonatomic, strong, readonly, nonnull) NSString *path;
@property (atomic, assign, readonly) BOOL isMonitoring;

- (nonnull instancetype)initWithPath:(nonnull NSString *)path;
- (nonnull instancetype)initWithPath:(nonnull NSString *)path completionQueue:(nonnull dispatch_queue_t)completionQueue;

- (BOOL)startWithError:(BRUOutError)error
              callback:(void (^ _Nonnull)(BRUFileMonitor * _Nonnull monitor))callback;

- (BOOL)stop:(BRUOutError)error;

@end

