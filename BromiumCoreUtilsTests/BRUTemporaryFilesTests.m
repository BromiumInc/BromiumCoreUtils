//
//  BRUTemporaryFilesTests.m
//  BromiumUtils
//
//  Created by Johannes Weiß on 31/05/2016.
//  Copyright © 2016 Bromium UK Ltd. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "BRUSetDiffFormatter.h"
#import "BRUTemporaryFiles.h"

@interface BRUTemporaryFilesTests : XCTestCase

@end

@implementation BRUTemporaryFilesTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
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

- (void)testCreateTempFileWithBasenameTemplateInDirectory
{
    NSError *err = nil;
    NSString *tmp = [BRUTemporaryFiles createTemporaryFileWithBasenameTemplate:@"foo-bar.XXXXXX"
                                                                   inDirectory:@"/tmp" error:&err];
    XCTAssertNil(err, @"err should be nil");
    XCTAssertNotNil(tmp, @"tmp should be the temp file name");
    XCTAssertTrue([tmp hasPrefix:@"/tmp/"], @"temp file in wrong directory");
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:tmp], @"temp file does not exist");
    XCTAssertTrue([[tmp lastPathComponent] hasPrefix:@"foo-bar."], @"temp file has wrong file name");
    XCTAssertEqual([[tmp lastPathComponent] length], (NSUInteger)14, @"temp file has wrong file name (length)");
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtPath:tmp error:&err], @"cannot remove temp file: %@", err);
}

- (void)testCreateTempFileWithBasenameTemplateInDirectoryWrongWithSlash
{
    NSError *err = nil;
    NSString *tmp = [BRUTemporaryFiles createTemporaryFileWithBasenameTemplate:@"foo-bar/XXXXXX"
                                                                   inDirectory:@"/tmp" error:&err];
    XCTAssertNotNil(err, @"err should not be nil");
    XCTAssertNil(tmp, @"tmp should be nil");
}

- (void)testCreateTempFileWithBasenameTemplateInDirectoryWrongWithoutXXXXXX
{
    NSError *err = nil;
    NSString *tmp = [BRUTemporaryFiles createTemporaryFileWithBasenameTemplate:@"foo-bar.X"
                                                                   inDirectory:@"/tmp" error:&err];
    XCTAssertNotNil(err, @"err should not be nil");
    XCTAssertNil(tmp, @"tmp should be nil");
}


- (void)testCreateTempFileWithSuffix
{
    NSString *suffix = @".txt";

    NSError *err = nil;
    NSString *tmp = [BRUTemporaryFiles createTemporaryFileWithSuffix:suffix error:&err];

    XCTAssertNil(err, @"err should be nil");
    XCTAssertNotNil(tmp, @"tmp should be the temp file name");
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:tmp], @"temp file does not exist");
    XCTAssertTrue([[tmp lastPathComponent] hasSuffix:suffix], @"temp file has wrong file name");
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtPath:tmp error:&err], @"cannot remove temp file: %@", err);
}

- (void)testCreateTempFileWithSuffixContainingWeirdCharacters
{
    NSString *suffix = @"⌘👊🔥🐱⎋🐌☑️⏎🌯";

    NSError *err = nil;
    NSString *tmp = [BRUTemporaryFiles createTemporaryFileWithSuffix:suffix error:&err];

    XCTAssertNil(err, @"err should be nil");
    XCTAssertNotNil(tmp, @"tmp should be the temp file name");
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:tmp], @"temp file does not exist");
    XCTAssertTrue([[tmp lastPathComponent] hasSuffix:suffix], @"temp file has wrong file name");
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtPath:tmp error:&err], @"cannot remove temp file: %@", err);
}

- (void)testCreateTempFileWithNilSuffix
{
    NSString *suffix = nil;

    NSError *err = nil;
    NSString *tmp = [BRUTemporaryFiles createTemporaryFileWithSuffix:suffix error:&err];

    XCTAssertNil(err, @"err should be nil");
    XCTAssertNotNil(tmp, @"tmp should be the temp file name");
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:tmp], @"temp file does not exist");
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtPath:tmp error:&err], @"cannot remove temp file: %@", err);
}

- (void)testCreateTempFileWithInvalidSuffix
{
    NSString *suffix = @"invalid/suffix";

    NSError *err = nil;
    NSString *tmp = [BRUTemporaryFiles createTemporaryFileWithSuffix:suffix error:&err];

    XCTAssertNotNil(err, @"err should not be nil");
    XCTAssertNil(tmp, @"tmp should be nil");
}

- (void)testCreateTempFileWithBasenameTemplateAndSuffix
{
    NSError *err = nil;
    NSString *tmp = [BRUTemporaryFiles createTemporaryFileWithBasenameTemplate:@"foo-bar.XXXXXX"
                                                                        suffix:@"baz"
                                                                   inDirectory:@"/tmp"
                                                                         error:&err];
    XCTAssertNil(err, @"err should be nil");
    XCTAssertNotNil(tmp, @"tmp should be the temp file name");
    XCTAssertTrue([tmp hasPrefix:@"/tmp/"], @"temp file in wrong directory");
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:tmp], @"temp file does not exist");
    XCTAssertTrue([[tmp lastPathComponent] hasPrefix:@"foo-bar."], @"temp file has wrong file name");
    XCTAssertTrue([[tmp lastPathComponent] hasSuffix:@"baz"], @"temp file has wrong file name");
    XCTAssertEqual([[tmp lastPathComponent] length], (NSUInteger)17, @"temp file has wrong file name (length)");
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtPath:tmp error:&err], @"cannot remove temp file: %@", err);
}

- (void)testCreateTempFileWithBasenameTemplateMissingXXXXXAndSuffixAddingMissingXXXXXes
{
    NSError *err = nil;
    NSString *tmp = [BRUTemporaryFiles createTemporaryFileWithBasenameTemplate:@"foo-bar.X"
                                                                        suffix:@"XXXXX"
                                                                   inDirectory:@"/tmp"
                                                                         error:&err];
    XCTAssertNotNil(err, @"err should not be nil");
    XCTAssertNil(tmp, @"tmp should be nil");
}

- (void)testCreateTempFileInDirectory
{
    NSError *err = nil;
    NSString *tmp = [BRUTemporaryFiles createTemporaryFileInDirectory:@"/tmp" error:&err];
    XCTAssertNil(err, @"err should be nil");
    XCTAssertNotNil(tmp, @"tmp should be the temp file name");
    XCTAssertTrue([tmp hasPrefix:@"/tmp/"], @"temp file in wrong directory");
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:tmp], @"temp file does not exist");
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtPath:tmp error:&err], @"cannot remove temp file: %@", err);
}

- (void)testCreateTempFileInDirectoryCheckActuallyInDirectory
{
    NSError *err = nil;
    NSString *tmpDir = [BRUTemporaryFiles createTemporaryDirectoryError:&err];
    XCTAssertNil(err, @"err should be nil");
    XCTAssertNotNil(tmpDir, @"tmpDir should be non nil");
    NSString *tmp = [BRUTemporaryFiles createTemporaryFileInDirectory:tmpDir error:&err];
    XCTAssertNil(err, @"err should be nil");
    XCTAssertNotNil(tmp, @"tmp should be the temp file name");
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:tmp], @"temp file does not exist");
    XCTAssertEqualObjects([tmpDir stringByAppendingPathComponent:[tmp lastPathComponent]], tmp, @"tmp not in tmpDir");
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtPath:tmpDir error:&err], @"cannot remove temp dir: %@", err);
}

- (void)testCreateTempFileInDirectoryNil
{
    NSError *err = nil;
    NSString *tmp = [BRUTemporaryFiles createTemporaryFileInDirectory:nil error:&err];
    XCTAssertNil(err, @"err should be nil");
    XCTAssertNotNil(tmp, @"tmp should be the temp file name");
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:tmp], @"temp file does not exist");
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtPath:tmp error:&err], @"cannot remove temp file: %@", err);
}

- (void)testCreateTempFile
{
    NSError *err = nil;
    NSString *tmp = [BRUTemporaryFiles createTemporaryFileError:&err];
    XCTAssertNil(err, @"err should be nil");
    XCTAssertNotNil(tmp, @"tmp should be the temp file name");
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:tmp], @"temp file does not exist");
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtPath:tmp error:&err], @"cannot remove temp file: %@", err);
}

- (void)testCreateTempDirectoryInDirectory
{
    NSError *err = nil;
    BOOL isDirectory = NO;
    NSString *tmp = [BRUTemporaryFiles createTemporaryDirectoryInDirectory:@"/tmp" error:&err];
    XCTAssertNil(err, @"err should be nil");
    XCTAssertNotNil(tmp, @"tmp should be the temp dir name");
    XCTAssertTrue([tmp hasPrefix:@"/tmp/"], @"temp dir in wrong directory");
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:tmp isDirectory: &isDirectory], @"temp dir does not exist");
    XCTAssertTrue(isDirectory, @"temp dir is not a dir");
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtPath:tmp error:&err], @"cannot remove temp dir: %@", err);
}

- (void)testCreateTempDirectoryInDirectoryNil
{
    NSError *err = nil;
    BOOL isDirectory = NO;
    NSString *tmp = [BRUTemporaryFiles createTemporaryDirectoryInDirectory:nil error:&err];
    XCTAssertNil(err, @"err should be nil");
    XCTAssertNotNil(tmp, @"tmp should be the temp dir name");
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:tmp isDirectory: &isDirectory], @"temp dir does not exist");
    XCTAssertTrue(isDirectory, @"temp dir is not a dir");
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtPath:tmp error:&err], @"cannot remove temp dir: %@", err);
}

- (void)testCreateTempDirectory
{
    NSError *err = nil;
    BOOL isDirectory = NO;
    NSString *tmp = [BRUTemporaryFiles createTemporaryDirectoryError:&err];
    XCTAssertNil(err, @"err should be nil");
    XCTAssertNotNil(tmp, @"tmp should be the temp dir name");
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:tmp isDirectory: &isDirectory], @"temp dir does not exist");
    XCTAssertTrue(isDirectory, @"temp dir is not a dir");
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtPath:tmp error:&err], @"cannot remove temp dir: %@", err);
}

- (void)testOpenTempFileOutFilenameInDirectory
{
    NSError *err = nil;
    NSString *tmp = nil;
    NSFileHandle *fh = [BRUTemporaryFiles openTemporaryFileInDirectory:@"/tmp"
                                                           outFilename:&tmp
                                                                 error:&err];
    XCTAssertNil(err, @"err should be nil");
    XCTAssertNotNil(tmp, @"filename should be non nil");
    XCTAssertNotNil(fh, @"file handle should be non nil");
    [fh closeFile];
    XCTAssertTrue([tmp hasPrefix:@"/tmp/"], @"temp file in wrong directory");
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:tmp], @"temp file does not exist");
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtPath:tmp error:&err], @"cannot remove temp file: %@", err);
}

- (void)testOpenTempFileInDirectory
{
    NSError *err = nil;
    NSFileHandle *fh = [BRUTemporaryFiles openTemporaryFileInDirectory:@"/tmp"
                                                                 error:&err];
    XCTAssertNil(err, @"err should be nil");
    XCTAssertNotNil(fh, @"file handle should be non nil");
    [fh closeFile];
}

- (void)testOpenTempFileOutFilenameInDirectoryNil
{
    NSError *err = nil;
    NSString *tmp = nil;
    NSFileHandle *fh = [BRUTemporaryFiles openTemporaryFileInDirectory:nil
                                                           outFilename:&tmp
                                                                 error:&err];
    XCTAssertNil(err, @"err should be nil");
    XCTAssertNotNil(tmp, @"filename should be non nil");
    XCTAssertNotNil(fh, @"file handle should be non nil");
    [fh closeFile];
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:tmp], @"temp file does not exist");
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtPath:tmp error:&err], @"cannot remove temp file: %@", err);
}

- (void)testOpenTempFile
{
    NSError *err = nil;
    NSFileHandle *fh = [BRUTemporaryFiles openTemporaryFileError:&err];
    XCTAssertNil(err, @"err should be nil");
    XCTAssertNotNil(fh, @"file handle should be non nil");
    [fh closeFile];
}

- (void)testOpenTempFileInNonExistantDirectoryFail
{
    NSError *err = nil;
    NSFileHandle *fh = [BRUTemporaryFiles openTemporaryFileInDirectory:@"/This/Directory/Does/Not/Exist"
                                                                 error:&err];
    XCTAssertNotNil(err, @"err should be non nil");
    XCTAssertNil(fh, @"file handle should be nil");
    XCTAssertEqual(NSPOSIXErrorDomain, err.domain, @"error domain should be POSIX");
    XCTAssertEqual((NSInteger)ENOENT, err.code, @"error should be ENOENT");
}

- (void)testCreateTempDirectoryInNonExistantDirectoryFail
{
    NSError *err = nil;
    NSString *tmp = [BRUTemporaryFiles createTemporaryDirectoryInDirectory:@"/This/Directory/Does/Not/Exist"
                                                                     error:&err];
    XCTAssertNotNil(err, @"err should be non nil");
    XCTAssertNil(tmp, @"path should be nil");
    XCTAssertEqual(NSPOSIXErrorDomain, err.domain, @"error domain should be POSIX");
    XCTAssertEqual((NSInteger)ENOENT, err.code, @"error should be ENOENT");
}

- (void)testCreateTempFileInNonExistantDirectoryFail
{
    NSError *err = nil;
    NSString *tmp = [BRUTemporaryFiles createTemporaryFileInDirectory:@"/This/Directory/Does/Not/Exist"
                                                                error:&err];
    XCTAssertNotNil(err, @"err should be non nil");
    XCTAssertNil(tmp, @"path should be nil");
    XCTAssertEqual(NSPOSIXErrorDomain, err.domain, @"error domain should be POSIX");
    XCTAssertEqual((NSInteger)ENOENT, err.code, @"error should be ENOENT");
}

- (void)testCreateTemporaryFileErrorNil
{
    NSError *err = nil;
    NSString *tmp = [BRUTemporaryFiles createTemporaryFileError:nil];
    XCTAssertNotNil(tmp, @"tmp should be the temp file name");
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:tmp], @"temp file does not exist");
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtPath:tmp error:&err], @"cannot remove temp file: %@", err);
}

- (void)testCreateTemporaryFileInNonExistantDirecotryErrorNilFail
{
    NSString *tmp = [BRUTemporaryFiles createTemporaryFileInDirectory:@"/This/Directory/Does/Not/Exist"
                                                                error:nil];
    XCTAssertNil(tmp, @"tmp should be nil");
}

- (void)testCreateTemporaryDirectoryInNonExistantDirecotryErrorNilFail
{
    NSString *tmp = [BRUTemporaryFiles createTemporaryDirectoryInDirectory:@"/This/Directory/Does/Not/Exist"
                                                                     error:nil];
    XCTAssertNil(tmp, @"tmp should be nil");
}

- (void)testOpenTemporaryFileInNonExistantDirecotryErrorNilFail
{
    NSFileHandle *tmp = [BRUTemporaryFiles openTemporaryFileInDirectory:@"/This/Directory/Does/Not/Exist"
                                                            outFilename:nil
                                                                  error:nil];
    XCTAssertNil(tmp, @"tmp should be nil");
}

- (void)testCreateTemporaryDirectoryWithTemplateInDirectorySuccess
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *err = nil;
    NSString *parent = [BRUTemporaryFiles createTemporaryDirectoryError:nil];
    NSString *t = [BRUTemporaryFiles createTemporaryDirectoryWithBasenameTemplate:@"foo.XXXXXX"
                                                                      inDirectory:parent
                                                                            error:&err];
    BOOL isDir = NO;
    XCTAssertNotNil(t, @"t nil");
    XCTAssertNil(err, @"error was set");
    XCTAssertTrue([fm fileExistsAtPath:t isDirectory:&isDir], @"does not exist");

    [[NSFileManager defaultManager] removeItemAtPath:parent error:nil];

    XCTAssertTrue(isDir, @"is no directory");
    XCTAssertTrue([t hasPrefix:parent], @"is not in parent directory");
}

- (void)testCreateTemporaryDirectoryWithTemplateInDirectoryBadTemplate
{
    NSError *err = nil;
    NSString *t = [BRUTemporaryFiles createTemporaryDirectoryWithBasenameTemplate:@"foo"
                                                                      inDirectory:nil
                                                                            error:&err];
    XCTAssertNil(t, @"bad template not detected");
    XCTAssertNotNil(err, @"err not set");
}

- (void)testCreateTemporaryDirAndFileWithWeirdName
{
    NSError *error = nil;
    NSString *tdir = [BRUTemporaryFiles createTemporaryDirectoryWithBasenameTemplate:@"😩😈👲💥-XXXXXX"
                                                                         inDirectory:nil
                                                                               error:&error];
    XCTAssertNotNil(tdir, @"couldn't create temp dir: %@", error);
    NSString *tfile = [BRUTemporaryFiles createTemporaryFileWithBasenameTemplate:@"£😩€😈™👲ö👵ä😻ü💥ß🔥-💤XXXXXX"
                                                                     inDirectory:tdir
                                                                           error:&error];
    XCTAssertNotNil(tfile, @"couldn't create temp file: %@", error);
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tdir error:&error];
    XCTAssertNotNil(files, @"couldn't list dir: %@", error);
    XCTAssertEqualObjects(@[[tfile lastPathComponent]], files, @"directory listing wrong: %@", files);

    BOOL suc = [[NSFileManager defaultManager] removeItemAtPath:tdir error:&error];
    XCTAssertTrue(suc, @"couldn't remove temp dir: %@", error);
}

- (void)testWeDontLeakFileDescriptors
{
    NSSet *preOpenFDs = [self getAllOpenFileDescriptors];
    NSSet *postOpenFDs;

    @autoreleasepool {
        NSError *err = nil;
        NSString *tmp = [BRUTemporaryFiles createTemporaryFileError:nil];
        XCTAssertNotNil(tmp, @"tmp should not be nil");
        XCTAssertTrue([[NSFileManager defaultManager] removeItemAtPath:tmp error:&err], @"cannot remove temp file: %@", err);
    }

    postOpenFDs = [self getAllOpenFileDescriptors];
    XCTAssertEqualObjects(preOpenFDs, postOpenFDs,
                          @"We're leaking FDs: %@! pre open FDs: %@, post open FDs %@",
                          [BRUSetDiffFormatter formatDiffWithSet:preOpenFDs
                                                          andSet:postOpenFDs
                                                         options:nil],
                          preOpenFDs,
                          postOpenFDs);
}

@end
