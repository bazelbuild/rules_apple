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

/// Shared options for the subcommand of CodeSigningTool to properly code sign a set of files.
public struct CodeSignProcessOptions: ParsableArguments {

  public init() {}

  @Option(
    name: .customLong("codesign"),
    help: "Mandatory. Path to the codesign binary that this process will invoke for signing.",
    transform: URL.init(fileURLWithPath:)
  )
  public private(set) var codesignBinaryPath: URL?

  @Option(
    name: .customLong("directory_to_sign"),
    help: """
      Path to a directory for the process to code sign. If the directory does not exist, the process
      will silently ignore the path.

      Must be provided if --target_to_sign is not.
      """,
    transform: URL.init(fileURLWithPath:)
  )
  public private(set) var directoriesToSign: [URL]

  @Flag(
    name: .customLong("disable_signing"),
    help: """
      Mutually exclusive flag to disable signing. If set, then no other code signing options can be
      set on the command line interface or the process will fail.
      """)
  public private(set) var disableSigning: Bool = false

  @Option(
    name: .customLong("entitlements"),
    help: """
      Path to an entitlements XML file to base all code signing operations around. This should never
      be provided for simulator builds, as simulator binaries will have the XML and DER encoded
      entitlements embedded within the built binaries.
      """,
    transform: URL.init(fileURLWithPath:)
  )
  public private(set) var entitlementsFilePath: URL?

  @Flag(
    name: .customLong("force"),
    help: """
      Replaces any code signing signatures from all of the paths given.
      """)
  public private(set) var forceCodeSigning: Bool = false

  @Option(
    name: .customLong("identity"),
    help: """
      A specific code signing identity to sign with. If one is not provided, this will be inferred
      based on the contents of the provisioning profile.
      """
  )
  public private(set) var codeSigningIdentity: String?

  @Option(
    name: .customLong("mobileprovision"),
    help: """
      Mandatory. Path to a provisioning profile to base all code signing operations around.
      """,
    transform: URL.init(fileURLWithPath:)
  )
  public private(set) var provisioningProfilePath: URL?

  @Option(
    name: .customLong("signed_path"),
    help: """
      Indicates a path within the bundle or signed artifact that has already been signed. This path
      will be excluded from the signing process. If the path is not found within the bundle, a
      warning will be generated.
      """,
    transform: URL.init(fileURLWithPath:)
  )
  public private(set) var alreadySignedPaths: [URL]

  @Option(
    name: .customLong("target_to_sign"),
    help: """
      Path to a target for the process to code sign. Must be provided if --directory_to_sign is not.
      """,
    transform: URL.init(fileURLWithPath:)
  )
  public private(set) var targetsToSign: [URL]

  public func validate() throws {
    if self.disableSigning == true {
      // TODO(b/336345916): Perform validation here where nothing else from CodeSignProcessOptions,
      // including mandatory values, should be declared if the disableSigning option is enabled.
    } else {
      // TODO(b/336345916): If the disableSigning option is NOT enabled, then the mandatory
      // CodeSignProcessOptions should be declared where necessary. For ArgumentParser's sake these
      // will have to be treated as Optional at the ivar definition and verified here.
      //
      // The following arguments are mandatory; mobileprovision, codesign.
      //
      // The following arguments are mutually exclusive; target_to_sign, directory_to_sign. One and
      // only one must be non-empty.
      //
      // All other arguments were considered optional by the original Python implementation.
    }
  }

}
