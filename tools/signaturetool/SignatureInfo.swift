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
import Security
import tools_signaturetool_collect_signatures_options

/// Structure to represent the signature information itself and its format.
public struct SignatureInfo: Codable, Equatable {

  /// The signing identifier sealed into the signature; see Apple's kSecCodeInfoIdentifier docs.
  /// Despite the name of the key, the value has no explicit connection to the bundle identifier.
  public let bundleIdentifier: String?

  /// An array containing the binary identifier for every digest algorithm supported.
  public let cdhashes: [Data]?

  /// An array of certificates representing the certificate chain of the signing certificate.
  public let certificates: [Data]?

  /// Mandatory key that is always set to "false" in Xcode 15.3.
  public let isSecureTimestamp: Bool = false

  /// A dictionary of additional, optional values supplied by the build graph.
  public let metadata: [String: String]

  /// A string representing the team identifier of the artifact and signing certificate.
  public let signatureIdentifier: String?

  /// Custom enum indicating the type of signing identity used to generate the signature.
  public enum SignatureType: String, Codable {
    /// The adhoc identity, often represented by '-' in /usr/bin/codesign CLI input.
    case adhoc = "SelfSigned"
    /// A signing identity furnished by Apple.
    case appleProvidedIdentity = "AppleDeveloperProgram"
  }

  /// Instance of the enum indicating the type of signing identity used to generate the signature.
  public let signatureType: SignatureType?

  /// Indicates wheither the artifact was code signed.
  public let signed: Bool

  /// The source of the code signature used for the code object.
  public let source: String?

  public init(
    cdhashes: [Data]? = nil, certificates: [SecCertificate]? = nil,
    flags: SecCodeSignatureFlags.RawValue? = nil, identifier: String? = nil,
    metadataInfo: [CollectSignaturesOptions.MetadataInfo], source: String? = nil,
    teamIdentifier: String? = nil
  ) {
    self.bundleIdentifier = identifier
    self.cdhashes = cdhashes
    self.certificates = certificates?.map { SecCertificateCopyData($0) as Data }
    self.metadata = Dictionary(
      uniqueKeysWithValues: metadataInfo.map { ($0.key, $0.value) })
    self.signatureIdentifier = teamIdentifier
    if let rawFlags = flags {
      self.signatureType =
        SecCodeSignatureFlags(rawValue: rawFlags).contains(.adhoc)
        ? .adhoc : .appleProvidedIdentity
    } else {
      self.signatureType = nil
    }
    // Per Apple documentation for SecCodeCopySigningInformation, an absent kSecCodeInfoIdentifier
    // key indicates that the object is unsigned.
    self.signed = identifier != nil
    self.source = source
  }

  private enum CodingKeys: String, CodingKey {
    // common_typos_disable - The misspelled key "bundleIndentifier" is what it is for Xcode 15.3.
    case bundleIdentifier = "bundleIndentifier"
    // common_typos_enable
    case cdhashes, certificates, isSecureTimestamp,
      metadata, signatureIdentifier, signatureType, signed, source
  }
}
