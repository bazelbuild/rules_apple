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

/// Structure to validate that the library identifier that was inferred at analysis time matches
/// what the root Info.plist in the XCFramework bundle describes.
public struct ValidateLibraryIdentifier {

  /// The architecture that we are looking for (e.g. x84_64, arm64).
  public var architecture: String

  /// The bundle name of the XCFramework itself.
  public var bundleName: String

  /// The target Apple environment (e.g. device, simulator).
  public var environment: String

  /// The path to the XCFramework root Info.plist.
  public var libraryIdentifier: String

  /// The platform that we are looking for (e.g. ios, macos).
  public var platform: String

  /// The path to the XCFramework root Info.plist.
  public var rootInfoPlist: URL

  /// Errors that may occur during validation.
  public enum Error: Swift.Error, CustomStringConvertible {

    /// Indicates if the decoded root Info.plist was not in the expected format.
    case unexpectedPropertyList(plistURL: URL)

    /// Indicates if the decoded root Info.plist is not an XCFramework root Info.plist.
    case unexpectedPropertyListContents(
      plistURL: URL, plistKey: String, plistDictionary: [String: AnyObject])

    /// Indicates if unexpected values were found for an AvailableLibraries entry in the Info.plist.
    case unexpectedAvailableLibraryContents(
      plistURL: URL, plistKey: String, availableLibrariesDictionary: [String: AnyObject],
      libraryIndex: Int)

    /// Indicates if the target platform is not supported as indicated by the root Info.plist.
    case unsupportedPlatform(
      plistURL: URL, platform: String, architecture: String, environment: String,
      availableLibraries: [[String: AnyObject]])

    /// Indicates if the library identifier determined at analysis does not match the Info.plist.
    case libraryIdentifierNotFound(
      plistURL: URL, bundleName: String, expectedLibraryIdentifier: String,
      actualLibraryIdentifier: String)

    public var description: String {
      switch self {
      case .unexpectedPropertyList(let plistURL):
        return "The root Info.plist file at \(plistURL) does not appear to be a valid plist."
      case .unexpectedPropertyListContents(let plistURL, let plistKey, let plistDictionary):
        return """
          Info.plist file at \(plistURL) has an unexpected value for key \"\(plistKey)\".

          Contents are as follows:
          \(plistDictionary as AnyObject)

          Is it an XCFramework Info.plist file?
          """
      case .unexpectedAvailableLibraryContents(
        let plistURL, let plistKey, let availableLibrariesDictionary, let libraryIndex):
        return """
          Info.plist file at \(plistURL) has an unexpected value for key \"\(plistKey)\" in the \
          instance of \"AvailableLibraries\" at index \(libraryIndex):

          Full instance of \"AvailableLibraries\" at index \(libraryIndex) is as follows:
          \(availableLibrariesDictionary as AnyObject)

          Check that the library described is valid, and file an issue with the Apple BUILD rules \
          if it appears to be.
          """
      case .unsupportedPlatform(
        let plistURL, let platform, let architecture, let environment, let availableLibraries):
        return """
          The Info.plist file at \(plistURL) indicates that the XCFramework does not support the \
          given target configuration:

          - platform: \(platform)
          - architecture: \(architecture)
          - environment: \(environment)

          Available libraries are as follows:
          \(availableLibraries as AnyObject)
          """
      case .libraryIdentifierNotFound(
        let plistURL, let bundleName, let expectedLibraryIdentifier, let actualLibraryIdentifier):
        return """
          The assumed library identifier for XCFramework \"\(bundleName)\" of \
          \"\(expectedLibraryIdentifier)\" does not match the actual library identifier of \
          \"\(actualLibraryIdentifier)\" found within the Info.plist file at \(plistURL).

          Please file a bug against the Apple BUILD Rules.
          """
      }
    }
  }

  public init(
    architecture: String, bundleName: String, environment: String, libraryIdentifier: String,
    platform: String, rootInfoPlist: URL
  ) {
    self.architecture = architecture
    self.bundleName = bundleName
    self.environment = environment
    self.libraryIdentifier = libraryIdentifier
    self.platform = platform
    self.rootInfoPlist = rootInfoPlist
  }

  /// Returns the library identifier that matches the required configuration from the set of
  /// libraries described in the XCFramework's root Info.plist.
  private func findAvailableLibraryIdentifier(
    availableLibraries: [[String: AnyObject]]
  ) throws -> String {
    for (libraryIndex, library) in availableLibraries.enumerated() {

      let libraryIdentifierKey = "LibraryIdentifier"
      guard let libraryIdentifier = library[libraryIdentifierKey] as? String else {
        throw Error.unexpectedAvailableLibraryContents(
          plistURL: self.rootInfoPlist,
          plistKey: libraryIdentifierKey,
          availableLibrariesDictionary: library,
          libraryIndex: libraryIndex)
      }

      let supportedPlatformKey = "SupportedPlatform"
      guard let supportedPlatform = library[supportedPlatformKey] as? String else {
        throw Error.unexpectedAvailableLibraryContents(
          plistURL: self.rootInfoPlist,
          plistKey: supportedPlatformKey,
          availableLibrariesDictionary: library,
          libraryIndex: libraryIndex)
      }

      if self.platform != supportedPlatform {
        continue
      }

      let supportedArchitecturesKey = "SupportedArchitectures"
      guard let supportedArchitectures = library[supportedArchitecturesKey] as? [String] else {
        throw Error.unexpectedAvailableLibraryContents(
          plistURL: self.rootInfoPlist,
          plistKey: supportedArchitecturesKey,
          availableLibrariesDictionary: library,
          libraryIndex: libraryIndex)
      }

      if !supportedArchitectures.contains(self.architecture) {
        continue
      }

      // The environment key is optional; treat it as such.
      let supportedEnvironmentKey = "SupportedPlatformVariant"
      if library[supportedEnvironmentKey] != nil {
        guard let supportedEnvironment = library[supportedEnvironmentKey] as? String else {
          throw Error.unexpectedAvailableLibraryContents(
            plistURL: self.rootInfoPlist,
            plistKey: supportedEnvironmentKey,
            availableLibrariesDictionary: library,
            libraryIndex: libraryIndex)
        }

        // If we're looking for a "device" environment, no SupportedPlatformVariant key will be
        // supplied by this particular instance of "AvailableLibraries".
        if self.environment != "device" && self.environment != supportedEnvironment {
          continue
        } else if self.environment == "device" {
          continue
        }
      }

      return libraryIdentifier
    }

    throw Error.unsupportedPlatform(
      plistURL: self.rootInfoPlist, platform: self.platform, architecture: self.architecture,
      environment: self.environment, availableLibraries: availableLibraries)
  }

  /// Validates that the root Info.plist for the given XCFramework follows the expected form, and
  /// that it contains
  public func validate() throws {
    let rootInfoPlistData = try Data(contentsOf: self.rootInfoPlist)

    guard
      let rootInfoPlistContents = try? PropertyListSerialization.propertyList(
        from: rootInfoPlistData, options: PropertyListSerialization.ReadOptions(), format: nil),
      let plistDictionary = rootInfoPlistContents as? [String: AnyObject]
    else {
      throw Error.unexpectedPropertyList(plistURL: self.rootInfoPlist)
    }

    let versionKey = "XCFrameworkFormatVersion"
    guard plistDictionary[versionKey] is String else {
      throw Error.unexpectedPropertyListContents(
        plistURL: self.rootInfoPlist,
        plistKey: versionKey,
        plistDictionary: plistDictionary)
    }

    let bundlePackageTypeKey = "CFBundlePackageType"
    guard let bundlePackageType = plistDictionary[bundlePackageTypeKey] as? String,
      bundlePackageType == "XFWK"
    else {
      throw Error.unexpectedPropertyListContents(
        plistURL: self.rootInfoPlist,
        plistKey: bundlePackageTypeKey,
        plistDictionary: plistDictionary)
    }

    let availableLibrariesKey = "AvailableLibraries"
    guard let availableLibraries = plistDictionary[availableLibrariesKey] as? [[String: AnyObject]]
    else {
      throw Error.unexpectedPropertyListContents(
        plistURL: self.rootInfoPlist,
        plistKey: availableLibrariesKey,
        plistDictionary: plistDictionary)
    }

    let libraryIdentifier = try findAvailableLibraryIdentifier(
      availableLibraries: availableLibraries)
    guard libraryIdentifier == self.libraryIdentifier else {
      throw Error.libraryIdentifierNotFound(
        plistURL: self.rootInfoPlist,
        bundleName: self.bundleName,
        expectedLibraryIdentifier: self.libraryIdentifier,
        actualLibraryIdentifier: libraryIdentifier)
    }
  }

}
