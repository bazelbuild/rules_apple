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

/// Shared options for the subcommand of XCFrameworkProcessorTool for validating root Info.plists.
public struct ValidateRootInfoPlistOptions: ParsableArguments {

  public init() {}

  @Option(help: "The target Apple architecture (e.g. x84_64, arm64).")
  public private(set) var architecture: String

  @Option(help: "The XCFramework bundle name (i.e. name.xcframework).")
  public private(set) var bundleName: String

  @Option(help: "The target Apple environment (e.g. device, simulator).")
  public private(set) var environment: String

  @Option(help: "The assumed identifier for the platform we need.")
  public private(set) var libraryIdentifier: String

  @Option(
    help: "Path to the XCFramework Info.plist file that will be the source of truth.",
    transform: URL.init(fileURLWithPath:)
  )
  public private(set) var infoPlistInputPath: URL

  @Option(
    help: "Path to write the output file to signal success.",
    transform: URL.init(fileURLWithPath:)
  )
  public private(set) var outputPath: URL

  @Option(help: "The target Apple platform (e.g. macos, ios).")
  public private(set) var platform: String
}
