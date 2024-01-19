#import <MixedAnswer/MixedAnswer.h>

#import "examples/multi_platform/MixedLibWithHeaderMap/MixedAnswer-Swift.h"

@implementation MixedAnswerObjc

+ (NSString *)mixedAnswerObjc {
    return [NSString stringWithFormat:@"%@_%@", @"mixedAnswerObjc", [MixedAnswerSwift swiftToObjcMixedAnswer]];
}

@end
