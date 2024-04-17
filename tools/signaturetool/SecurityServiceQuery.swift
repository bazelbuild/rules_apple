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

public struct SecurityServiceQuery {

  /// A URL reference to the file or bundle to query code sign information from.
  private let artifactToQuery: URL

  /// Errors that may occur while querying the artifact.
  public enum Error: Swift.Error {

    /// Indicates if the static code object supplied by Security framework was empty.
    case SecStaticCodeEmpty

    /// Indicates if the signing information supplied by Security framework was empty.
    case SecSigningInformationEmpty

    /// Indicates if the Security framework supplied a user-readable error message string.
    case SecErrorMessageString(String)
  }

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

    /// A string indicating if the signature was adhoc ("SelfSigned") or came from a signing
    /// identity furnished by Apple ("AppleDeveloperProgram").
    public let signatureType: String?

    /// Indicates wheither the artifact was code signed.
    public let signed: Bool

    /// The source of the code signature used for the code object.
    public let source: String?

    init(
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
          ? "SelfSigned" : "AppleDeveloperProgram"
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
      case bundleIdentifier = "bundleIndentifier", cdhashes, certificates, isSecureTimestamp,
        metadata, signatureIdentifier, signatureType, signed, source
      // common_typos_enable
    }
  }

  public init(artifactToQuery: URL) {
    self.artifactToQuery = artifactToQuery
  }

  /// Return the Security framework static code object representing the artifact to query.
  private func secStaticCode() throws -> SecStaticCode {
    var secStaticCodePath: SecStaticCode?
    let osStatus = SecStaticCodeCreateWithPath(
      self.artifactToQuery as CFURL, [], &secStaticCodePath)
    guard osStatus == errSecSuccess else {
      let secErrorMessage = SecCopyErrorMessageString(osStatus, nil)
      throw Error.SecErrorMessageString(String(describing: secErrorMessage))
    }
    guard let secStaticCode = secStaticCodePath else {
      throw Error.SecStaticCodeEmpty
    }
    return secStaticCode
  }

  /// Return the Security framework signing information dictionary representing the artifact.
  private func signingInformation(secStaticCode: SecStaticCode) throws -> [String: Any] {
    let codeSignFlags = SecCSFlags(rawValue: kSecCSSigningInformation)
    var cfSigningInformation: CFDictionary?
    let osStatus = SecCodeCopySigningInformation(
      secStaticCode, codeSignFlags, &cfSigningInformation)
    guard osStatus == errSecSuccess else {
      let secErrorMessage = SecCopyErrorMessageString(osStatus, nil)
      throw Error.SecErrorMessageString(String(describing: secErrorMessage))
    }
    guard let signingInformation = cfSigningInformation as? [String: Any] else {
      throw Error.SecSigningInformationEmpty
    }
    return signingInformation
  }

  /// Return a structure that represents signing information needed for the output XML.
  public func signatureInfo(metadataInfo: [CollectSignaturesOptions.MetadataInfo])
    throws -> SignatureInfo
  {
    let secStaticCode = try self.secStaticCode()
    let infoDictionary = try self.signingInformation(secStaticCode: secStaticCode)
    let identifier = infoDictionary[kSecCodeInfoIdentifier as String] as? String

    return SignatureInfo(
      cdhashes: infoDictionary[kSecCodeInfoCdHashes as String] as? [Data],
      certificates: infoDictionary[kSecCodeInfoCertificates as String] as? [SecCertificate],
      flags: infoDictionary[kSecCodeInfoFlags as String] as? SecCodeSignatureFlags.RawValue,
      identifier: identifier,
      metadataInfo: metadataInfo,
      source: infoDictionary[kSecCodeInfoSource as String] as? String,
      teamIdentifier: infoDictionary[kSecCodeInfoTeamIdentifier as String] as? String)
  }

}
