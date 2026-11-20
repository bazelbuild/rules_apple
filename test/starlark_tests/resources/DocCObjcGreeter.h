// Copyright 2026 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@import Foundation;

#import "test/starlark_tests/resources/DocCObjcSalutation.h"

/// A greeter that greets people by name.
@interface DocCObjcGreeter : NSObject

/// The salutation used when greeting.
@property(nonatomic, readonly) DocCObjcSalutation *salutation;

/// Returns a greeting for the given name.
///
/// - Parameter name: The name of the person to greet.
/// - Returns: The greeting.
- (NSString *)greetingForName:(NSString *)name;

@end
