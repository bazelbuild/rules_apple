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
import Foundation

/// Shared options for the subcommand of ImportedFrameworkProcessor to process dynamic frameworks.
public struct ProcessDynamicFrameworkOptions: ParsableArguments {

  public init() {}

  // TODO(b/335516374): Extend this to take in multiple binaries to lipo for codeless dylib support.
  @Option(
    help: """
      Path to the main executable binary file scoped to one of the imported frameworks.
      """,
    transform: URL.init(fileURLWithPath:)
  )
  public private(set) var frameworkBinaryPath: URL

  @Option(
    help: """
      Path to a file soped to one of the imported frameworks, distinct from the binary files.
      """,
    transform: URL.init(fileURLWithPath:)
  )
  public private(set) var frameworkFilePaths: [URL]

  @Option(
    help: """
      Path to save the zip file containing the imported precompiled framework after processing.
      """,
    transform: URL.init(fileURLWithPath:)
  )
  public private(set) var outputZipPath: URL

  @Option(
    help: """
      An expected architecture for the final processed binary within the framework.
      """
  )
  public private(set) var requestedArchitectures: [String]

  @Option(
    help: """
      Path to temporarily copy all framework files to.
      """,
    transform: URL.init(fileURLWithPath:)
  )
  public private(set) var temporaryFrameworkFilePath: URL

}
