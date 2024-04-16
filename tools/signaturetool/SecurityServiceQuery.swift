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

    /// Mandatory key that is always set to "false" in Xcode 15.3.
    public let isSecureTimestamp: Bool = false

    /// A dictionary of additional, optional values supplied by the build graph.
    public let metadata: [String: String]

    /// Indicates wheither the artifact was code signed.
    public let signed: Bool

    public init(metadataInfo: [CollectSignaturesOptions.MetadataInfo], signed: Bool) {
      self.metadata = Dictionary(
        uniqueKeysWithValues: metadataInfo.map { ($0.key, $0.value) })
      self.signed = signed
    }

    private enum CodingKeys: String, CodingKey {
      case isSecureTimestamp, metadata, signed
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

    // First, get the signing information dictionary, ignoring validation.
    let infoDictionary = try self.signingInformation(secStaticCode: secStaticCode)

    // Per Apple documentation for SecCodeCopySigningInformation, an absent kSecCodeInfoIdentifier
    // key indicates that the object is unsigned. Return a simple dictionary indicating as much,
    // matching the output of xcodebuild as of Xcode 15.3.
    if infoDictionary[kSecCodeInfoIdentifier as String] == nil {
      return SignatureInfo(metadataInfo: metadataInfo, signed: false)
    }

    // TODO(b/326280185): If the object is signed, convert the signing information dictionary into
    // an encodable XML plist-safe form, with Data objects instead of custom Core Foundation or
    // Security structures and types.

    return SignatureInfo(metadataInfo: metadataInfo, signed: true)
  }

}
