// Copyright 2023 The Bazel Authors. All rights reserved.
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

import AppIntents

public enum RefreshInterval: String, AppEnum {
  case hourly, daily, weekly

  public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Refresh Interval"
  public static let caseDisplayRepresentations: [RefreshInterval: DisplayRepresentation] = [
    .hourly: "Every Hour",
    .daily: "Every Day",
    .weekly: "Every Week",
  ]
}

public struct FavoriteSoup: WidgetConfigurationIntent, AppIntentsPackage {
  public static let title: LocalizedStringResource = "Favorite Soup"
  static let description = IntentDescription("Shows a picture of your favorite soup!")

  @Parameter(title: "Soup")
  public var name: String?

  @Parameter(title: "Shuffle", default: true)
  public var shuffle: Bool

  @Parameter(title: "Refresh", default: .daily)
  public var interval: RefreshInterval

  public init() {}

  public func perform() async throws -> some IntentResult & ProvidesDialog {
    return .result(dialog: "This is an intent with a computed property!")
  }
}
