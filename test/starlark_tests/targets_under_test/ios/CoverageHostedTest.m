#import <XCTest/XCTest.h>

#import "test/starlark_tests/targets_under_test/ios/CoverageMain.h"
#import "test/starlark_tests/targets_under_test/ios/CoverageSharedLogic.h"

@interface CoverageHostedTest : XCTestCase
@end

@implementation CoverageHostedTest
- (void)testHostedAPI {
  [[SharedLogic new] doSomething];
  XCTAssertEqual(1, coverageFoo());
}
@end
