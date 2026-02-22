@testable import simulator_manager
import XCTest

final class SimulatorManagerTests: XCTestCase {
  func test_lease_release_lease() async throws {
    let mockSimulatorControl = MockSimulatorControl()
    let simulatorManager = SimulatorManager(
      simulatorControl: mockSimulatorControl,
      deleteRecentlyUsedIdleAfter: 0,
      deleteIdleAfter: 0,
      recentlyUsedCapacity: 1,
      deleteOnPIDExit: false
    )
    let leaser: PID = 1234
    let config = SimulatorConfig(deviceType: "iPhone 14", os: "iOS", version: "16.4")

    let simulator1 =
      try await simulatorManager
        .lease(to: leaser, exclusive: false, config: config)
    let maybeBaseSimulators1 = await mockSimulatorControl.baseSimulators[config]
    let baseSimulators1 = try XCTUnwrap(maybeBaseSimulators1)
    XCTAssert(baseSimulators1.count == 1)
    let baseSimulator1 = baseSimulators1[0]
    let maybeBaseForClone = await mockSimulatorControl.baseForClones[simulator1]
    let baseForClone = try XCTUnwrap(maybeBaseForClone)

    try await simulatorManager.release(for: leaser)
    let maybeBaseSimulators2 = await mockSimulatorControl.baseSimulators[config]
    let baseSimulators2 = try XCTUnwrap(maybeBaseSimulators2)
    XCTAssert(baseSimulators2.count == 1)
    let baseSimulator2 = baseSimulators2[0]

    let simulator2 =
      try await simulatorManager
        .lease(to: leaser, exclusive: false, config: config)
    let maybeBaseSimulators3 = await mockSimulatorControl.baseSimulators[config]
    let baseSimulators3 = try XCTUnwrap(maybeBaseSimulators3)
    XCTAssert(baseSimulators3.count == 2)
    let baseSimulator3 = baseSimulators3[1]

    // Simulator is a clone (not the same as base)
    XCTAssertNotEqual(simulator1, baseSimulator1)
    XCTAssertEqual(baseForClone, baseSimulator1)

    // Even with reuse, after last use of a simulator it's deleted
    XCTAssertNotEqual(simulator1, simulator2)

    XCTAssertEqual(baseSimulator1, baseSimulator2)

    // We don't cache our clones
    XCTAssertNotEqual(baseSimulator2, baseSimulator3)
  }

  func test_lease_reuse() async throws {
    let mockSimulatorControl = MockSimulatorControl()
    let simulatorManager = SimulatorManager(
      simulatorControl: mockSimulatorControl,
      deleteRecentlyUsedIdleAfter: 0,
      deleteIdleAfter: 0,
      recentlyUsedCapacity: 1,
      deleteOnPIDExit: false
    )
    let leaser1: PID = 1234
    let leaser2: PID = 1235
    let config = SimulatorConfig(deviceType: "iPhone 14", os: "iOS", version: "16.4")

    let simulator1 =
      try await simulatorManager
        .lease(to: leaser1, exclusive: false, config: config)
    let simulator2 =
      try await simulatorManager
        .lease(to: leaser2, exclusive: false, config: config)

    XCTAssertEqual(simulator1, simulator2)
  }

  func test_lease_exclusive() async throws {
    let mockSimulatorControl = MockSimulatorControl()
    let simulatorManager = SimulatorManager(
      simulatorControl: mockSimulatorControl,
      deleteRecentlyUsedIdleAfter: 0,
      deleteIdleAfter: 0,
      recentlyUsedCapacity: 1,
      deleteOnPIDExit: false
    )
    let leaser1: PID = 1234
    let leaser2: PID = 1235
    let config = SimulatorConfig(deviceType: "iPhone 14", os: "iOS", version: "16.4")

    let simulator1 =
      try await simulatorManager
        .lease(to: leaser1, exclusive: true, config: config)
    let simulator2 =
      try await simulatorManager
        .lease(to: leaser2, exclusive: true, config: config)

    XCTAssertNotEqual(simulator1, simulator2)
  }

  func test_lease_twice() async throws {
    let mockSimulatorControl = MockSimulatorControl()
    let simulatorManager = SimulatorManager(
      simulatorControl: mockSimulatorControl,
      deleteRecentlyUsedIdleAfter: 0,
      deleteIdleAfter: 0,
      recentlyUsedCapacity: 1,
      deleteOnPIDExit: false
    )
    let leaser: PID = 1234
    let config = SimulatorConfig(deviceType: "iPhone 14", os: "iOS", version: "16.4")

    _ =
      try await simulatorManager
        .lease(to: leaser, exclusive: true, config: config)

    // swiftformat:disable:next hoistAwait
    try await assertThrowsAsyncError(
      await simulatorManager
        .lease(to: leaser, exclusive: true, config: config)
    )
  }

  func test_release_alone() async throws {
    let mockSimulatorControl = MockSimulatorControl()
    let simulatorManager = SimulatorManager(
      simulatorControl: mockSimulatorControl,
      deleteRecentlyUsedIdleAfter: 0,
      deleteIdleAfter: 0,
      recentlyUsedCapacity: 1,
      deleteOnPIDExit: false
    )
    let leaser: PID = 1234

    // swiftformat:disable:next hoistAwait
    try await assertThrowsAsyncError(await simulatorManager.release(for: leaser))
  }
}

func assertThrowsAsyncError(
  _ expression: @autoclosure () async throws -> some Any,
  _ message: @autoclosure () -> String = "",
  file: StaticString = #filePath,
  line: UInt = #line,
  _ errorHandler: (_ error: Error) -> Void = { _ in }
) async {
  do {
    _ = try await expression()
    // expected error to be thrown, but it was not
    let customMessage = message()
    if customMessage.isEmpty {
      XCTFail("Asynchronous call did not throw an error.", file: file, line: line)
    } else {
      XCTFail(customMessage, file: file, line: line)
    }
  } catch {
    errorHandler(error)
  }
}

actor MockSimulatorControl: SimulatorControl {
  var baseSimulators: [SimulatorConfig: [SimulatorUDID]] = [:]
  var baseForClones: [SimulatorUDID: SimulatorUDID] = [:]

  func createBase(
    name: String,
    with config: SimulatorConfig,
    runtimeIdentifier: String
  ) async throws -> SimulatorUDID {
    let simulator = UUID().uuidString
    baseSimulators[config, default: []].append(simulator)
    return simulator
  }

  func clone(
    _ simulator: SimulatorUDID,
    name: String,
    deviceType: String,
    runtimeIdentifier: String,
    postBoot: String?
  ) async throws -> SimulatorUDID {
    let clone = UUID().uuidString
    baseForClones[clone] = simulator
    return clone
  }

  func ensureBooted(
    _ simulator: SimulatorUDID,
    context: @escaping @autoclosure () -> String?
  ) async throws {
    return
  }

  func cleanTempFiles(in simulator: SimulatorUDID) {
    return
  }

  func delete(
    _ simulator: SimulatorUDID,
    name: String,
    context: @escaping @autoclosure () -> String?
  ) async throws {
    return
  }

  func getExisting(
    name: String,
    deviceType: String,
    runtimeIdentifier: String,
    context: @escaping @autoclosure () -> String?
  ) async throws -> String? {
    return nil
  }
}
