//
//  BRUResourceCleanupTests.m
//  BromiumUtils
//
//  Created by Johannes Weiß on 19/01/2016.
//  Copyright © 2016 Bromium UK Ltd. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <BRUTemporaryFiles.h>
#import <BRUResourceCleanup.h>

@interface BRUResourceCleanupTests : XCTestCase

@end

@implementation BRUResourceCleanupTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testEmptyCleanupIsFineDiscarded
{
    BRUResourceCleanup *cleanup = [BRUResourceCleanup new];
    [cleanup discardAllCleanups];
}

- (void)testEmptyCleanupIsFineWithRunning
{
    BRUResourceCleanup *cleanup = [BRUResourceCleanup new];
    NSError *error = nil;
    BOOL suc = [cleanup runAllCleanupsWithError:&error];
    XCTAssertTrue(suc, @"not successful: %@", error);
}

- (void)testCleanupDiscardsEverythingIfToldToDo
{
    __block int timesRun = 0;
    BRUResourceCleanup *cleanup = [BRUResourceCleanup new];
    [cleanup addResourceNonFallibleCleanupBlock:^{
        timesRun++;
    }];
    [cleanup addResourceNonFallibleCleanupBlock:^{
        timesRun++;
    }];
    [cleanup addResourceNonFallibleCleanupBlock:^{
        timesRun++;
    }];
    [cleanup discardAllCleanups];
    XCTAssertEqual(0, timesRun);
}

- (void)testCleanupRunStuffJustFine
{
    __block int timesRun = 0;
    BRUResourceCleanup *cleanup = [BRUResourceCleanup new];
    [cleanup addResourceNonFallibleCleanupBlock:^{
        timesRun++;
    }];
    [cleanup addResourceNonFallibleCleanupBlock:^{
        timesRun++;
    }];
    [cleanup addResourceNonFallibleCleanupBlock:^{
        timesRun++;
    }];
    NSError *error = nil;
    BOOL suc = [cleanup runAllCleanupsWithError:&error];
    XCTAssertTrue(suc, @"not successful: %@", error);
    XCTAssertEqual(3, timesRun);
}

- (void)testCleanupRunStuffEvenIfSomethingFails
{
    NSError *expectedError = [NSError errorWithDomain:NSPOSIXErrorDomain
                                                 code:EINVAL
                                             userInfo:@{@"test":@"error"}];
    __block int timesRun = 0;
    BRUResourceCleanup *cleanup = [BRUResourceCleanup new];
    [cleanup addResourceNonFallibleCleanupBlock:^{
        timesRun++;
    }];
    [cleanup addResourceCleanupBlock:^BOOL(BRUOutError outError) {
        timesRun++;
        BRU_ASSIGN_OUT_PTR(outError, expectedError);
        return NO;
    }];
    [cleanup addResourceNonFallibleCleanupBlock:^{
        timesRun++;
    }];
    NSError *error = nil;
    BOOL suc = [cleanup runAllCleanupsWithError:&error];
    XCTAssertFalse(suc);
    XCTAssertEqualObjects(expectedError, error);
    XCTAssertEqual(3, timesRun);
}

- (void)testClosingFDConvenienceMethodWords
{
    int pipe_fds[2] = {0, 0};
    int suc = pipe(pipe_fds);
    XCTAssert(suc >= 0);
    char buf[1024];
    BRUResourceCleanup *cleanup = [BRUResourceCleanup new];
    [cleanup addCleanupBlockForClosingFileDescriptor:pipe_fds[1]];
    NSError *error = nil;
    BOOL cleanupSuc = [cleanup runAllCleanupsWithError:&error];
    XCTAssertTrue(cleanupSuc, @"cleanup failed: %@", error);
    ssize_t readBytes = read(pipe_fds[0], buf, 1024);
    XCTAssertEqual(0, readBytes);
}

- (void)testDeleteFileSystemItemConvenienceMethodWorks
{
    NSError *error = nil;
    NSString *file = [BRUTemporaryFiles createTemporaryFileError:&error];
    XCTAssertTrue(file, @"temp file creation failed: %@", error);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:file]);
    BRUResourceCleanup *cleanup = [BRUResourceCleanup new];
    [cleanup addCleanupBlockForDeletingFileSystemItemAtPath:file];
    BOOL cleanupSuc = [cleanup runAllCleanupsWithError:&error];
    XCTAssertTrue(cleanupSuc, @"clean up failed: %@", error);
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:file]);
}

- (void)testFailsAndSetsFileNotFoundErrorIfOneOfTheFilesDidntExist
{
    NSError *error = nil;

    // Create file1
    NSString *file1 = [BRUTemporaryFiles createTemporaryFileError:&error];
    XCTAssertNotNil(file1, @"temp file creation failed: %@", error);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:file1]);

    // Create file2
    NSString *file2 = [BRUTemporaryFiles createTemporaryFileError:&error];
    XCTAssertNotNil(file2, @"temp file creation failed: %@", error);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:file2]);

    // Add both files to cleanup
    BRUResourceCleanup *cleanup = [BRUResourceCleanup new];
    [cleanup addCleanupBlockForDeletingFileSystemItemAtPath:file1];
    [cleanup addCleanupBlockForDeletingFileSystemItemAtPath:file1];

    // Delete file2 before running clean-up
    BOOL success = [[NSFileManager defaultManager] removeItemAtPath:file2 error:&error];
    XCTAssertTrue(success);
    XCTAssertNil(error);

    // Run cleanup and expect NSFileNoSuchFileError
    BOOL cleanupSuc = [cleanup runAllCleanupsWithError:&error];
    XCTAssertFalse(cleanupSuc, @"clean up should have failed");
    XCTAssertEqualObjects(NSCocoaErrorDomain, error.domain);
    XCTAssertEqual(NSFileNoSuchFileError, error.code);
}

@end
