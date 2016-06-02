//
//  BRUTask.m
//  BromiumUtils
//
//  Created by Johannes Weiß on 31/05/2016.
//  Copyright © 2016 Bromium UK Ltd. All rights reserved.
//

#import "BRUDispatchUtils.h"
#import "BRUAsserts.h"
#import "BRUNullabilityUtils.h"
#import "BRUTask.h"

#define AssertStateInternal BRUAssert

@interface BRUTask ()

@property (atomic, readwrite, assign) pid_t processIdentifier;
@property (atomic, readwrite, assign) int terminationStatus;
@property (atomic, readwrite, assign) NSTaskTerminationReason terminationReason;
@property (atomic, readwrite, assign, getter = isRunning) BOOL running;

@property (nonatomic, readwrite, assign) BOOL wasLaunched;
@property (atomic, readwrite, assign) BOOL hasBeenWaitedOn;
@property (nonatomic, readonly, strong) dispatch_semaphore_t waitOnSemaphore;
@property (nonatomic, readwrite, strong) dispatch_source_t childExitedSrc;
@property (nonatomic, readonly, strong) dispatch_queue_t childTerminationHandlingQueue;

@end

static char **deepMallocedNullTerminatedArrayOfCUTF8StringsWithArray(NSArray *arr)
{
    if (!arr || 0 == [arr count]) {
        return NULL;
    } else {
        char **ret = malloc(([arr count] + 1) * sizeof(char *));
        for (NSUInteger i=0; i<[arr count]; i++) {
            ret[i] = strdup([arr[i] UTF8String]);
        }
        ret[[arr count]] = NULL;
        return ret;
    }
}

static void freeDeepMallocedNullTerminatedArrayOfCUTF8StringsWithArray(char **cArray)
{
    if (!cArray) {
        return;
    }
    for (NSUInteger i=0; cArray[i]; i++) {
        free(cArray[i]);
    }
    free(cArray);
}


@implementation BRUTask

#pragma mark - Helpers

+ (char **)buildEnvironmentWithDictionary:(NSDictionary *)envDict
{
    NSMutableArray *envArray = [NSMutableArray arrayWithCapacity:[envDict count]];
    for (NSString *key in [envDict keyEnumerator]) {
        [envArray addObject:[NSString stringWithFormat:@"%@=%@", key, envDict[key]] ?: @""];
    }
    return deepMallocedNullTerminatedArrayOfCUTF8StringsWithArray(envArray);
}

+ (NSFileHandle *)extractFileHandleWithObject:(id)obj
                                    writeMode:(BOOL)writeMode
                         shouldCloseParentEnd:(BOOL *)outShouldClose
{
    NSFileHandle *fileHandle = nil;
    BOOL shouldClose = NO;
    if (obj) {
        if ([obj isKindOfClass:[NSPipe class]]) {
            NSPipe *p = obj;
            if (writeMode) {
                fileHandle = p.fileHandleForWriting;
            } else {
                fileHandle = p.fileHandleForReading;
            }
            shouldClose = YES;
        } else if ([obj isKindOfClass:[NSFileHandle class]]) {
            fileHandle = obj;
            shouldClose = NO;
        } else {
            BRUAssert(NO, @"wrong type: %@, supported: NSPipe and NSFileHandle", [obj class]);
        }
    }
    if (outShouldClose) {
        *outShouldClose = shouldClose;
    }
    return fileHandle;
}

#pragma mark - Public API

- (id)init
{
    if ((self = [super init])) {
        self->_wasLaunched = NO;
        self->_hasBeenWaitedOn = NO;
        self->_waitOnSemaphore = dispatch_semaphore_create(0);
        self->_spawnAsSessionLeader = YES;
        self->_childTerminationHandlingQueue = bru_dispatch_queue_create("com.bromium.BRUTask.ProcessSignalsQueue",
                                                                         DISPATCH_QUEUE_SERIAL);
        self->_childExitedSrc = NULL;
    }
    return self;
}

- (void)dealloc
{
    if (self->_childExitedSrc) {
        dispatch_source_cancel(self->_childExitedSrc);
    }
}

- (NSString *)description
{
    NSString *state;
    if (self.isRunning) {
        state = [NSString stringWithFormat:@"state={running=YES, pid=%d}", self.processIdentifier];
    } else {
        if (self.wasLaunched) {
            state = [NSString stringWithFormat:@"state={running=NO, exit-reason:%@, exit-status:%d, dead-pid:%d}",
                     self.terminationReason == NSTaskTerminationReasonUncaughtSignal ? @"signal" : @"exit",
                     self.terminationStatus, self.processIdentifier];
        } else {
            state = @"state={running=NO, was-started=NO}";
        }
    }
    return [NSString stringWithFormat:@"BRUTask {launchPath='%@', arguments='%@', %@}",
            self.launchPath, self.arguments, state];
}

- (BOOL)launchWithError:(NSError **)outError
{
    NSMutableArray *argvNS = [NSMutableArray arrayWithCapacity:1+[self.arguments count]];
    char **argv = NULL;
    char **envp = NULL;
    const char *pwd = [self.currentDirectoryPath UTF8String];
    __block BOOL success = NO;
    __block int error_errno = 0;
    __block char *error_desc = NULL;

    AssertStateInternal(!self.wasLaunched, @"BRUTask has already been launched");
    self.wasLaunched = YES;

    [argvNS addObject:self.launchPath];
    for (NSString *arg in self.arguments) {
        [argvNS addObject:arg];
    }
    argv = deepMallocedNullTerminatedArrayOfCUTF8StringsWithArray(argvNS);
    if (self.environment) {
        envp = [BRUTask buildEnvironmentWithDictionary:self.environment];
    }

    dispatch_block_t doFork = ^{
        BOOL beSessionLeader = self.spawnAsSessionLeader;
        BOOL shouldClose_stdin = NO;
        BOOL shouldClose_stdout = NO;
        BOOL shouldClose_stderr = NO;
        NSFileHandle *fh_stdin = nil;
        NSFileHandle *fh_stdout = nil;
        NSFileHandle *fh_stderr = nil;
        int fd_stdin = -1;
        int fd_stdout = -1;
        int fd_stderr = -1;
        int child2parent[2];
        int parent2child[2];
        int err_pipe = pipe(child2parent);
        if (err_pipe) {
            success = NO;
            error_errno = errno;
            error_desc = "child2parent: pipe() failed";
            return;
        }
        err_pipe = pipe(parent2child);
        if (err_pipe) {
            success = NO;
            error_errno = errno;
            error_desc = "parent2child: pipe() failed";

            close(child2parent[0]);
            close(child2parent[1]);
            return;
        }

        fh_stdin = [BRUTask extractFileHandleWithObject:self.standardInput
                                              writeMode:NO
                                   shouldCloseParentEnd:&shouldClose_stdin];
        fh_stdout = [BRUTask extractFileHandleWithObject:self.standardOutput
                                               writeMode:YES
                                    shouldCloseParentEnd:&shouldClose_stdout];
        fh_stderr = [BRUTask extractFileHandleWithObject:self.standardError
                                               writeMode:YES
                                    shouldCloseParentEnd:&shouldClose_stderr];
        /* DO NOT close(2) fd_* IN THE PARENT! */
        fd_stdin = fh_stdin ? [fh_stdin fileDescriptor] : -1;
        fd_stdout = fh_stdout ? [fh_stdout fileDescriptor] : -1;
        fd_stderr = fh_stderr ? [fh_stderr fileDescriptor] : -1;

        pid_t pid = fork();
        if (pid > 0) {
            /* parent */

            self.processIdentifier = pid;

            ssize_t n;
            int err_exec = 0;
            close(parent2child[0]);
            close(child2parent[1]);
            self.childExitedSrc = dispatch_source_create(DISPATCH_SOURCE_TYPE_PROC,
                                                         (uintptr_t)pid /* yes, that's correct */,
                                                         DISPATCH_PROC_EXIT,
                                                         self.childTerminationHandlingQueue);
            ssize_t suc_write = write(parent2child[1], "\0", 1); /* signal child that it can execv now */
            BOOL start_failure = NO;
            int errno_save = errno;
            close(parent2child[1]);
            errno = errno_save;
            if (suc_write < 0) {
                success = NO;
                error_errno = errno;
                error_desc = "parent2child write() failed";
                start_failure = YES;
            } else if (0 == suc_write) {
                success = NO;
                error_errno = EINVAL;
                error_desc = "EOF on parent2child write()";
                start_failure = YES;
            }
            while (!start_failure) {
                n = read(child2parent[0], &err_exec, sizeof(int));
                if (0 == n) {
                    self.running = YES;
                    success = YES;
                    break;
                } else if (n < 0) {
                    if (EINTR == errno || EAGAIN == errno) {
                        continue;
                    } else {
                        success = NO;
                        error_errno = errno;
                        error_desc = "internal error, please report (read failed)";
                        break;
                    }
                } else {
                    success = NO;
                    if (sizeof(int) == n) {
                        error_errno = err_exec;
                        error_desc = "exec failed";
                    } else {
                        error_errno = EDOM;
                        error_desc = "exec failed, couldn't figure why";
                    }
                    break;
                }
            }
            close(child2parent[0]);
            if (success) {
                /* NSTask only closes these file descriptors if the launch doesn't fail, so do we... */
                if (shouldClose_stdin && fd_stdin > STDERR_FILENO) {
                    [fh_stdin closeFile];
                }
                if (shouldClose_stdout && fd_stdout > STDERR_FILENO) {
                    [fh_stdout closeFile];
                }
                if (shouldClose_stderr && fd_stderr > STDERR_FILENO) {
                    [fh_stderr closeFile];
                }
            }
        } else if (0 == pid) {
            /* child */
            /* NO OBJECTIVE-C CODE HERE! ONLY PLAIN C */
            char buf[1];
            int err = 0;

            err = close(child2parent[0]);
            assert(0 == err);
            close(parent2child[1]);
            err = fcntl(child2parent[1], F_SETFD, FD_CLOEXEC); /* This fd will be closed on exec */
            if (err != 0) {
                /* That's very bad because if setting this fails, the parent might wait indefinitely, best effort now */
                ssize_t suc_write = write(child2parent[1], &errno, sizeof(int));
                assert(suc_write >= 0);
                close(child2parent[1]);
                abort();
            }
            if (pwd) {
                chdir(pwd);
            }
            read(parent2child[0], buf, 1); /* wait until parent has set-up dispatch_source */
            close(parent2child[0]);

            if (fd_stdin >= 0) {
                dup2(fd_stdin, STDIN_FILENO);
            }
            if (fd_stdout >= 0) {
                dup2(fd_stdout, STDOUT_FILENO);
            }
            if (fd_stderr >= 0) {
                dup2(fd_stderr, STDERR_FILENO);
            }

            if (fd_stdin > STDERR_FILENO) {
                close(fd_stdin);
            }
            if (fd_stdout > STDERR_FILENO) {
                close(fd_stdout);
            }
            if (fd_stderr > STDERR_FILENO) {
                close(fd_stderr);
            }

            for (int i=STDERR_FILENO+1; i<=getdtablesize(); i++) {
                if (i != child2parent[1]) {
                    close(i);
                }
            }
            if (beSessionLeader) {
                setsid();
            }

            for (int i=1; i<NSIG; i++) {
                signal(i, SIG_DFL);
            }
            sigset_t sig_set_all = 0;
            sigfillset(&sig_set_all);
            sigprocmask(SIG_UNBLOCK, &sig_set_all, NULL);

            execve(argv[0], argv, envp);
            /* execXX returned: error */
            ssize_t suc_write = write(child2parent[1], &errno, sizeof(int));
            assert(sizeof(int) == suc_write); /* if this write fails that's pretty bad. */
            close(child2parent[1]);
            _exit(EINVAL);
        } else {
            success = NO;
            error_errno = errno;
            error_desc = "fork() failed";
        }
    };

    doFork(); /* We don't do this on main thread anymore */

    if (argv) {
        freeDeepMallocedNullTerminatedArrayOfCUTF8StringsWithArray(argv);
    }
    if (envp) {
        freeDeepMallocedNullTerminatedArrayOfCUTF8StringsWithArray(envp);
    }

    if (success) {
        BRUAssertAlwaysFatal(self.childExitedSrc, @"child exited dispatch_source nil");
        if (!self.childExitedSrc) { BRU_ASSERT_NOT_REACHED(@"the impossible happned"); } /* make analyser happy */
        dispatch_source_set_event_handler(self.childExitedSrc, ^{
            /* this block deliberately captures self and creates a temporary reference cycle until the task dies */
            int err_wp;
            int wp_status = 0;

            while (true) {
                err_wp = waitpid(self.processIdentifier, &wp_status, WNOHANG);
                if (err_wp < 0 && EINTR == errno) {
                    continue;
                }

                if (err_wp < 0) {
                    BRUAssertDebugLog(err_wp >= 0, @"waitpid(%d, ...) returned %d (errno=%d, %s)",
                                      self.processIdentifier, err_wp, errno, strerror(errno));
                    return;
                } else if (0 == err_wp) {
                    /* that's a race: dispatch_source already fired but waitpid() hasn't the status ready yet */
                    [NSThread sleepForTimeInterval:0.01];
                    continue;
                } else {
                    break;
                }
            }

            /* process exited */
            /* the next line makes sure to break the reference cycle. Most likely it's not needed because cancel hopefully
             does its job and removes the event handler. However, the documentation doesn't guarantee it, so we make
             it sure. */
            dispatch_source_set_event_handler(self.childExitedSrc, ^{});
            dispatch_source_cancel(self.childExitedSrc);
            BRUAssertAlwaysFatal(self.running && self.wasLaunched, @"received SIGCHLD without a running task");

            if (WIFSIGNALED(wp_status)) {
                self.terminationReason = NSTaskTerminationReasonUncaughtSignal;
                self.terminationStatus = WTERMSIG(wp_status);
            } else if (WIFEXITED(wp_status)) {
                self.terminationReason = NSTaskTerminationReasonExit;
                self.terminationStatus = WEXITSTATUS(wp_status);
            } else {
                BRUAssert(NO, @"waitpid() returned with pid that has neither exited, nor signalled: 0x%x", wp_status);
            }

            self.running = NO;

            dispatch_semaphore_signal(self.waitOnSemaphore);

            void (^terminationHandler)(BRUTask *) = self.terminationHandler;
            if (terminationHandler) {
                terminationHandler(self);
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                /* This is on main thread for greater NSTask compatibility */
                [[NSNotificationCenter defaultCenter] postNotificationName:NSTaskDidTerminateNotification
                                                                    object:self
                                                                  userInfo:@{}];
            });
        });

        dispatch_resume(self.childExitedSrc);
    } else {
        if (self.childExitedSrc) {
            dispatch_source_set_event_handler(self.childExitedSrc, ^{});
            dispatch_resume(self.childExitedSrc);
        }
        BRU_ASSIGN_OUT_PTR(outError,
                           [NSError errorWithDomain:NSPOSIXErrorDomain
                                               code:error_errno
                                           userInfo:@{@"reason":[NSString stringWithCString:error_desc
                                                                                   encoding:NSUTF8StringEncoding],
                                                      @"launch-path":BRUNonnull(self.launchPath, @"<NULL>"),
                                                      @"args":BRUNonnull(self.arguments, @"<NULL>")}]);
    }
    return success;
}

- (void)interrupt
{
    AssertStateInternal(self.wasLaunched, @"task wasn't launched yet");
    if (self.running) {
        kill(self.processIdentifier, SIGINT);
    }
}

- (void)terminate
{
    AssertStateInternal(self.wasLaunched, @"task wasn't launched yet");
    if (self.running) {
        kill(self.processIdentifier, SIGTERM);
    }
}

- (BOOL)suspend
{
    int error = 1;
    AssertStateInternal(self.wasLaunched, @"task wasn't launched yet");
    if (self.running) {
        error = kill(self.processIdentifier, SIGSTOP);
    }
    return !error;
}

- (BOOL)resume
{
    int error = 1;
    AssertStateInternal(self.wasLaunched, @"task wasn't launched yet");
    if (self.running) {
        error = kill(self.processIdentifier, SIGCONT);
    }
    return !error;
}

+ (BRUTask *)launchedTaskWithLaunchPath:(NSString *)path arguments:(NSArray *)arguments
{
    BRUTask *t = [[BRUTask alloc] init];
    t.launchPath = path;
    t.arguments = arguments;
    BOOL suc_launch = [t launchWithError:nil];
    if (suc_launch) {
        return t;
    } else {
        return nil;
    }
}

- (void)waitUntilExit
{
    AssertStateInternal(self.wasLaunched, @"task wasn't launched yet");
    AssertStateInternal(!self.hasBeenWaitedOn, @"already waited for task");
    self.hasBeenWaitedOn = YES;

    if (![self isRunning]) {
        return;
    } else {
        NSRunLoop *rl = [NSRunLoop currentRunLoop];
        if (rl) {
            while (true) {
                long timeout = dispatch_semaphore_wait(self.waitOnSemaphore, DISPATCH_TIME_NOW);
                if (timeout) {
                    [rl runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeInterval:1
                                                                                   sinceDate:[NSDate date]]];
                } else {
                    break;
                }
            }
        } else {
            dispatch_semaphore_wait(self.waitOnSemaphore, DISPATCH_TIME_FOREVER);
        }
    }
}

@end
