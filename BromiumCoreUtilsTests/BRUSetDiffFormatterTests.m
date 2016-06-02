//
//  BRUSetDiffFormatterTests.m
//  BromiumCoreUtils
//
//  Created by Johannes Weiß on 02/06/2016.
//  Copyright © 2016 Bromium UK Ltd. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <BRUSetDiffFormatter.h>

@interface BRUSetDiffFormatterTests : XCTestCase

@end

@implementation BRUSetDiffFormatterTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testSetFormattingBothEmpty
{
    NSString *actual = [BRUSetDiffFormatter formatDiffWithSet:[NSSet set] andSet:[NSSet set] options:nil];
    NSString *expected = @"DIFF (0 elements --> 0 elements) -0 +0: <>";
    XCTAssertEqualObjects(actual, expected, @"Set formatting problem");
}

- (void)testSetFormattingBothNil
{
    NSString *actual = [BRUSetDiffFormatter formatDiffWithSet:nil andSet:nil options:nil];
    NSString *expected = @"DIFF (0 elements <NULL> --> 0 elements <NULL>) -0 +0: <>";
    XCTAssertEqualObjects(actual, expected, @"Set formatting problem");
}

- (void)testSetFormattingOrigNil
{
    NSString *actual = [BRUSetDiffFormatter formatDiffWithSet:nil andSet:[NSSet setWithObject:@"foo"] options:nil];
    NSString *expected = @"DIFF (0 elements <NULL> --> 1 elements) -0 +1: <+'foo'>";
    XCTAssertEqualObjects(actual, expected, @"Set formatting problem");
}

- (void)testSetFormattingNewNil
{
    NSString *actual = [BRUSetDiffFormatter formatDiffWithSet:[NSSet setWithObject:@"foo"] andSet:nil options:nil];
    NSString *expected = @"DIFF (1 elements --> 0 elements <NULL>) -1 +0: <-'foo'>";
    XCTAssertEqualObjects(actual, expected, @"Set formatting problem");
}

- (void)testSetFormattingP1M1
{
    NSString *actual = [BRUSetDiffFormatter formatDiffWithSet:[NSSet setWithObjects:@"foo", @"bar", nil]
                                                       andSet:[NSSet setWithObjects:@"bar", @"buz", nil]
                                                      options:nil];
    NSString *expected = @"DIFF (2 elements --> 2 elements) -1 +1: <-'foo' +'buz'>";
    XCTAssertEqualObjects(actual, expected, @"Set formatting problem");
}

- (void)testSetFormattingP3M0
{
    NSString *actual = [BRUSetDiffFormatter formatDiffWithSet:[NSSet setWithObjects:@"foo", @"bar", nil]
                                                       andSet:[NSSet setWithObjects:@"foo", @"bar",@"buz",@"qux",@"quux",nil]
                                                      options:nil];
    NSString *expected = @"DIFF (2 elements --> 5 elements) -0 +3: <+'buz' +'qux' +'quux'>";
    XCTAssertEqualObjects(actual, expected, @"Set formatting problem");
}

- (void)testSetFormattingPtooManyM1
{
    NSString *actual = [BRUSetDiffFormatter formatDiffWithSet:[NSSet setWithObjects:@"foo", @"bar", nil]
                                                       andSet:[NSSet setWithObjects:@"foo", @"buz", @"qux", @"quux",nil]
                                                      options:@{kBRUSetDiffFormatterOptionMaxDiffPrints:@2}];
    NSString *expectedPrefix = @"DIFF (2 elements --> 4 elements) -1 +3: <-'bar'";
    NSString *expectedSuffix = @"+...>";
    XCTAssertTrue([actual hasPrefix:expectedPrefix], @"Set formatting problem");
    XCTAssertTrue([actual hasSuffix:expectedSuffix], @"Set formatting problem");
}

- (void)testSetFormattingP0Mmax
{
    NSString *actual = [BRUSetDiffFormatter formatDiffWithSet:[NSSet setWithObjects:@"foo", @"bar", nil]
                                                       andSet:[NSSet setWithObjects:@"foo", nil]
                                                      options:@{kBRUSetDiffFormatterOptionMaxDiffPrints:@1}];
    NSString *expected = @"DIFF (2 elements --> 1 elements) -1 +0: <-'bar'>";
    XCTAssertEqualObjects(actual, expected, @"Set formatting problem");
}

- (void)testSetFormattingP0MtooMany
{
    NSString *actual = [BRUSetDiffFormatter formatDiffWithSet:[NSSet setWithObjects:@"foo bar", @"foo buz", nil]
                                                       andSet:[NSSet set]
                                                      options:@{kBRUSetDiffFormatterOptionMaxDiffPrints:@1}];
    NSString *expectedPrefix = @"DIFF (2 elements --> 0 elements) -2 +0: <-'foo ";
    NSString *expectedSuffix = @"-...>";
    XCTAssertTrue([actual hasPrefix:expectedPrefix], @"Set formatting problem");
    XCTAssertTrue([actual hasSuffix:expectedSuffix], @"Set formatting problem");
}

@end
