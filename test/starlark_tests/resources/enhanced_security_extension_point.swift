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

import ExtensionFoundation

@available(iOS 26.0, macOS 26.0, *)
extension AppExtensionPoint {
  @Definition
  static var exampleExtension: AppExtensionPoint {
    Name("extension-point")
    EnhancedSecurity()
  }
}

@main
struct DummyApp {
  static func main() {}
}
