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

/// Entry point for XCFrameworkProcessorTool.
///
/// This command line application acts as a helper for the Apple BUILD rules to process components
/// of an imported XCFramework that cannot be done with shared methods or analysis time logic.
@main
struct XCFrameworkProcessorTool: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "xcframework_processor_tool",
    abstract: """
      XCFrameworkProcessorTool: Tool to validate and process the contents of an XCFramework.
      """,
    subcommands: [ValidateRootInfoPlist.self],  // TODO(b/335516374): Add codeless dylib support.
    defaultSubcommand: ValidateRootInfoPlist.self
  )
}
