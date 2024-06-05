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

/// Entry point for ImportedFrameworkProcessor.
///
/// This command line application acts as a helper for the Apple BUILD rules to process precompiled
/// frameworks referenced from the build graph's dependencies to make adjustments required for code
/// signing and distributing their contents.
@main
struct ImportedFrameworkProcessor: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "imported_framework_processor",
    abstract: """
      ImportedFrameworkProcessor: Tool to process the contents of a precompiled framework.
      """,
    subcommands: [ProcessDynamicFramework.self],
    defaultSubcommand: ProcessDynamicFramework.self
  )
}
