#import <UIKit/UIKit.h>

int coverageFoo(void) {
  return 1;
}

@interface CoverageAppDelegate : UIResponder <UIApplicationDelegate>
@end

@implementation CoverageAppDelegate
@end

int main(int argc, char **argv) {
  return UIApplicationMain(argc, argv, nil, @"CoverageAppDelegate");
}
