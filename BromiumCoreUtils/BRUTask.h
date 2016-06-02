//
//  BRUTask.h
//  BromiumUtils
//
//  Created by Johannes Weiß on 31/05/2016.
//  Copyright © 2016 Bromium UK Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "BRUBaseDefines.h"

/**
 * This is a drop-in replacement for NSTask. Everything but the launch method (which doesn't throw excetions in the
 * case of BRUTask) should be the same.
 *
 * BRUTask now adds some BRUTask specific features (such as launch a task which is not a session leader itself).
 *
 * @see NSTask
 */
BRU_restrict_subclassing
@interface BRUTask : NSObject

@property (atomic, readwrite, copy) NSString *launchPath;
@property (atomic, readwrite, copy) NSArray *arguments;
@property (atomic, readwrite, copy) NSDictionary *environment;
@property (atomic, readwrite, copy) NSString *currentDirectoryPath;
@property (atomic, readwrite, strong) id standardInput;
@property (atomic, readwrite, strong) id standardOutput;
@property (atomic, readwrite, strong) id standardError;
@property (atomic, readwrite, copy) void (^terminationHandler)(BRUTask *);

@property (atomic, readonly, assign, getter = isRunning) BOOL running;
@property (atomic, readonly, assign) pid_t processIdentifier;
@property (atomic, readonly, assign) int terminationStatus;
@property (atomic, readonly, assign) NSTaskTerminationReason terminationReason;

/**
 * Specifies whether the launched task is its own session leader. Default is `YES` for compatibility with `NSTask`.
 *
 * This is a feature only available in BRUTask, not in NSTask.
 */
@property (atomic, readwrite, assign) BOOL spawnAsSessionLeader;


- (id)init;

- (BOOL)launchWithError:(NSError **)error;

- (void)interrupt;
- (void)terminate;

- (BOOL)suspend;
- (BOOL)resume;

@end

@interface BRUTask (BRUTaskConveniences)

+ (BRUTask *)launchedTaskWithLaunchPath:(NSString *)path arguments:(NSArray *)arguments;
- (void)waitUntilExit;

@end
