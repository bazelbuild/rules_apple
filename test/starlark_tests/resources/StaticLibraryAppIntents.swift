// Copyright 2025 The Bazel Authors. All rights reserved.
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

public struct OrderSoupIntent: AppIntent {
  public static var title = LocalizedStringResource("Order Soup")
  public static var description = IntentDescription("Orders a soup from your favorite restaurant.")

  @Parameter(title: "Quantity")
  var quantity: Int?

  public init() {}

  public static var parameterSummary: some ParameterSummary {
    Summary("Order \(\.$quantity)") {
      \.$quantity
    }
  }

  public func perform() async throws -> some IntentResult {
    return .result()
  }
}
