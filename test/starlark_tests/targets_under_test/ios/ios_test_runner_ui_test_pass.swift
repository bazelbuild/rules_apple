// Copyright 2026 The Bazel Authors. All rights reserved.
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

import XCTest

private final class PassingUiTestObservation: NSObject, XCTestObservation {
  private static let expectedTestNamesEnvKey = "EXPECTED_UI_TEST_NAMES"

  private let expectedTestNames: Set<String>
  private var finishedTestNames = Set<String>()
  private(set) var startedTestNames = Set<String>()

  init(expectedTestNames: Set<String>) {
    self.expectedTestNames = expectedTestNames
  }

  func testCaseWillStart(_ testCase: XCTestCase) {
    startedTestNames.insert(Self.normalizedTestName(testCase.name))
  }

  func testCaseDidFinish(_ testCase: XCTestCase) {
    finishedTestNames.insert(Self.normalizedTestName(testCase.name))
  }

  func testBundleDidFinish(_ testBundle: Bundle) {
    let missingTestNames = expectedTestNames.subtracting(finishedTestNames)
    let unexpectedTestNames = finishedTestNames.subtracting(expectedTestNames)
    guard missingTestNames.isEmpty && unexpectedTestNames.isEmpty else {
      fatalError(
        "Expected tests \(expectedTestNames.sorted()) to run, but \(finishedTestNames.sorted()) " +
          "ran. Missing: \(missingTestNames.sorted()). Unexpected: \(unexpectedTestNames.sorted())"
      )
    }
  }

  static func expectedTestNamesFromEnvironment() -> Set<String> {
    let environment = ProcessInfo.processInfo.environment
    guard let expectedTestNames = environment[expectedTestNamesEnvKey] else {
      fatalError("Missing \(expectedTestNamesEnvKey) environment variable")
    }

    let names = expectedTestNames
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    guard !names.isEmpty else {
      fatalError("\(expectedTestNamesEnvKey) environment variable must contain at least one test")
    }

    return Set(names)
  }

  static func normalizedTestName(_ testName: String) -> String {
    if testName.hasSuffix("]"), let lastSpace = testName.lastIndex(of: " ") {
      let methodNameRange = testName.index(after: lastSpace)..<testName.index(before: testName.endIndex)
      return String(testName[methodNameRange])
    }

    if let slash = testName.lastIndex(of: "/") {
      return String(testName[testName.index(after: slash)...])
    }

    if let dot = testName.lastIndex(of: ".") {
      return String(testName[testName.index(after: dot)...])
    }

    return testName
  }
}

@objc(PassingUiTest)
final class PassingUiTest: XCTestCase {
  private static let observation = PassingUiTestObservation(
    expectedTestNames: PassingUiTestObservation.expectedTestNamesFromEnvironment()
  )

  override class func setUp() {
    super.setUp()
    XCTestObservationCenter.shared.addTestObserver(observation)
  }

  override func setUp() {
    super.setUp()
    continueAfterFailure = false
    XCUIApplication().launch()
  }

  func testPass() {
    assertObservationStartedCurrentTest()
    XCTAssertEqual(1, 1, "should pass")
  }

  func testPass2() {
    assertObservationStartedCurrentTest()
    XCTAssertEqual(1, 1, "should pass")
  }

  func testEnv() {
    assertObservationStartedCurrentTest()
    let varValue = ProcessInfo.processInfo.environment["ENV_KEY1"]
    XCTAssertEqual(
      varValue,
      "ENV_VALUE2",
      "env ENV_KEY1 should be ENV_VALUE2, instead is \(varValue ?? "nil")"
    )
  }

  private func assertObservationStartedCurrentTest() {
    XCTAssertTrue(
      Self.observation.startedTestNames.contains(PassingUiTestObservation.normalizedTestName(name))
    )
  }
}
