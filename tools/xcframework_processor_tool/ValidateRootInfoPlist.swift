// Copyright 2024 The Bazel Authors. All rights reserved.
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

import ArgumentParser
import tools_xcframework_processor_tool_validate_library_identifier
import tools_xcframework_processor_tool_validate_root_info_plist_options

/// XCFrameworkProcessorTool invocation that validates the root Info.plist matches earlier
/// assumptions made at analysis time to properly reference the XCFramework's binary and resources.
public struct ValidateRootInfoPlist: ParsableCommand {
  @OptionGroup
  private var sharedOptions: ValidateRootInfoPlistOptions

  public init() {}

  public func run() throws {
    // Setup the structures needed for validation.
    let validateLibraryIdentifier = ValidateLibraryIdentifier(
      architecture: sharedOptions.architecture,
      bundleName: sharedOptions.bundleName,
      environment: sharedOptions.environment,
      libraryIdentifier: sharedOptions.libraryIdentifier,
      platform: sharedOptions.platform,
      rootInfoPlist: sharedOptions.infoPlistInputPath)

    // Check that the library identifier matches expectations.
    try validateLibraryIdentifier.validate()

    // Signal to the build via the validation output group file output that validation succeeded.
    try "Success!".write(to: sharedOptions.outputPath, atomically: true, encoding: .utf8)
  }

}
