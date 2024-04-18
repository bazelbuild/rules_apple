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
import tools_signaturetool_collect_signatures_options
import tools_signaturetool_security_service_query
import tools_signaturetool_signature_xml_plist

/// Signature Tool invocation that composes the necessary set of options to generate a Signatures
/// XML plist file appropriate for bundling within an IPA or an xcarchive bundle.
public struct CollectSignatures: ParsableCommand {
  @OptionGroup
  private var sharedOptions: CollectSignaturesOptions

  public init() {}

  public func run() throws {
    let artifactToQuery = sharedOptions.signaturesInputPath
    let serviceQuery = SecurityServiceQuery(artifactToQuery: artifactToQuery)
    let signatureInfo = try serviceQuery.signatureInfo(metadataInfo: sharedOptions.metadataInfo)
    let signatureXMLPlist = try SignatureXMLPlist(signatureInfo: signatureInfo)
    try signatureXMLPlist.writeFile(outputPath: sharedOptions.signaturesOutputPath)
  }

}
