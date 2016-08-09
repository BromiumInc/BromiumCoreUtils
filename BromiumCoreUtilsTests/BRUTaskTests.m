//
//  Copyright (C) 2013-2016, Bromium Inc.
//
//  This software may be modified and distributed under the terms
//  of the BSD license.  See the LICENSE file for details.
//
//  Created by Johannes Weiß on 31/05/2016.
//

#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#import <XCTest/XCTest.h>

#import <BRUSetDiffFormatter.h>
#import <BRUTemporaryFiles.h>
#import <BRUConcurrentBox.h>
#import <BRUTask.h>

static void __attribute__((noinline)) noop() {} /* for signal handling */

@interface BRUTaskTests : XCTestCase

@end

@implementation BRUTaskTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}


- (void)testBRUTaskSmoke
{
    NSError *error = nil;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    for (int i=0; i < 100; i++) {
        NSPipe *p = [NSPipe pipe];
        BRUTask *t = [[BRUTask alloc] init];
        __weak id tWeak = t;
        t.launchPath = @"/usr/bin/stat";
        t.arguments = @[@"-f", @"%p %z %u %g %i {%N}", @"/"];
        t.standardOutput = p;
        t.terminationHandler = ^(id tBlock) {
            dispatch_semaphore_signal(sem);
            XCTAssertEqual(tWeak, tBlock, @"task got mixed up");
            XCTAssertEqual(0, ((NSTask *)tBlock).terminationStatus, @"didn't exit 0");
            XCTAssertEqual(NSTaskTerminationReasonExit, ((NSTask *)tBlock).terminationReason, @"wrong termination reason");
        };
        BOOL suc = [t launchWithError:&error];
        XCTAssertEqual(YES, suc, @"launch not successful");
        XCTAssertNil(error, @"error not nil");
        dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
        NSData *data = [p.fileHandleForReading readDataToEndOfFile];
        [p.fileHandleForReading closeFile];
        XCTAssertTrue([data length] > 10, @"wrong output");
    }
}

- (void)testBRUTaskSmokeManyChildProcessesAndTerminationBlockRunsWhenTaskUnreachable
{
    const int num = 200;
    dispatch_semaphore_t sems[num];
    for (int i=0; i < num; i++) {
        __attribute__((objc_precise_lifetime)) BRUTask *t = [[BRUTask alloc] init];
        sems[i] = dispatch_semaphore_create(0);
        dispatch_semaphore_t sem = sems[i];

        t.launchPath = @"/bin/sleep";
        t.arguments = @[@"1"];
        t.terminationHandler = ^(BRUTask *t) {
            dispatch_semaphore_signal(sem);
            XCTAssertEqual(0, t.terminationStatus, @"didn't exit 0");
        };
        BOOL suc_lauch = [t launchWithError:nil];
        XCTAssert(suc_lauch, @"launch failed");
    }
    for (int i=0; i < num; i++) {
        dispatch_semaphore_wait(sems[i], DISPATCH_TIME_FOREVER);
    }
}

- (void)testBRUTaskOtherThread
{
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    for (int i=0; i < 100; i++) {
        NSPipe *p = [NSPipe pipe];
        BRUTask *t = [[BRUTask alloc] init];
        __weak id tWeak = t;
        t.launchPath = @"/usr/bin/stat";
        t.arguments = @[@"-f", @"%p %z %u %g %i {%N}", @"/"];
        t.standardOutput = p;
        t.terminationHandler = ^(id tBlock) {
            dispatch_semaphore_signal(sem);
            XCTAssertEqual(tWeak, tBlock, @"task got mixed up");
            XCTAssertEqual(0, ((NSTask *)tBlock).terminationStatus, @"didn't exit 0");
            XCTAssertEqual(NSTaskTerminationReasonExit, ((NSTask *)tBlock).terminationReason, @"wrong termination reason");
        };
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSError *error = nil;
            BOOL suc = [t launchWithError:&error];
            XCTAssertEqual(YES, suc, @"launch not successful");
            XCTAssertNil(error, @"error not nil");
        });
        dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
        NSData *data = [p.fileHandleForReading readDataToEndOfFile];
        [p.fileHandleForReading closeFile];
        XCTAssertTrue([data length] > 10, @"wrong output");
    }
}

- (void)testBRUTaskDoesntLeakFDs
{
    NSError *error = nil;
    NSString *file = nil;
    NSFileHandle *fh = [BRUTemporaryFiles openTemporaryFileInDirectory:nil outFilename:&file error:&error];
    XCTAssertNotNil(fh, @"file handle nil");
    XCTAssertNil(error, @"error not nil");
    BRUTask *t = [[BRUTask alloc] init];
    t.launchPath = @"/bin/zsh";
    t.arguments = @[@"-c", @"/usr/sbin/lsof -a -d ^cwd,^txt -p $$"];
    t.standardOutput = fh;
    BOOL suc = [t launchWithError:&error];
    XCTAssertTrue(suc, @"launch failed");
    XCTAssertNil(error, @"error not nil");
    [t waitUntilExit];
    [fh closeFile];
    NSString *s = [NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:&error];
    XCTAssertNotNil(s, @"file contents nil");
    XCTAssertNil(error, @"error not nil");
    NSArray *lines = [s componentsSeparatedByString:@"\n"];
    XCTAssertEqual((NSUInteger)7, [lines count], @"wrong number of FDs: %@", s);
    [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
}

- (void)testBRUTaskEnvironment
{
    NSError *error = nil;
    NSPipe *p = [NSPipe pipe];
    BRUTask *t = [[BRUTask alloc] init];
    t.launchPath = @"/bin/zsh";
    t.arguments = @[@"-c", @"echo $SOME_VAR; echo $SOME_OTHER_VAR"];
    t.environment = @{@"SOME_VAR":@"foo"};
    t.standardOutput = p;
    BOOL suc_launch = [t launchWithError:&error];
    XCTAssertTrue(suc_launch, @"launch failed");
    XCTAssertNil(error, @"error not nil");
    NSData *actual = [p.fileHandleForReading readDataToEndOfFile];
    [p.fileHandleForReading closeFile];
    NSData *expected = [@"foo\n\n" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(expected, actual, @"wrong output");
}

- (void)testBRUTaskWeirdEnvironment
{
    NSString *withSpecialChars = @" ! \\\n   !ö  = & ! ; \\ Héllö Wörld!";
    NSError *error = nil;
    NSPipe *p = [NSPipe pipe];
    BRUTask *t = [[BRUTask alloc] init];
    t.launchPath = @"/bin/zsh";
    t.arguments = @[@"-c", @"echo $WITH_SPACES; echo $WITH_SPECIAL_CHARS"];
    t.environment = @{@"WITH_SPACES":@"foo bar", @"WITH_SPECIAL_CHARS":withSpecialChars};
    t.standardOutput = p;
    BOOL suc_launch = [t launchWithError:&error];
    XCTAssertTrue(suc_launch, @"launch failed");
    XCTAssertNil(error, @"error not nil");
    NSData *actual = [p.fileHandleForReading readDataToEndOfFile];
    [p.fileHandleForReading closeFile];
    NSData *expected = [[NSString stringWithFormat:@"foo bar\n%@\n", withSpecialChars]
                        dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(expected, actual, @"wrong output");
}

- (void)testBRUTaskPWD
{
    NSError *error = nil;
    NSPipe *p = [NSPipe pipe];
    BRUTask *t = [[BRUTask alloc] init];
    t.launchPath = @"/bin/zsh";
    t.arguments = @[@"-c", @"pwd"];
    t.currentDirectoryPath = @"/System/Library";
    t.standardOutput = p;
    BOOL suc_launch = [t launchWithError:&error];
    XCTAssertTrue(suc_launch, @"launch failed");
    XCTAssertNil(error, @"error not nil");
    NSData *actual = [p.fileHandleForReading readDataToEndOfFile];
    [p.fileHandleForReading closeFile];
    NSData *expected = [@"/System/Library\n" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(expected, actual, @"wrong pwd");
}

- (void)testBRUTaskStdoutStderr
{
    NSError *error = nil;
    NSPipe *pStdout = [NSPipe pipe];
    NSPipe *pStderr = [NSPipe pipe];
    BRUTask *t = [[BRUTask alloc] init];
    t.launchPath = @"/bin/zsh";
    t.arguments = @[@"-c", @"echo stdout; echo >&2 stderr"];
    t.standardOutput = pStdout;
    t.standardError = pStderr;
    BOOL suc_launch = [t launchWithError:&error];
    XCTAssertTrue(suc_launch, @"launch failed");
    XCTAssertNil(error, @"error not nil");
    NSData *actualStdout = [pStdout.fileHandleForReading readDataToEndOfFile];
    [pStdout.fileHandleForReading closeFile];
    NSData *expectedStdout = [@"stdout\n" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(expectedStdout, actualStdout, @"wrong stdout");
    NSData *actualStderr = [pStderr.fileHandleForReading readDataToEndOfFile];
    [pStderr.fileHandleForReading closeFile];
    NSData *expectedStderr = [@"stderr\n" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(expectedStderr, actualStderr, @"wrong stderr");
}

- (void)testBRUTaskWaitForTerm
{
    NSError *error = nil;
    BRUTask *t = [[BRUTask alloc] init];
    t.launchPath = @"/bin/zsh";
    t.arguments = @[@"-c", @"sleep 3"];
    NSDate *start = [NSDate date];
    BOOL suc_launch = [t launchWithError:&error];
    NSDate *launchFinished = [NSDate date];
    XCTAssertTrue(suc_launch, @"launch failed");
    XCTAssertNil(error, @"error not nil");
    XCTAssertTrue(t.running, @"task not running???");
    XCTAssertTrue([launchFinished timeIntervalSinceDate:start] < 1, @"launch took too long");
    [t waitUntilExit];
    NSDate *end = [NSDate date];
    XCTAssertFalse(t.running, @"still running after exit");
    XCTAssertTrue([end timeIntervalSinceDate:start] > 3, @"ran too fast, impossible");
    XCTAssertEqual(0, t.terminationStatus, @"wrong exit code");
    XCTAssertEqual(NSTaskTerminationReasonExit, t.terminationReason, @"wrong termination reason");
}

- (void)testBRUTaskTestPid
{
    NSError *error = nil;
    NSPipe *p = [NSPipe pipe];
    BRUTask *t = [[BRUTask alloc] init];
    t.launchPath = @"/bin/zsh";
    t.arguments = @[@"-c", @"echo $$"];
    t.standardOutput = p;
    BOOL suc_launch = [t launchWithError:&error];
    XCTAssertTrue(suc_launch, @"launch failed");
    XCTAssertNil(error, @"error not nil");
    NSData *actual = [p.fileHandleForReading readDataToEndOfFile];
    [p.fileHandleForReading closeFile];
    NSData *expected = [[NSString stringWithFormat:@"%d\n", t.processIdentifier]
                        dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(expected, actual, @"wrong output");
}

- (void)testBRUTaskTerminationHandler
{
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    NSError *error = nil;
    NSPipe *p = [NSPipe pipe];
    BRUTask *t = [[BRUTask alloc] init];
    t.launchPath = @"/bin/zsh";
    t.arguments = @[@"-c", @"echo foo bar; exit 42"];
    t.standardOutput = p;
    t.terminationHandler = ^(BRUTask *t) {
        dispatch_semaphore_signal(sem);
        XCTAssertFalse(t.running, @"task running in termination handler");
        XCTAssertTrue(t.terminationReason == NSTaskTerminationReasonExit, @"wrong termination reason");
        XCTAssertTrue(t.terminationStatus == 42, @"wrong exit code");
    };
    BOOL suc_launch = [t launchWithError:&error];
    XCTAssertTrue(suc_launch, @"launch failed");
    XCTAssertNil(error, @"error not nil");
    NSData *actual = [p.fileHandleForReading readDataToEndOfFile];
    [p.fileHandleForReading closeFile];
    NSData *expected = [@"foo bar\n" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(expected, actual, @"wrong output");
    long err = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)));
    XCTAssertTrue(0 == err, @"termination handler wasn't called");
}

- (void)testBRUTaskTerminationHandlerAndSignalExit
{
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    NSError *error = nil;
    NSPipe *p = [NSPipe pipe];
    BRUTask *t = [[BRUTask alloc] init];
    t.launchPath = @"/bin/zsh";
    t.arguments = @[@"-c", @"echo foo bar; kill -TERM $$; sleep 10000"];
    t.standardOutput = p;
    t.terminationHandler = ^(BRUTask *t) {
        dispatch_semaphore_signal(sem);
        XCTAssertFalse(t.running, @"task running in termination handler");
        XCTAssertTrue(t.terminationReason == NSTaskTerminationReasonUncaughtSignal, @"wrong termination reason");
        XCTAssertTrue(t.terminationStatus == SIGTERM, @"wrong exit code");
    };
    BOOL suc_launch = [t launchWithError:&error];
    XCTAssertTrue(suc_launch, @"launch failed");
    XCTAssertNil(error, @"error not nil");
    NSData *actual = [p.fileHandleForReading readDataToEndOfFile];
    [p.fileHandleForReading closeFile];
    NSData *expected = [@"foo bar\n" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(expected, actual, @"wrong output");
    [t waitUntilExit];
    XCTAssertFalse(t.running, @"task running in termination handler");
    XCTAssertTrue(t.terminationReason == NSTaskTerminationReasonUncaughtSignal, @"wrong termination reason");
    XCTAssertTrue(t.terminationStatus == SIGTERM, @"wrong exit code");
    long err = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)));
    XCTAssertTrue(0 == err, @"termination handler wasn't called");
}

- (void)testBRUTaskConvenienceLaunch
{
    NSString *tmpDir = [BRUTemporaryFiles createTemporaryDirectoryError:nil];
    NSString *tmpFile = [tmpDir stringByAppendingPathComponent:@"foo bar"];
    XCTAssertNotNil(tmpFile, @"couldn't create tmp file");
    BRUTask *t = [BRUTask launchedTaskWithLaunchPath:@"/bin/zsh"
                                           arguments:@[@"-c", [NSString stringWithFormat:@"sleep 2; touch '%@'",
                                                               tmpFile]]];
    XCTAssertTrue(t.running, @"task not running");
    [t waitUntilExit];
    XCTAssertFalse(t.running, @"task not running after exit");
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:tmpFile], @"tmp file not created, cmd not ran?");
    BOOL suc_rmrf = [[NSFileManager defaultManager] removeItemAtPath:tmpDir error:nil];
    XCTAssertTrue(suc_rmrf, @"deleting tmp dir failed");
}

- (void)testBRUTaskStdoutAndStderrToNSFileHandle
{
    NSString *filename = nil;
    NSFileHandle *fh = [BRUTemporaryFiles openTemporaryFileWithBasenameTemplate:@"screw-you-XXXXXX"
                                                                    inDirectory:nil
                                                                    outFilename:&filename
                                                                          error:nil];
    XCTAssertNotNil(fh, @"couldn't create temp file handle");
    XCTAssertNotNil(filename, @"couldn't get temp file name");
#ifdef BRTEST_USE_NSTASK
    NSTask *t = [[NSTask alloc] init];
#else
    NSError *error = nil;
    BRUTask *t = [[BRUTask alloc] init];
#endif
    t.standardOutput = fh;
    t.standardError = fh;
    t.launchPath = @"/bin/zsh";
    t.arguments = @[ @"-c", @"echo >&2 STDERR; sleep 1; echo STDOUT" ];
#ifdef BRTEST_USE_NSTASK
    @try { [t launch]; } @catch (__unused NSException *e) {}
#else
    BOOL lSuc = [t launchWithError:&error];
    XCTAssertTrue(lSuc, @"launch not successful");
    XCTAssertNil(error, @"error object not nil");
#endif
    [fh closeFile];
    [t waitUntilExit];
    NSString *expected = @"STDERR\nSTDOUT\n";
    NSString *actual = [[NSString alloc] initWithContentsOfFile:filename encoding:NSUTF8StringEncoding error:nil];
    XCTAssertEqualObjects(expected, actual, @"file contents differ");
}

- (void)testBRUTaskStdoutAndWriteAgainSelf
{
    NSError *error = nil;
    NSString *filename = nil;
    NSFileHandle *fh = [BRUTemporaryFiles openTemporaryFileWithBasenameTemplate:@"screw-you-XXXXXX"
                                                                    inDirectory:nil
                                                                    outFilename:&filename
                                                                          error:nil];
    XCTAssertNotNil(fh, @"couldn't create temp file handle");
    XCTAssertNotNil(filename, @"couldn't get temp file name");
    BRUTask *t = [[BRUTask alloc] init];
    t.standardOutput = fh;
    t.launchPath = @"/bin/zsh";
    t.arguments = @[ @"-c", @"echo STDOUT" ];
    BOOL lSuc = [t launchWithError:&error];
    XCTAssertTrue(lSuc, @"launch not successful");
    XCTAssertNil(error, @"error object not nil");
    [t waitUntilExit];
    [fh writeData:[@"SELF WRITE\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [fh closeFile];
    NSString *expected = @"STDOUT\nSELF WRITE\n";
    NSString *actual = [[NSString alloc] initWithContentsOfFile:filename encoding:NSUTF8StringEncoding error:nil];
    XCTAssertEqualObjects(expected, actual, @"file contents differ");
}

- (void)testBRUTaskIgnoredSignalsWork
{
    signal(SIGUSR1, SIG_IGN);
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    NSError *error = nil;
    BRUTask *t = [[BRUTask alloc] init];
    t.launchPath = @"/bin/zsh";
    t.arguments = @[ @"-c", @"kill -USR1 $$; echo THIS SHOULD NEVER BE REACHED; while true; do sleep 100; done" ];
    BOOL suc = [t launchWithError:&error];
    XCTAssertTrue(suc, @"couldn't launch");
    XCTAssertNil(error, @"error not nil: %@", error);
    t.terminationHandler = ^(BRUTask *t) {
        dispatch_semaphore_signal(sem);
    };
    long timeout = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)));
    XCTAssertEqual((long)0, timeout, @"timed out");
    XCTAssertEqual(NSTaskTerminationReasonUncaughtSignal, t.terminationReason, @"wrong exit reason");
    XCTAssertEqual(SIGUSR1, t.terminationStatus, @"wrong signal");
    signal(SIGUSR1, SIG_DFL);
}

- (void)testBRUTaskBlockedSignalsWork
{
    sigset_t sig_set = 0;
    sigemptyset(&sig_set);
    sigaddset(&sig_set, SIGUSR1);
    sigprocmask(SIG_UNBLOCK, &sig_set, NULL);

    signal(SIGUSR1, SIG_IGN);
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    NSError *error = nil;
    BRUTask *t = [[BRUTask alloc] init];
    t.launchPath = @"/bin/zsh";
    t.arguments = @[ @"-c", @"kill -USR1 $$; echo THIS SHOULD NEVER BE REACHED; while true; do sleep 100; done" ];
    BOOL suc = [t launchWithError:&error];
    XCTAssertTrue(suc, @"couldn't launch");
    XCTAssertNil(error, @"error not nil: %@", error);
    t.terminationHandler = ^(BRUTask *t) {
        dispatch_semaphore_signal(sem);
    };
    long timeout = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)));
    XCTAssertEqual((long)0, timeout, @"timed out");
    XCTAssertEqual(NSTaskTerminationReasonUncaughtSignal, t.terminationReason, @"wrong exit reason");
    XCTAssertEqual(SIGUSR1, t.terminationStatus, @"wrong signal");
    sigfillset(&sig_set);
    sigprocmask(SIG_UNBLOCK, &sig_set, NULL);
}

- (void)testBRUTaskHandledSignalsWork
{
    signal(SIGUSR1, noop);
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    NSError *error = nil;
    BRUTask *t = [[BRUTask alloc] init];
    t.launchPath = @"/bin/zsh";
    t.arguments = @[ @"-c", @"kill -USR1 $$; echo THIS SHOULD NEVER BE REACHED; while true; do sleep 100; done" ];
    BOOL suc = [t launchWithError:&error];
    XCTAssertTrue(suc, @"couldn't launch");
    XCTAssertNil(error, @"error not nil: %@", error);
    t.terminationHandler = ^(BRUTask *t) {
        dispatch_semaphore_signal(sem);
    };
    long timeout = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)));
    XCTAssertEqual((long)0, timeout, @"timed out");
    XCTAssertEqual(NSTaskTerminationReasonUncaughtSignal, t.terminationReason, @"wrong exit reason");
    XCTAssertEqual(SIGUSR1, t.terminationStatus, @"wrong signal");
    signal(SIGUSR1, SIG_DFL);
}

- (void)testBRUTaskDoesCloseOtherPipeEnd
{
    BOOL gotExceptionStdin = NO;
    BOOL gotExceptionStdout = NO;
    BOOL gotExceptionStderr = NO;
    NSError *error = nil;
    NSPipe *pStdin = [NSPipe pipe];
    NSPipe *pStdout = [NSPipe pipe];
    NSPipe *pStderr = [NSPipe pipe];
    BRUTask *t = [[BRUTask alloc] init];
    t.launchPath = @"/bin/zsh";
    t.arguments = @[@"-c", @"read data; echo $data; echo >&2 $data"];
    t.standardInput = pStdin;
    t.standardOutput = pStdout;
    t.standardError = pStderr;
    BOOL suc_launch = [t launchWithError:&error];
    XCTAssertTrue(suc_launch, @"launch failed");
    XCTAssertNil(error, @"error not nil");
    [pStdin.fileHandleForWriting writeData:[@"HIYA\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [[pStdin fileHandleForWriting] closeFile];
    NSData *actualStdout = [pStdout.fileHandleForReading readDataToEndOfFile];
    [[pStdout fileHandleForReading] closeFile];
    NSData *actualStderr = [pStderr.fileHandleForReading readDataToEndOfFile];
    [[pStderr fileHandleForReading] closeFile];
    NSData *expected = [@"HIYA\n" dataUsingEncoding:NSUTF8StringEncoding];
    [t waitUntilExit];
    @try {
        [pStdin.fileHandleForReading readDataToEndOfFile];
    }
    @catch (NSException *ex) {
        XCTAssertEqualObjects(@"NSFileHandleOperationException", ex.name, @"wrong exception");
        gotExceptionStdin = YES;
    }
    @finally {
        XCTAssertTrue(gotExceptionStdin, @"stdin: didn't get exception, file handle still open");
    }
    @try {
        [pStdout.fileHandleForWriting writeData:[@"XXX" dataUsingEncoding:NSUTF8StringEncoding]];
    }
    @catch (NSException *ex) {
        XCTAssertEqualObjects(@"NSFileHandleOperationException", ex.name, @"wrong exception");
        gotExceptionStdout = YES;
    }
    @finally {
        XCTAssertTrue(gotExceptionStdout, @"stdout: didn't get exception, file handle still open");
    }
    @try {
        [pStderr.fileHandleForWriting writeData:[@"XXX" dataUsingEncoding:NSUTF8StringEncoding]];
    }
    @catch (NSException *ex) {
        XCTAssertEqualObjects(@"NSFileHandleOperationException", ex.name, @"wrong exception");
        gotExceptionStderr = YES;
    }
    @finally {
        XCTAssertTrue(gotExceptionStderr, @"stderr: didn't get exception, file handle still open");
    }

    XCTAssertEqualObjects(expected, actualStdout, @"wrong output");
    XCTAssertEqualObjects(expected, actualStderr, @"wrong output");
}

- (void)testBRUTaskDoesNotCloseNSFileHandles
{
    NSError *error = nil;
    NSPipe *pStdin = [NSPipe pipe];
    NSPipe *pStdout = [NSPipe pipe];
    NSPipe *pStderr = [NSPipe pipe];
    BRUTask *t = [[BRUTask alloc] init];
    t.launchPath = @"/bin/zsh";
    t.arguments = @[@"-c", @"read data; echo $data; echo >&2 $data"];
    t.standardInput = pStdin.fileHandleForReading;
    t.standardOutput = pStdout.fileHandleForWriting;
    t.standardError = pStderr.fileHandleForWriting;
    BOOL suc_launch = [t launchWithError:&error];
    XCTAssertTrue(suc_launch, @"launch failed");
    XCTAssertNil(error, @"error not nil");
    [pStdin.fileHandleForWriting writeData:[@"HIYA\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [pStdin.fileHandleForReading closeFile];
    [pStdout.fileHandleForWriting closeFile];
    [pStderr.fileHandleForWriting closeFile];
    NSData *actualStdout = [pStdout.fileHandleForReading readDataToEndOfFile];
    NSData *actualStderr = [pStderr.fileHandleForReading readDataToEndOfFile];
    NSData *expected = [@"HIYA\n" dataUsingEncoding:NSUTF8StringEncoding];
    [t waitUntilExit];

    XCTAssertEqualObjects(expected, actualStdout, @"wrong output");
    XCTAssertEqualObjects(expected, actualStderr, @"wrong output");
}

- (void)testBRUTaskWeirdExecutableName
{
    NSError *error = nil;
    NSString *tempDir = [BRUTemporaryFiles createTemporaryDirectoryWithBasenameTemplate:@"😩😈👲💥-XXXXXX"
                                                                            inDirectory:nil
                                                                                  error:&error];
    XCTAssertNotNil(tempDir, @"temp dir: no luck: %@", error);
    NSString *tempFile = [BRUTemporaryFiles createTemporaryFileWithBasenameTemplate:@"Do you like 👠 ?-XXXXXX"
                                                                        inDirectory:tempDir
                                                                              error:&error];
    XCTAssertNotNil(tempFile, @"temp file: no luck: %@", error);
    struct stat buf;
    int res = stat([tempFile fileSystemRepresentation], &buf);
    XCTAssertEqual(0, res, @"stat failed");
    mode_t mode = buf.st_mode;
    mode |= (S_IXUSR | S_IXGRP | S_IXOTH);
    res = chmod([tempFile fileSystemRepresentation], mode);
    XCTAssertEqual(0, res, @"chmod failed");

    BOOL suc = [@"#!/bin/zsh\nexit 23;\n" writeToFile:tempFile
                                           atomically:YES
                                             encoding:NSUTF8StringEncoding
                                                error:&error];
    XCTAssertTrue(suc, @"no luck writing: %@", error);
    BRUTask *t = [[BRUTask alloc] init];
    t.launchPath = tempFile;
    suc = [t launchWithError:&error];
    XCTAssertTrue(suc, @"no luck launching: %@", error);
    [t waitUntilExit];
    XCTAssertEqual(23, t.terminationStatus, @"wrong exit code");
    suc = [[NSFileManager defaultManager] removeItemAtPath:tempDir error:&error];
    XCTAssertTrue(suc, @"no luck removing dir: %@", error);
}

- (void)testBRUTaskFailureWhenLaunchPathIsDirectory
{
    NSError *error = nil;
    BRUTask *t = [[BRUTask alloc] init];
    t.launchPath = @"/";
    BOOL suc = [t launchWithError:&error];
    XCTAssertNotNil(error, @"executing a directory but error is still nil.");
    XCTAssertFalse(suc, @"successful executing a directory?");
    XCTAssertEqual([error domain], NSPOSIXErrorDomain, @"Error domain should be POSIX (no access).");
    XCTAssertEqual([error code], (NSInteger)EACCES, @"Error code should equal EACCES");
}

- (void)testBRUTaskFailureWhenLaunchPathIsNonExistant
{
    NSError *error = nil;
    BRUTask *t = [[BRUTask alloc] init];
    t.launchPath = @"/This/path/will/NOT/exist/on/your/system/I/hope/:-)";
    BOOL suc = [t launchWithError:&error];
    XCTAssertNotNil(error, @"file should not exist but error is still nil.");
    XCTAssertFalse(suc, @"successful executing a non-existant file?");
    XCTAssertEqual([error domain], NSPOSIXErrorDomain, @"Error domain should be POSIX (file not found).");
    XCTAssertEqual([error code], (NSInteger)ENOENT, @"Error code should equal ENOENT");
}

- (NSSet *)getAllOpenFileDescriptors
{
    NSMutableSet *openFDs = [NSMutableSet new];
    for (int i=0; i<=getdtablesize(); i++) {
        if (0 == fcntl(i, F_GETFD)) {
            [openFDs addObject:@(i)];
        }
    }
    return [openFDs copy];
}

- (void)testBRUTaskDoesntLeakFileDescriptors
{
    NSSet *preOpenFDs = [self getAllOpenFileDescriptors];
    NSSet *postOpenFDs;
    __attribute__((objc_precise_lifetime)) NSPipe *stdinPipe = [NSPipe pipe];
    __attribute__((objc_precise_lifetime)) NSPipe *stdoutPipe = [NSPipe pipe];
    NSString *pipeFDNumbers = [NSString stringWithFormat:@"in:{r=%d, w=%d}, out:{r=%d, w=%d}",
                               [[stdinPipe fileHandleForReading] fileDescriptor],
                               [[stdinPipe fileHandleForWriting] fileDescriptor],
                               [[stdoutPipe fileHandleForReading] fileDescriptor],
                               [[stdoutPipe fileHandleForWriting] fileDescriptor]];

    @autoreleasepool {
#ifdef BRTEST_USE_NSTASK
        NSTask *t = [[NSTask alloc] init];
#else
        NSError *error = nil;
        BRUTask *t = [[BRUTask alloc] init];
#endif
        t.arguments = @[@"-c", @"read line; echo Hello $line XX"];
        t.launchPath = @"/bin/zsh";
        t.standardInput = stdinPipe;
        t.standardOutput = stdoutPipe;

        [[stdinPipe fileHandleForWriting] writeData:[@"foo bar" dataUsingEncoding:NSUTF8StringEncoding]];
        [[stdinPipe fileHandleForWriting] closeFile];
#ifdef BRTEST_USE_NSTASK
        @try { [t launch]; } @catch (__unused NSException *e) {}
#else
        BOOL suc = [t launchWithError:&error];
        XCTAssertTrue(suc, @"launch failed");
        XCTAssertNil(error, @"error set");
#endif
        [t waitUntilExit];

        NSString *actual = [[NSString alloc] initWithData:[[stdoutPipe fileHandleForReading] readDataToEndOfFile]
                                                 encoding:NSUTF8StringEncoding];
        [[stdoutPipe fileHandleForReading] closeFile];
        XCTAssertEqualObjects(@"Hello foo bar XX\n", actual, @"wrong data");
    }

    postOpenFDs = [self getAllOpenFileDescriptors];
    XCTAssertEqualObjects(preOpenFDs, postOpenFDs,
                          @"We're leaking FDs: %@ (%@)! pre open FDs: %@, post open FDs %@",
                          [BRUSetDiffFormatter formatDiffWithSet:preOpenFDs
                                                          andSet:postOpenFDs
                                                         options:nil],
                          pipeFDNumbers,
                          preOpenFDs,
                          postOpenFDs);
}

- (void)testBRUTaskDoesntLeakFileDescriptorsWhenLaunchFails
{
    NSSet *preOpenFDs = [self getAllOpenFileDescriptors];
    NSSet *postOpenFDs;
    __attribute__((objc_precise_lifetime)) NSPipe *stdinPipe = [NSPipe pipe];
    __attribute__((objc_precise_lifetime)) NSPipe *stdoutPipe = [NSPipe pipe];
    NSString *pipeFDNumbers = [NSString stringWithFormat:@"in:{r=%d, w=%d}, out:{r=%d, w=%d}",
                               [[stdinPipe fileHandleForReading] fileDescriptor],
                               [[stdinPipe fileHandleForWriting] fileDescriptor],
                               [[stdoutPipe fileHandleForReading] fileDescriptor],
                               [[stdoutPipe fileHandleForWriting] fileDescriptor]];

    @autoreleasepool {
#ifdef BRTEST_USE_NSTASK
        NSTask *t = [[NSTask alloc] init];
#else
        NSError *error = nil;
        BRUTask *t = [[BRUTask alloc] init];
#endif
        t.arguments = @[@"-c", @"read line; echo Hello $line XX"];
        t.launchPath = @"/";
        t.standardInput = stdinPipe;
        t.standardOutput = stdoutPipe;

        [[stdinPipe fileHandleForWriting] writeData:[@"foo bar" dataUsingEncoding:NSUTF8StringEncoding]];
        [[stdinPipe fileHandleForWriting] closeFile];
#ifdef BRTEST_USE_NSTASK
        @try { [t launch]; } @catch (__unused NSException *e) {}
#else
        BOOL suc = [t launchWithError:&error];
        XCTAssertFalse(suc, @"success when launching directory");
        XCTAssertNotNil(error, @"error not set");
#endif
        [t waitUntilExit];
        [[stdoutPipe fileHandleForReading] closeFile];
        /* We have to close the normally automatically closed file descriptors here because there was a failure */
        [[stdinPipe fileHandleForReading] closeFile];
        [[stdoutPipe fileHandleForWriting] closeFile];
    }

    postOpenFDs = [self getAllOpenFileDescriptors];
    XCTAssertEqualObjects(preOpenFDs, postOpenFDs,
                          @"We're leaking FDs: %@ (%@)! pre open FDs: %@, post open FDs %@",
                          [BRUSetDiffFormatter formatDiffWithSet:preOpenFDs
                                                          andSet:postOpenFDs
                                                         options:nil],
                          pipeFDNumbers,
                          preOpenFDs,
                          postOpenFDs);
}

- (void)testBRUTaskMarksTaskAsExitedShortlyAfterSIGKILL
{
    BRUTask *t = [[BRUTask alloc] init];
    t.launchPath = @"/bin/zsh";
    t.arguments = @[@"-c", @"sleep 3600"];
    NSError *error = nil;
    BOOL suc = [t launchWithError:&error];
    XCTAssertTrue(suc, @"launch failed: %@", error);
    XCTAssertNil(error, @"error set to non-nil");
    XCTAssertTrue(t.running);
    XCTAssertTrue(t.processIdentifier > 0, @"pid <= 0: %d", t.processIdentifier);
    int err = kill(t.processIdentifier, SIGKILL);
    XCTAssertTrue(0 == err, @"kill returned error: %d (errno=%d)", err, errno);
    [NSThread sleepForTimeInterval:1];
    XCTAssertTrue(0 == err, @"sleep returned %u", err);

    XCTAssertFalse(t.running);
}

- (void)testBRUTaskRegisterTerminationHandlerLateWorks
{
    NSError *error = nil;
    NSString *tmpDir = [BRUTemporaryFiles createTemporaryDirectoryError:&error];
    XCTAssertNotNil(tmpDir, @"creating tmp dir failed: %@", error);
    XCTAssertNil(error, @"error not nil");
    NSString *markerFile = [tmpDir stringByAppendingPathComponent:@"marker-file"];

    BRUTask *t = [[BRUTask alloc] init];
    t.launchPath = @"/bin/zsh";
    t.arguments = @[@"-c", [NSString stringWithFormat:@"while [[ ! -f '%@' ]]; do sleep 0.1; done; exit 42",
                            markerFile]];
    BOOL suc = [t launchWithError:&error];
    XCTAssertTrue(suc, @"launch failed: %@", error);
    XCTAssertNil(error, @"error set to non-nil");
    XCTAssertTrue(t.running);
    XCTAssertTrue(t.processIdentifier > 0, @"pid <= 0: %d", t.processIdentifier);
    [NSThread sleepForTimeInterval:0.1];

    BRUConcurrentBox<BRUEitherErrorOrSuccess<BRUTask *> *> *box = [BRUConcurrentBox emptyBox];
    t.terminationHandler = ^(BRUTask *bt) {
        [box put:[BRUEitherErrorOrSuccess newWithSuccessObject:bt]];
    };

    XCTAssertTrue(t.running, @"task died prematurely");

    suc = [@"" writeToFile:markerFile
                atomically:YES
                  encoding:NSUTF8StringEncoding
                     error:&error];
    XCTAssertTrue(suc, @"write to file '%@' failed: %@", markerFile, error);
    XCTAssertNil(error, @"error not nil");
    BRUEitherErrorOrSuccess *mSuc = [BRUEitherErrorOrSuccess takeFromBox:box
                                                           timeoutAtDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    XCTAssertTrue(mSuc.success, @"termination handler not called: %@", mSuc.error);
    XCTAssertTrue(mSuc.object == t, @"notified object (%p) not same as started task (%p)", mSuc.object, t);
    XCTAssertNil(mSuc.error, @"error object not nil: %@", mSuc.error);
    XCTAssertTrue(NSTaskTerminationReasonExit == t.terminationReason,
                  @"wrong termination reason: %ld", t.terminationReason);
    XCTAssertTrue(42 == t.terminationStatus, @"wrong exit code: %d", t.terminationStatus);

    XCTAssertFalse(t.running);
}


- (void)testBRUTaskDeallocedBeforeStarted
{
    id n = nil;
    {
        __attribute__ ((objc_precise_lifetime)) BRUTask *t = [[BRUTask alloc] init];
        XCTAssertNotNil(t, @"BRUTask alloc didn't work. Just using t here :-)");
    }
    XCTAssertNil(n, @"n != nil, just random code here that runs after t has been dealloced");
}

@end
