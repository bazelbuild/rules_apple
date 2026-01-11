import Foundation
import os.log
import ShellOut

typealias SimulatorUDID = String

extension Logger {
  static let simulatorControl = simulatorManager(category: "control")
}

struct SimulatorConfig: Hashable, Equatable {
  let deviceType: String
  let os: String
  let version: String
}

extension SimulatorConfig: CustomStringConvertible {
  var description: String {
    return "\(deviceType) (\(os) \(version))"
  }
}

struct SimCtlDevices: Decodable {
  let devices: [String: [SimCtlDevice]]
}

struct SimCtlDevice: Decodable {
  let name: String
  let udid: String
}

struct ProcessError: Error {
  let command: String
  let context: String?
  let exitCode: Int32
  let stdOut: String
  let stdErr: String
}

extension ProcessError: CustomStringConvertible {
  var description: String {
    let contextStr: String
    if let context {
      contextStr = " (\(context))"
    } else {
      contextStr = ""
    }

    return """
    "\(command)"\(contextStr) failed with exit code \(exitCode):
    \(stdOut)\(stdErr)
    """
  }
}

extension ProcessError: LocalizedError {
  var errorDescription: String? {
    return description
  }
}

protocol SimulatorControl: Actor {
  // Creates a base simulator with the given config.
  //
  // It also boots and shuts down the simulator, making it ready for cloning.
  //
  // If an existing simulator with the same name already exists, that is returned instead of
  // creating a new one. This is to support the simulator manager being restarted and losing state.
  func createBase(
    name: String,
    with config: SimulatorConfig,
    runtimeIdentifier: String
  ) async throws -> SimulatorUDID

  // Clones a base simulator.
  //
  // It also boots the cloned simulator, making it ready for use.
  //
  // If an existing simulator with the same name already exists, that is returned instead of
  // creating a new one. This is to support the simulator manager being restarted and losing state.
  func clone(
    _ baseSimulator: SimulatorUDID,
    name: String,
    deviceType: String,
    runtimeIdentifier: String,
    postBoot: String?
  ) async throws -> SimulatorUDID

  func ensureBooted(
    _ simulator: SimulatorUDID,
    context: @escaping @autoclosure () -> String?
  ) async throws

  func cleanTempFiles(in simulator: SimulatorUDID)

  func delete(
    _ simulator: SimulatorUDID,
    name: String,
    context: @escaping @autoclosure () -> String?
  ) async throws

  func getExisting(
    name: String,
    deviceType: String,
    runtimeIdentifier: String,
    context: @escaping @autoclosure () -> String?
  ) async throws -> String?
}

actor RealSimulatorControl: SimulatorControl {
  private var createBaseTasks: [String: Task<SimulatorUDID, Error>] = [:]
  private var cloneTasks: [String: Task<SimulatorUDID, Error>] = [:]

  private var deleteAndExistenceMutexes: [String: (SimulatorDeleteOrExistenceMutex, Int)] = [:]

  func createBase(
    name: String,
    with config: SimulatorConfig,
    runtimeIdentifier: String
  ) async throws -> SimulatorUDID {
    if let existingTask = createBaseTasks[name] {
      return try await existingTask.value
    }

    // We use a task to prevent data races that can occur when the `await` on `simctl` blocks. This
    // ensures that multiple callers trying create a base simulator will all wait for the same
    // simulator to be returned.
    let task = Task<SimulatorUDID, Error> {
      defer {
        createBaseTasks.removeValue(forKey: name)
      }

      if let existingUDID = try await getExisting(
        name: name,
        deviceType: config.deviceType,
        runtimeIdentifier: runtimeIdentifier,
        context: "createBase"
      ) {
        Logger.simulatorControl.info(
          """
          📱 Base simulator "\(name, privacy: .public)" already exists, skipping creation: \
          \(existingUDID, privacy: .public)
          """
        )

        do {
          // Under weird circumstances, the base simulator might be booted. This could happen if
          // the simulator manager is killed in the process of creating a new base. Always call
          // shutdown just in case.
          try await shutdown(existingUDID, context: "createBase existing: \(name)")
        } catch {
          // If we fail to do what we need to, then we need to delete the faulty base simulator
          Logger.simulatorControl.error(
            """
            📱 Failed to set up base simulator "\(name)" \(existingUDID, privacy: .public); deleting
            """
          )

          // If we fail to delete, don't throw _that_ error, throw the original error
          try? await delete(existingUDID, name: name, context: "createBase existing: \(name)")

          throw error
        }

        return existingUDID
      }

      Logger.simulatorControl.info(
        #"📱 Creating \#(config, privacy: .public) base simulator "\#(name, privacy: .public)""#
      )

      let udid = try await simctl(
        ["create", name, config.deviceType, runtimeIdentifier]
      ).trimmingCharacters(in: .whitespacesAndNewlines)

      do {
        try await ensureBooted(udid, context: "createBase new: \(name)")

        // FIXME: Find a better way to know the simulator is ready
        // Give the simulator some time to do some post-boot processing
        try await Task.sleep(for: .seconds(5))

        try await shutdown(udid, context: "createBase new: \(name)")
      } catch {
        // If we fail to do what we need to, then we need to delete the faulty base simulator
        Logger.simulatorControl.error(
          #""📱 Failed to set up base simulator "\#(name)" \#(udid, privacy: .public); deleting"#
        )

        // If we fail to delete, don't throw _that_ error, throw the original error
        try? await delete(udid, name: name, context: "createBase new: \(name)")

        throw error
      }

      Logger.simulatorControl.info(
        """
        📱 Created \(config, privacy: .public) base simulator \
        "\(name, privacy: .public)": \(udid, privacy: .public)
        """
      )

      return udid
    }

    createBaseTasks[name] = task

    return try await task.value
  }

  func clone(
    _ baseSimulator: SimulatorUDID,
    name: String,
    deviceType: String,
    runtimeIdentifier: String,
    postBoot: String? = nil
  ) async throws -> SimulatorUDID {
    if let existingTask = cloneTasks[name] {
      return try await existingTask.value
    }

    // We use a task to prevent data races that can occur when the `await` on `simctl` blocks. This
    // ensures that multiple callers trying create a base simulator will all wait for the same
    // simulator to be returned.
    let task = Task<SimulatorUDID, Error> {
      defer {
        cloneTasks.removeValue(forKey: name)
      }

      let udid: String
      let isExisting: Bool
      if let existingUDID = try await getExisting(
        name: name,
        deviceType: deviceType,
        runtimeIdentifier: runtimeIdentifier,
        context: "clone"
      ) {
        udid = existingUDID
        isExisting = true

        // An existing simulator can be found if a previous simulator manager was killed before the
        // clone was deleted. No tests _should_ be actively leasing the simulator.
        Logger.simulatorControl.info(
          """
          📱 Cloned simulator "\(name, privacy: .public)" already exists, skipping creation: \
          \(udid, privacy: .public)
          """
        )

        // Wait for it to boot. This shouldn't be necessary, but sometimes the simulator will
        // reboot because of a migration.
        try await ensureBooted(udid, context: "clone, existing: \(name)")
      } else {
        isExisting = false

        Logger.simulatorControl.info(
          """
          📱 Cloning base simulator \(baseSimulator, privacy: .public) as \
          "\(name, privacy: .public)"
          """
        )

        udid = try await simctl(
          ["clone", baseSimulator, name]
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        Logger.simulatorControl.info(
          """
          📱 Cloned base simulator \(baseSimulator, privacy: .public) as \
          "\(name, privacy: .public)": \(udid, privacy: .public)
          """
        )

        try await ensureBooted(udid, context: "clone, new: \(name)")
      }

      if let postBoot {
        Logger.simulatorControl.info(
          """
          📱 Running post-boot script "\(postBoot, privacy: .public)" on \
          \(udid, privacy: .public)
          """
        )

        do {
          _ = try await subprocess(postBoot, env: ["SIMULATOR_UDID": udid])
        } catch {
          throw NSError(
            domain: "SimulatorControl",
            code: 1,
            userInfo:
            [NSLocalizedDescriptionKey: "postBoot failed (isExisting: \(isExisting)): \(error)"]
          )
        }
      }

      return udid
    }

    cloneTasks[name] = task

    return try await task.value
  }

  func shutdown(_ simulator: SimulatorUDID, context: @escaping @autoclosure () -> String?) async throws {
    do {
      _ = try await simctl(["shutdown", simulator], context: context())
    } catch let error as ProcessError {
      // Exit code 149 is related to the simulator already being shut down
      guard error.exitCode == 149 else {
        throw error
      }

      Logger.simulatorControl.warning(
        """
        ⚠️ Shutdown failed, but probably \"already shut down\": \(error, privacy: .public)
        """
      )
    }
  }

  func cleanTempFiles(in simulator: SimulatorUDID) {
    let fileManager = FileManager.default

    // Remove all files and directories under
    // `data/Library/Caches/com.apple.containermanagerd/Dead/`, ignoring errors. There seems to be
    // a bug where the simulator moves files here but never cleans them up. Maybe it's waiting for
    // a reboot or something, which we never do.
    let deadCachesPath =
      "\(NSHomeDirectory())/Library/Developer/CoreSimulator/Devices/\(simulator)/data/Library/Caches/com.apple.containermanagerd/Dead"
    guard let contents = try? fileManager.contentsOfDirectory(atPath: deadCachesPath) else {
      return
    }
    for item in contents {
      let itemPath = "\(deadCachesPath)/\(item)"
      try? fileManager.removeItem(atPath: itemPath)
    }
  }

  func delete(
    _ simulator: SimulatorUDID,
    name: String,
    context: @escaping @autoclosure () -> String?
  ) async throws {
    try await deleteAndExistenceMutex(name: name) { mutex in
      try await mutex.unlockedDelete(simulator, context: context())
    }
  }

  func getExisting(
    name: String,
    deviceType: String,
    runtimeIdentifier: String,
    context: @escaping @autoclosure () -> String?
  ) async throws -> String? {
    return try await deleteAndExistenceMutex(name: name) { mutex in
      return try await mutex.unlockedGetExisting(
        name: name,
        deviceType: deviceType,
        runtimeIdentifier: runtimeIdentifier,
        context: context()
      )
    }
  }

  func ensureBooted(_ simulator: SimulatorUDID, context: @escaping @autoclosure () -> String?) async throws {
    for retriesLeft in (0...1).reversed() {
      do {
        // This private command boots the simulator if it isn't already, and waits for the
        // appropriate amount of time until we can actually run tests
        _ = try await simctl(["bootstatus", simulator, "-b"], context: context())
        break
      } catch let error as ProcessError {
        // Exit code 149 is related to the simulator already being booted
        guard error.exitCode == 149 && retriesLeft > 0 else {
          throw error
        }

        // This is a known error that happens when the simulator is already booted. A retry
        // should succeed.
        Logger.simulatorControl.warning(
          """
          ⚠️ Boot of simulator \(simulator, privacy: .public) failed, but probably \"already \
          booted\": \(error, privacy: .public)
          """
        )
      }
    }
  }

  private func deleteAndExistenceMutex<T>(
    name: String,
    _ call: (_ mutex: SimulatorDeleteOrExistenceMutex) async throws -> T
  ) async throws -> T {
    var (mutex, referenceCount) =
      deleteAndExistenceMutexes[name] ?? (SimulatorDeleteOrExistenceMutex(), 0)
    referenceCount += 1
    deleteAndExistenceMutexes[name] = (mutex, referenceCount)

    defer {
      guard let mutexAndRef = deleteAndExistenceMutexes[name] else {
        preconditionFailure(
          """
          State of `deleteAndExistenceMutexes` changed unexpectedly. Expected value for "\(name)".
          """
        )
      }
      let mutex = mutexAndRef.0
      var referenceCount = mutexAndRef.1
      referenceCount -= 1

      if referenceCount == 0 {
        deleteAndExistenceMutexes.removeValue(forKey: name)
      } else {
        deleteAndExistenceMutexes[name] = (mutex, referenceCount)
      }
    }

    return try await mutex.withLock {
      try await call(mutex)
    }
  }
}

// An instance of this actor is created for each simulator name that is being checked for existence
// or being deleted. The actor is only called through `withLock()`, which will suspend on multiple
// calls to ensure that these operations are serialized. Without this, someone could try to call
// `clone()` while a deletion is pending, which will call `getExisting()`, and it can return the
// simulator that is in the process of being deleted.
actor SimulatorDeleteOrExistenceMutex {
  private var isLocked = false
  private var waiters: [CheckedContinuation<Void, Never>] = []

  /// Acquires, runs the work, and then releases the lock.
  func withLock<T>(_ work: () async throws -> T) async throws -> T {
    await lock()
    defer { unlock() }
    return try await work()
  }

  /// Acquires the lock. If already locked, will suspend until unlocked.
  private func lock() async {
    if !isLocked {
      isLocked = true
    } else {
      await withCheckedContinuation { cont in
        waiters.append(cont)
      }
    }
  }

  /// Releases the lock and wakes one waiter (if any).
  private func unlock() {
    if !waiters.isEmpty {
      let cont = waiters.removeFirst()
      cont.resume()
    } else {
      isLocked = false
    }
  }

  func unlockedGetExisting(
    name: String,
    deviceType: String,
    runtimeIdentifier: String,
    context: @escaping @autoclosure () -> String?
  ) async throws -> String? {
    Logger.simulatorControl.debug(
      #"🔍 Trying to find existing simulator "\#(name, privacy: .public)""#
    )

    let output = try await simctl(["list", "devices", "-j", deviceType], context: context())

    guard let jsonData = output.data(using: .utf8) else {
      throw NSError(
        domain: "SimulatorControl",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Failed to convert output to data"]
      )
    }

    let jsonDecoder = JSONDecoder()

    let devicesByRuntime: [String: [SimCtlDevice]]
    do {
      devicesByRuntime = try jsonDecoder.decode(SimCtlDevices.self, from: jsonData).devices
    } catch {
      let json = String(data: jsonData, encoding: .utf8) ?? "<invalid utf8>"
      Logger.simulatorControl.error(
        """
        ❌ Failed to decode 'simctl list devices -j': \(error, privacy: .public).
        Output: \(json, privacy: .public)
        """
      )
      throw NSError(
        domain: "SimulatorControl",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Failed to decode output: \(error) - \(json)"]
      )
    }

    if let devices = devicesByRuntime[runtimeIdentifier] {
      for device in devices {
        if device.name == name {
          let udid = device.udid

          Logger.simulatorControl.debug(
            #"🔍 Found existing simulator "\#(name, privacy: .public)": \#(udid, privacy: .public)"#
          )

          // Sometimes the simulator is not actually on disk, but it is in the list. If this
          // happens, "delete" it so simctl stops reporting it as existing.
          if !FileManager.default.fileExists(
            atPath:
            "\(NSHomeDirectory())/Library/Developer/CoreSimulator/Devices/\(udid)"
          ) {
            Logger.simulatorControl.debug(
              """
              ⚠️ Simulator \(udid, privacy: .public) doesn't actually exist on disk; "deleting"
              """
            )

            // If we fail to delete, don't throw an error
            try? await unlockedDelete(udid, context: context())

            return nil
          }

          return udid
        }
      }
    }

    Logger.simulatorControl.debug(
      #"🔍 No existing simulator "\#(name, privacy: .public)" found"#
    )

    return nil
  }

  func unlockedDelete(
    _ simulator: SimulatorUDID,
    context: @escaping @autoclosure () -> String?
  ) async throws {
    Logger.simulatorControl.info("🗑️ Deleting simulator \(simulator, privacy: .public)")

    do {
      _ = try await simctl(["delete", simulator], context: context())
    } catch {
      Logger.simulatorControl.error(
        """
        ❌ Failed to delete simulator \(simulator, privacy: .public): \
        \(error, privacy: .public)
        """
      )

      throw error
    }

    Logger.simulatorControl.info("🗑️ Deleted simulator \(simulator, privacy: .public)")
  }
}

private func simctl(
  _ args: [String],
  context: @escaping @autoclosure () -> String? = nil
) async throws -> String {
  return try await subprocess("/usr/bin/xcrun", ["simctl"] + args, context: context())
}

private func subprocess(
  _ executable: String,
  _ args: [String] = [],
  env: [String: String] = [:],
  context: @escaping @autoclosure () -> String? = nil
) async throws -> String {
  return try await Task { try syncSubprocess(executable, args, env: env, context: context()) }.value
}

private func syncSubprocess(
  _ executable: String,
  _ args: [String] = [],
  env: [String: String] = [:],
  context: @escaping @autoclosure () -> String? = nil
) throws -> String {
  let quotedArgs = args.map { "'\($0)'" }

  var newEnv = ProcessInfo.processInfo.environment.merging(env) { _, new in new }
  newEnv["PWD"] = FileManager.default.currentDirectoryPath

  let process = Process()
  process.environment = ProcessInfo.processInfo.environment.merging(env) { _, new in new }

  let command = "\(executable) \(quotedArgs.joined(separator: " "))"

  Logger.simulatorControl.debug(#"🛠️ Running "\#(command, privacy: .public)""#)

  do {
    return try shellOut(
      to: executable,
      arguments: quotedArgs,
      process: process
    )
  } catch let error as ShellOutError {
    throw ProcessError(
      command: command,
      context: context(),
      exitCode: error.terminationStatus,
      stdOut: error.output,
      stdErr: error.message
    )
  }
}

extension SimulatorConfig {
  func baseDeviceName() -> String {
    return "EXAMPLE_BAZEL_BASE_\(deviceType)_\(version)"
  }

  func cloneDeviceName(index: Int) -> String {
    return "EXAMPLE_BAZEL_CLONE_\(deviceType)_\(version)_\(index)"
  }

  func runtimeIdentifier() -> String {
    let runtimeVersion = version.replacingOccurrences(of: ".", with: "-")
    return "com.apple.CoreSimulator.SimRuntime.\(os)-\(runtimeVersion)"
  }
}
