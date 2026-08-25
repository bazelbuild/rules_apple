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
import Foundation

struct DummyConfiguration: AppExtensionConfiguration {
  func accept(connection: NSXPCConnection) -> Bool {
    return false
  }
}

@available(iOS 26.0, macOS 26.0, *)
@main
struct EnhancedSecurityExtension: AppExtension {
  var configuration: some AppExtensionConfiguration {
    DummyConfiguration()
  }

  @AppExtensionPoint.Bind
  var boundExtensionPoint: AppExtensionPoint {
    AppExtensionPoint.Identifier(
      host: "com.apple.example",
      name: "extension-point"
    )
  }
}
