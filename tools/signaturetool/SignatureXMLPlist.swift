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

import Foundation
import tools_signaturetool_signature_info

/// Converts a SignatureInfo data structure into an appropriate signatures XML plist file for an
/// xcarchive or IPA.
public struct SignatureXMLPlist {

  /// A Data representation of the encoded plist to be used for the signature XML plist.
  private let signatureInfoPlistData: Data

  /// Errors that may occur while encoding the signatures XML plist.
  public enum Error: Swift.Error {
    /// Indicates if the signature information couldn't be encoded to plist format.
    case plistEncodingFailed
  }

  public init(signatureInfo: SignatureInfo) throws {
    // TODO(b/304829417): Replace the use of PropertyListEncoder to write out an XML plist with an
    // XML serializer that will sort keys in a stable, ordered fashion. One candidate is the macOS
    // Foundation XMLDocument API, given options fully describing the format of an XML plist.
    let plistEncoder = PropertyListEncoder()
    plistEncoder.outputFormat = .xml

    guard let plistFileData = try? plistEncoder.encode(signatureInfo) else {
      throw Error.plistEncodingFailed
    }

    self.signatureInfoPlistData = plistFileData
  }

  /// Safely write a signatures XML plist to the given output path.
  public func writeFile(outputPath: URL) throws {
    try self.signatureInfoPlistData.write(to: outputPath, options: .atomic)
  }

}
