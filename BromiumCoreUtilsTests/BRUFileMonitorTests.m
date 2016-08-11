//
//  Copyright (C) 2013-2016, Bromium Inc.
//
//  This software may be modified and distributed under the terms
//  of the BSD license.  See the LICENSE file for details.
//
//
//  Created by Steve Flack on 17/05/2013.
//


/* Bromium Libraries */
#import "BRUTemporaryFiles.h"

/* Local Imports */
#import "BRUFileMonitorTests.h"
#import "BRUFileMonitor.h"


@implementation BRUFileMonitorTests

+ (void)setUp
{
}

+ (void)tearDown
{
}

- (void)testThatFileMonitorStartsForBogusPath
{
    BRUFileMonitor *monitor = [[BRUFileMonitor alloc] initWithPath:@"/This/Is/A/Bad/Path"];
    
    BOOL rv;
    NSError *error = nil;
    rv = [monitor startWithError:&error
                        callback:^(__unused BRUFileMonitor *monitor) {
                        }];
    XCTAssertTrue(rv);
    XCTAssertNil(error);

    rv = [monitor stop:&error];
    XCTAssertTrue(rv);
    XCTAssertNil(error);
}

- (void)testThatBasicStartStopWorks
{
    BRUFileMonitor *monitor = [[BRUFileMonitor alloc] initWithPath:@"/tmp"];
    
    XCTAssertFalse(monitor.isMonitoring, @"Expected monitor to not be monitoring");
    
    BOOL rv;
    NSError *error = nil;
    rv = [monitor startWithError:&error
               callback:^(__unused BRUFileMonitor *monitor) {
               }];
    XCTAssertTrue(rv, @"Start failed unexpectedly: %@", error);
    XCTAssertTrue(monitor.isMonitoring, @"Expected monitor to be monitoring");
    
    error = nil;
    rv = [monitor stop:&error];
    XCTAssertTrue(rv, @"Stop failed unexpectedly: %@", error);
    
    XCTAssertFalse(monitor.isMonitoring, @"Expected monitor to not be monitoring");
}

- (void)testThatMultipleStartFails
{
    BRUFileMonitor *monitor = [[BRUFileMonitor alloc] initWithPath:@"/tmp"];
    
    BOOL rv;
    NSError *error = nil;
    rv = [monitor startWithError:&error
               callback:^(__unused BRUFileMonitor *monitor) {
               }];
    XCTAssertTrue(rv, @"Start failed unexpectedly: %@", error);
    
    error = nil;
    rv = [monitor startWithError:&error
               callback:^(__unused BRUFileMonitor *monitor) {
               }];
    XCTAssertFalse(rv, @"Second start succeeded unexpectedly");

    error = nil;
    rv = [monitor stop:&error];
    XCTAssertTrue(rv);
    XCTAssertNil(error);
}

- (void)testThatStopWhenStoppedFails
{
    BRUFileMonitor *monitor = [[BRUFileMonitor alloc] initWithPath:@"/tmp"];
    
    XCTAssertFalse(monitor.isMonitoring, @"Expected monitor to not be monitoring");
    
    NSError *error = nil;
    BOOL rv = [monitor stop:&error];
    XCTAssertFalse(rv, @"Stop should not have worked");
}

- (void)testNotificaitonWhenFileTouched
{
    NSString *path = [BRUTemporaryFiles createTemporaryFileError:nil];
    XCTAssertNotNil(path, @"failed to create temp file for test");

    BRUFileMonitor *monitor = [[BRUFileMonitor alloc] initWithPath:path];

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    BOOL rv = [monitor startWithError:nil
                             callback:^(__unused BRUFileMonitor *monitor) {
                                 dispatch_semaphore_signal(sem);
                             }];
    XCTAssertTrue(rv, @"Failed to start monitor");

    NSError *error = nil;
    rv = [@"test" writeToFile:path
                   atomically:YES
                     encoding:NSUTF8StringEncoding
                        error:&error];
    XCTAssertTrue(rv, @"Failed to write file: %@", error);

    long r = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)));
    XCTAssertEqual(r, (long)0, @"Failed to get file notification");

    BOOL success = [monitor stop:&error];
    XCTAssertTrue(success, @"file monitor stop unsuccessful: %@", error);
    success = [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
    XCTAssertTrue(success, @"removing temporary file unsuccessful: %@", error);
}

- (void)testNotificaitonWhenDirectoryHasNewFile
{
    NSString *path = [BRUTemporaryFiles createTemporaryDirectoryError:nil];
    XCTAssertNotNil(path, @"failed to create temp file for test");
    
    BRUFileMonitor *monitor = [[BRUFileMonitor alloc] initWithPath:path];
    
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    
    BOOL rv = [monitor startWithError:nil
                    callback:^(__unused BRUFileMonitor *monitor) {
                        dispatch_semaphore_signal(sem);
                    }];
    XCTAssertTrue(rv, @"Failed to start monitor");
    
    NSString *filepath = [path stringByAppendingPathComponent:@"test"];
    
    NSError *error = nil;
    rv = [@"test" writeToFile:filepath
                   atomically:YES
                     encoding:NSUTF8StringEncoding
                        error:&error];
    XCTAssertTrue(rv, @"Failed to write file: %@", error);

    long r = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)));
    XCTAssertEqual(r, (long)0, @"Failed to get directory notification");

    BOOL success = [monitor stop:&error];
    XCTAssertTrue(success, @"file monitor stop unsuccessful: %@", error);
    success = [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
    XCTAssertTrue(success, @"removing temporary directory unsuccessful: %@", error);
}

- (void)testNotificaitonWhenDirectoryHasDeletedFile
{
    NSString *path = [BRUTemporaryFiles createTemporaryDirectoryError:nil];
    XCTAssertNotNil(path, @"failed to create temp file for test");
    
    NSString *filepath = [path stringByAppendingPathComponent:@"test"];
    
    NSError *error = nil;
    BOOL rv = [@"test" writeToFile:filepath
                        atomically:YES
                          encoding:NSUTF8StringEncoding
                             error:&error];
    XCTAssertTrue(rv, @"Failed to write file: %@", error);
    
    BRUFileMonitor *monitor = [[BRUFileMonitor alloc] initWithPath:path];
    
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    
    rv = [monitor startWithError:nil
               callback:^(__unused BRUFileMonitor *monitor) {
                   dispatch_semaphore_signal(sem);
               }];
    XCTAssertTrue(rv, @"Failed to start monitor");
    
    error = nil;
    rv = [[NSFileManager defaultManager] removeItemAtPath:filepath
                                                    error:&error];
    XCTAssertTrue(rv, @"Failed to delete file: %@", error);

    long r = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)));
    XCTAssertEqual(r, (long)0, @"Failed to get directory notification");

    BOOL success = [monitor stop:&error];
    XCTAssertTrue(success, @"file monitor stop unsuccessful: %@", error);
    success = [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
    XCTAssertTrue(success, @"removing temporary directory unsuccessful: %@", error);
}

- (void)testNotificaitonWhenFileAppended
{
    NSString *path = [BRUTemporaryFiles createTemporaryDirectoryError:nil];
    XCTAssertNotNil(path, @"failed to create temp file for test");

    NSString *filepath = [path stringByAppendingPathComponent:@"test"];

    int fd = open([filepath fileSystemRepresentation], O_CREAT | O_WRONLY, 0644);
    int err = errno;
    XCTAssert(fd >= 0, @"Failed to open file: %s", strerror(err));
    write(fd, "test", 4);
    close(fd);

    BRUFileMonitor *monitor = [[BRUFileMonitor alloc] initWithPath:filepath];

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    NSError *error = nil;
    BOOL rv = [monitor startWithError:&error
                             callback:^(__unused BRUFileMonitor *monitor) {
                                 dispatch_semaphore_signal(sem);
                             }];
    XCTAssertTrue(rv, @"Failed to start monitor");
    XCTAssertNil(error);

    fd = open([filepath fileSystemRepresentation], O_WRONLY | O_APPEND);
    err = errno;
    XCTAssert(fd >= 0, @"Failed to open file: %s", strerror(err));
    write(fd, "helloworld", 10);
    close(fd);

    long r = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)));
    XCTAssertEqual(r, (long)0, @"Failed to get notification");

    BOOL success = [monitor stop:&error];
    XCTAssertTrue(success, @"file monitor stop unsuccessful: %@", error);
    success = [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
    XCTAssertTrue(success, @"removing temporary directory unsuccessful: %@", error);
}

- (void)testNotificaitonWhenFileModifiedByMemMap
{
    NSString *path = [BRUTemporaryFiles createTemporaryDirectoryError:nil];
    XCTAssertNotNil(path, @"failed to create temp file for test");

    NSString *filepath = [path stringByAppendingPathComponent:@"test"];

    NSError *error = nil;
    BOOL rv = [@"test" writeToFile:filepath
                        atomically:YES
                          encoding:NSUTF8StringEncoding
                             error:&error];
    XCTAssertTrue(rv, @"Failed to write file: %@", error);

    BRUFileMonitor *monitor = [[BRUFileMonitor alloc] initWithPath:filepath];

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    rv = [monitor startWithError:nil
                        callback:^(__unused BRUFileMonitor *monitor) {
                            dispatch_semaphore_signal(sem);
                        }];
    XCTAssertTrue(rv, @"Failed to start monitor");

    int fd = open([filepath fileSystemRepresentation], O_RDWR);
    int err = errno;
    XCTAssert(fd >= 0, @"Failed to open file: %s", strerror(err));

    char *bytes = (char*)mmap(0, 4, PROT_WRITE | PROT_READ, MAP_PRIVATE, fd, 0);
    bytes[1] = '4';
    close(fd);

    long r = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)));
    XCTAssertEqual(r, (long)0, @"Failed to get notification");

    BOOL success = [monitor stop:&error];
    XCTAssertTrue(success, @"file monitor stop unsuccessful: %@", error);
    success = [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
    XCTAssertTrue(success, @"removing temporary directory unsuccessful: %@", error);
}

- (void)testNotificaitonWhenDirectoryHasRewrittenFile
{
    NSString *path = [BRUTemporaryFiles createTemporaryDirectoryError:nil];
    XCTAssertNotNil(path, @"failed to create temp file for test");
    
    NSString *filepath = [path stringByAppendingPathComponent:@"test"];
    
    NSError *error = nil;
    BOOL rv = [@"test" writeToFile:filepath
                        atomically:YES
                          encoding:NSUTF8StringEncoding
                             error:&error];
    XCTAssertTrue(rv, @"Failed to write file: %@", error);
    
    BRUFileMonitor *monitor = [[BRUFileMonitor alloc] initWithPath:path];
    
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    
    rv = [monitor startWithError:nil
               callback:^(__unused BRUFileMonitor *monitor) {
                   dispatch_semaphore_signal(sem);
               }];
    XCTAssertTrue(rv, @"Failed to start monitor");
    
    error = nil;
    rv = [@"test2" writeToFile:filepath
                   atomically:YES
                     encoding:NSUTF8StringEncoding
                        error:&error];
    XCTAssertTrue(rv, @"Failed to write file: %@", error);

    long r = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)));
    XCTAssertEqual(r, (long)0, @"Failed to get directory notification");

    BOOL success = [monitor stop:&error];
    XCTAssertTrue(success, @"file monitor stop unsuccessful: %@", error);
    success = [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
    XCTAssertTrue(success, @"removing temporary directory unsuccessful: %@", error);
}

- (void)testFileComingIntoExistanceInDirectoryDirectly
{
    NSString *path = [BRUTemporaryFiles createTemporaryDirectoryError:nil];
    XCTAssertNotNil(path, @"failed to create temp file for test");

    NSString *filepath = [path stringByAppendingPathComponent:@"test"];

    BRUFileMonitor *monitor = [[BRUFileMonitor alloc] initWithPath:filepath];

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    BOOL rv = [monitor startWithError:nil
                             callback:^(__unused BRUFileMonitor *monitor) {
                                 dispatch_semaphore_signal(sem);
                             }];
    XCTAssertTrue(rv, @"Failed to start monitor");

    NSError *error = nil;
    rv = [@"test" writeToFile:filepath
                   atomically:YES
                     encoding:NSUTF8StringEncoding
                        error:&error];
    XCTAssertTrue(rv, @"Failed to write file: %@", error);

    long r = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)));
    XCTAssertEqual(r, (long)0, @"Failed to get directory notification");

    BOOL success = [monitor stop:&error];
    XCTAssertTrue(success, @"file monitor stop unsuccessful: %@", error);
    success = [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
    XCTAssertTrue(success, @"removing temporary directory unsuccessful: %@", error);
}

- (void)testFileSideBySideFileModifyOrDeleteDoesNotTrigger
{
    NSString *path = [BRUTemporaryFiles createTemporaryDirectoryError:nil];
    XCTAssertNotNil(path, @"failed to create temp file for test");

    NSString *filepath1 = [path stringByAppendingPathComponent:@"test1"];

    NSError *error = nil;
    BOOL rv = [@"test" writeToFile:filepath1
                        atomically:YES
                          encoding:NSUTF8StringEncoding
                             error:&error];
    XCTAssertTrue(rv, @"Failed to write file: %@", error);

    NSString *filepath2 = [path stringByAppendingPathComponent:@"test2"];

    error = nil;
    rv = [@"test" writeToFile:filepath1
                   atomically:YES
                     encoding:NSUTF8StringEncoding
                        error:&error];
    XCTAssertTrue(rv, @"Failed to write file: %@", error);

    BRUFileMonitor *monitor = [[BRUFileMonitor alloc] initWithPath:filepath1];

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    rv = [monitor startWithError:nil
                        callback:^(__unused BRUFileMonitor *monitor) {
                                 dispatch_semaphore_signal(sem);
                             }];
    XCTAssertTrue(rv, @"Failed to start monitor");

    error = nil;
    rv = [@"test42" writeToFile:filepath2
                     atomically:YES
                       encoding:NSUTF8StringEncoding
                          error:&error];
    XCTAssertTrue(rv, @"Failed to write file: %@", error);

    long r = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)));
    XCTAssertNotEqual(r, (long)0, @"Failed to get directory notification");

    error = nil;
    rv = [[NSFileManager defaultManager] removeItemAtPath:filepath2
                                                    error:&error];
    XCTAssertTrue(rv, @"Failed to delete file: %@", error);

    r = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)));
    XCTAssertNotEqual(r, (long)0, @"Failed to get directory notification");

    BOOL success = [monitor stop:&error];
    XCTAssertTrue(success, @"file monitor stop unsuccessful: %@", error);
    success = [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
    XCTAssertTrue(success, @"removing temporary directory unsuccessful: %@", error);
}

@end
