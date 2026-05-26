#import <XCTest/XCTest.h>

#import "test/starlark_tests/targets_under_test/ios/CoverageSharedLogic.h"

@interface CoverageStandaloneTest : XCTestCase
@end

@implementation CoverageStandaloneTest
- (void)testAnything {
  [[SharedLogic new] doSomething];
  XCTAssertTrue(YES);
}
@end
