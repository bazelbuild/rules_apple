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

/// Shared options for the subcommands of SignatureTool for collecting code signed signatures.
public struct CollectSignaturesOptions: ParsableArguments {

  public init() {}

  /// A parsed key and value pair passed to the signatures tool with the `--metadata-info <key>=
  /// <value>` flag.
  public struct MetadataInfo: ExpressibleByArgument {
    /// A key representing metadata expected by App Store verification, such as "platform".
    public private(set) var key: String

    /// A value representing metadata expected by App Store verification, such as "iOS".
    public private(set) var value: String

    public init?(argument: String) {
      let components = argument.split(separator: "=", maxSplits: 1)
      guard components.count == 2 else { return nil }

      self.key = String(components[0])
      self.value = String(components[1])
    }
  }

  @Option(
    help: """
      A list representing extra string-based information to reference directly within the generated
      signatures XML in the form '<key>=<value>'. Each key and value provided will be referenced
      within a "metadata" dictionary in the final signatures XML as equivalent plist keys and string
      values.
      """
  )
  public private(set) var metadataInfo: [MetadataInfo] = []

  @Option(
    help: "Path to a code signed file or bundle that will be an input for the SignatureTool.",
    transform: URL.init(fileURLWithPath:)
  )
  public private(set) var signaturesInputPath: URL

  @Option(
    help: "Path to which the signatures XML plist should be written to.",
    transform: URL.init(fileURLWithPath:)
  )
  public private(set) var signaturesOutputPath: URL

}
