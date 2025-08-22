import Foundation
import os
import ShellOut

typealias PID = pid_t

extension Logger {
  static let simulatorManager = simulatorManager(category: "manager")
  static let childProcess = simulatorManager(category: "manager.child-process")
}

enum SimulatorManagerError: Error {
  case alreadyLeased(udid: SimulatorUDID)
  case noLease
}

private struct SimulatorLease {
  let udid: SimulatorUDID
  let config: SimulatorConfig
  let exclusive: Bool
  let slotIndex: Int
}

private enum SimulatorSlot {
  case empty
  case pendingCreation(Task<SimulatorUDID, Error>, exclusive: Bool)
  case active(SimulatorUDID, exclusive: Bool)
  case pendingDeletion(SimulatorUDID, Task<Void, Error>)
  case deleting(SimulatorUDID)
}

extension SimulatorSlot {
  var sortOrder: Int {
    switch self {
    // Try to use active or pending creation simulators first (should only be
    // one of either for non-exclusive)
    case .active:
      return 0
    case .pendingCreation:
      return 1

    // Use a pending deletion before any empty slots
    case .pendingDeletion:
      return 2

    // Finally use empty slots
    case .empty:
      return 3

    // Deleting simulator can't be used, so put it at the end
    case .deleting:
      return 4
    }
  }
}

private enum SimulatorSlotResult {
  case active(SimulatorUDID, slotIndex: Int)
  case pending(Task<SimulatorUDID, Error>, slotIndex: Int)
}

actor SimulatorManager {
  private let simulatorControl: SimulatorControl

  private var simulatorSlots: [SimulatorConfig: [SimulatorSlot]] = [:]
  private var referenceCount: [SimulatorUDID: Int] = [:]
  private var leases: [PID: SimulatorLease] = [:]

  private var leaserExitListeners: [PID: DispatchSourceProcess] = [:]

  private var getBaseSimulatorTasks: [SimulatorConfig: Task<SimulatorUDID, Error>] = [:]

  private let deleteIdleAfter: UInt16
  private let deleteRecentlyUsedIdleAfter: UInt16
  private let deleteOnPIDExit: Bool

  private var recentlyLeased: LRUSet<SimulatorConfig>

  private var startupProcessPaths: [String]
  private var postBoot: String?
  private var childProcessTasks: [Task<Void, Never>] = []
  private var childProcesses: [String: (Process, DispatchSourceRead, DispatchSourceRead)] = [:]

  init(
    simulatorControl: SimulatorControl,
    deleteRecentlyUsedIdleAfter: UInt16,
    deleteIdleAfter: UInt16,
    recentlyUsedCapacity: Int,
    deleteOnPIDExit: Bool,
    startupProcesses: [String] = [],
    postBoot: String? = nil
  ) {
    self.simulatorControl = simulatorControl
    self.deleteIdleAfter = deleteIdleAfter
    self.deleteRecentlyUsedIdleAfter = deleteRecentlyUsedIdleAfter
    self.deleteOnPIDExit = deleteOnPIDExit
    self.recentlyLeased = LRUSet(capacity: recentlyUsedCapacity)
    self.startupProcessPaths = startupProcesses
    self.postBoot = postBoot

    // Change the working directory to some place stable, since on RBE the runfiles directory can
    // get cleaned up
    FileManager.default.changeCurrentDirectoryPath("/tmp")
  }

  deinit {
    for task in childProcessTasks {
      task.cancel()
    }

    for (process, outWatcher, errWatcher) in childProcesses.values {
      process.terminate()
      outWatcher.cancel()
      errWatcher.cancel()
    }
  }

  func startChildProcesses() throws {
    for path in startupProcessPaths {
      childProcessTasks.append(createStartChildProcessTask(path: path))
    }
  }

  func lease(
    to leaser: PID,
    exclusive: Bool,
    config: SimulatorConfig
  ) async throws -> SimulatorUDID {
    // Each process can only lease one simulator at a time
    if let existingLease = leases[leaser] {
      throw SimulatorManagerError.alreadyLeased(udid: existingLease.udid)
    }

    Logger.simulatorManager.info(
      """
      🔒 Leasing \(exclusive ? "exclusive" : "non-exclusive", privacy: .public) \
      \(config, privacy: .public) simulator for PID \(leaser, privacy: .public)
      """
    )

    // `getSimulator()` will increment the reference count for the simulator
    let (simulator, slotIndex) = try await getSimulator(for: config, exclusive: exclusive)

    _ = recentlyLeased.insert(config)

    leases[leaser] = .init(
      udid: simulator,
      config: config,
      exclusive: exclusive,
      slotIndex: slotIndex
    )

    Logger.simulatorManager.info(
      "🔒 Leased simulator \(simulator, privacy: .public) to PID \(leaser, privacy: .public)"
    )

    if deleteOnPIDExit {
      registerReleaseOnExit(for: leaser)
    }

    return simulator
  }

  func release(for leaser: PID) async throws {
    guard let lease = leases.removeValue(forKey: leaser) else {
      // If the manager recently restarted, we might not have the state of all leases. Since
      // `SimulatorControl` will return existing simulators matching a given name, the dangling
      // simulator will eventually get picked back up again and properly reference counted. So we
      // will return an error here, and ignore it in the test runner.
      throw SimulatorManagerError.noLease
    }

    Logger.simulatorManager.info(
      "🔓 Releasing simulator \(lease.udid, privacy: .public) for PID \(leaser, privacy: .public)"
    )

    removeReleaseOnExit(for: leaser)

    await simulatorControl.cleanTempFiles(in: lease.udid)

    try await decrementReferenceCount(
      for: lease.udid,
      config: lease.config,
      slotIndex: lease.slotIndex
    )
  }

  private func getBase(
    for config: SimulatorConfig
  ) async throws -> SimulatorUDID {
    if let existingTask = getBaseSimulatorTasks[config] {
      return try await existingTask.value
    }

    // We use a task to prevent data races that can occur when the `await` on `simulatorControl`
    // blocks. This ensures that multiple callers trying to get a base simulator will all wait
    // for the same simulator to be returned.
    let task = Task<SimulatorUDID, Error> {
      defer {
        getBaseSimulatorTasks.removeValue(forKey: config)
      }

      Logger.simulatorManager.info("📱 Creating \(config, privacy: .public) base simulator")

      let baseSimulator =
        try await simulatorControl
          .createBase(
            name: config.baseDeviceName(),
            with: config,
            runtimeIdentifier: config.runtimeIdentifier()
          )

      Logger.simulatorManager.info(
        "📱 Created \(config, privacy: .public) base simulator: \(baseSimulator, privacy: .public)"
      )

      return baseSimulator
    }

    getBaseSimulatorTasks[config] = task

    return try await task.value
  }

  private func incrementReferenceCount(for simulator: SimulatorUDID) {
    var count = referenceCount[simulator] ?? 0
    count += 1
    referenceCount[simulator] = count

    Logger.simulatorManager.debug(
      """
      🔼 Reference count for simulator \(simulator, privacy: .public) is now \
      \(count, privacy: .public)
      """
    )
  }

  private func decrementReferenceCount(
    for simulator: SimulatorUDID,
    config: SimulatorConfig,
    slotIndex: Int
  ) async throws {
    guard var count = referenceCount[simulator] else {
      // Simulator was already deleted, nothing to do
      return
    }

    count -= 1
    referenceCount[simulator] = count

    Logger.simulatorManager.debug(
      "🔽 Reference count for \(simulator, privacy: .public) is now \(count, privacy: .public)"
    )

    guard count == 0 else {
      return
    }

    // Wait a bit before deleting simulators, to allow them to be reused
    await pendingDeletion(simulator, config: config, slotIndex: slotIndex)
  }

  // Warning: We must update slots before we `await` on anything in this function (unless that
  // method updates slots before `await`ing on anything).
  private func getSimulator(
    for config: SimulatorConfig,
    exclusive: Bool
  ) async throws -> (simulator: SimulatorUDID, slotIndex: Int) {
    if simulatorSlots.keys.contains(config) == false {
      simulatorSlots[config] = []
    }

    // Need to sort so we reuse the the correct slots
    let sortedSlots = simulatorSlots[config]!.enumerated().sorted { lhs, rhs in
      let lhsSortOrder = lhs.element.sortOrder
      let rhsSortOrder = rhs.element.sortOrder

      guard lhsSortOrder == rhsSortOrder else {
        // Sort by sort order first
        return lhsSortOrder < rhsSortOrder
      }

      // If the sort order is the same, sort by index
      return lhs.offset < rhs.offset
    }

    for (index, slot) in sortedSlots {
      switch slot {
      case .active(let simulator, false) where exclusive != true:
        // We have an active non-exclusive simulator, so reuse it
        return try await (
          reuseSimulator(simulator, config: config, exclusive: exclusive, slotIndex: index),
          slotIndex: index
        )

      case .pendingDeletion(let simulator, let task):
        // We have a pending deletion, so we can reuse it
        Logger.simulatorManager.info(
          """
          ♻️ Turning a pending deletion of simulator \(simulator, privacy: .public) into an \
          active \(exclusive ? "exclusive" : "non-exclusive", privacy: .public) simulator
          """
        )

        simulatorSlots[config]![index] = .active(simulator, exclusive: exclusive)

        task.cancel()

        return try await (
          reuseSimulator(simulator, config: config, exclusive: exclusive, slotIndex: index),
          slotIndex: index
        )

      case .empty:
        let task = createCloneTask(config: config, exclusive: exclusive, slotIndex: index)
        simulatorSlots[config]![index] = .pendingCreation(task, exclusive: exclusive)
        return try await (task.value, slotIndex: index)

      case .pendingCreation(let task, false) where exclusive == false:
        // We have a non-exclusive simulator pending creation, so reuse it
        let simulator = try await task.value

        // We call `incrementReferenceCount()` instead of `reuseSimulator()` here, because the
        // simulator is freshly created, so we can (hopefully) assume it is in a good state
        incrementReferenceCount(for: simulator)

        return (simulator, slotIndex: index)

      default:
        // Ignore incompatible slots
        break
      }
    }

    // If we got here, we need to add a new slot
    let index = simulatorSlots[config]!.count
    let task = createCloneTask(config: config, exclusive: exclusive, slotIndex: index)
    simulatorSlots[config]!.append(.pendingCreation(task, exclusive: exclusive))
    return try await (task.value, slotIndex: index)
  }

  private func reuseSimulator(
    _ simulator: SimulatorUDID,
    config: SimulatorConfig,
    exclusive: Bool,
    slotIndex: Int
  ) async throws -> SimulatorUDID {
    incrementReferenceCount(for: simulator)

    do {
      // Wait for it to boot. This shouldn't be necessary, but sometimes the simulator will
      // reboot because of a migration. This also guards against a simulator being deleted out
      // from under us, as it will error, and we can then "delete" it and return a new one.
      try await simulatorControl.ensureBooted(
        simulator,
        context: "getSimulator, reused: \(config.cloneDeviceName(index: slotIndex))"
      )

      return simulator
    } catch let error as ProcessError {
      // 148 happens for "Invalid device". So it either has already been deleted or it's corrupt
      // in some way. Either way, we will "delete" it and return a new one.
      guard error.exitCode == 148 else {
        throw error
      }

      Logger.simulatorManager.warning(
        """
        ⚠️ Boot of existing simulator \(simulator, privacy: .public) failed; deleting and \
        returning a new simulator: \(error, privacy: .public)
        """
      )

      // If we fail to delete, don't throw an error
      try? await delete(
        simulator,
        config: config,
        slotIndex: slotIndex,
        // We can't clean up slots, since we assign to it below
        cleanUpSlots: false,
        context: "getSimulator, reused: \(config.cloneDeviceName(index: slotIndex))"
      )

      let task = createCloneTask(config: config, exclusive: exclusive, slotIndex: slotIndex)
      simulatorSlots[config]![slotIndex] = .pendingCreation(task, exclusive: exclusive)
      return try await task.value
    }
  }

  private func createCloneTask(
    config: SimulatorConfig,
    exclusive: Bool,
    slotIndex: Int
  ) -> Task<SimulatorUDID, Error> {
    return Task {
      do {
        let simulator = try await simulatorControl.clone(
          getBase(for: config),
          name: config.cloneDeviceName(index: slotIndex),
          deviceType: config.deviceType,
          runtimeIdentifier: config.runtimeIdentifier(),
          postBoot: postBoot
        )

        simulatorSlots[config]![slotIndex] = .active(simulator, exclusive: exclusive)

        // We want to increment the reference count as soon as we get back from `await`, to ensure
        // that when we suspend and potentially decrement the reference count, we don't delete the
        // simulator before we have a chance to use it. Also, since we created the simulator, we
        // should be responsible for incrementing the reference count. Any functions that reuse
        // this task need to increment the reference count as well.
        incrementReferenceCount(for: simulator)

        return simulator
      } catch {
        // If we fail to create the clone, we need to empty the slot, instead
        // of leaving it in a pending state
        simulatorSlots[config]![slotIndex] = .empty

        throw error
      }
    }
  }

  private func registerReleaseOnExit(for leaser: PID) {
    let processSource =
      DispatchSource.makeProcessSource(identifier: leaser, eventMask: .exit, queue: .main)

    var handledExit = false
    let onExitHandler: () -> Void = { [weak self] in
      // Avoid double handling of exit in case the process exits between
      // `processSource.resume()` and the check with `kill`
      guard !handledExit else { return }
      handledExit = true

      Task {
        guard let self else { return }

        Logger.simulatorManager.debug("👋 PID \(leaser, privacy: .public) exited")

        try await self.release(for: leaser)
      }
    }

    processSource.setEventHandler { onExitHandler() }
    processSource.resume()

    // Check to see if the process is already dead and cancel the source if it is, which will
    // trigger `setCancelHandler`, which releases the simulator
    guard kill(leaser, 0) == 0 else {
      processSource.cancel()
      onExitHandler()
      return
    }

    leaserExitListeners[leaser] = processSource
  }

  private func removeReleaseOnExit(for leaser: PID) {
    guard let leaserExitListener = leaserExitListeners[leaser] else { return }
    leaserExitListeners.removeValue(forKey: leaser)
    leaserExitListener.cancel()
  }

  private func pendingDeletion(
    _ simulator: SimulatorUDID,
    config: SimulatorConfig,
    slotIndex: Int
  ) async {
    guard deleteIdleAfter > 0 || deleteRecentlyUsedIdleAfter > 0 else {
      // If we fail to delete, don't throw an error
      try? await delete(
        simulator,
        config: config,
        slotIndex: slotIndex,
        cleanUpSlots: true,
        context: "pendingDeletion immediate"
      )
      return
    }

    let task = Task {
      Logger.simulatorManager.info(
        """
        💤 Scheduling delete of simulator \(simulator, privacy: .public) in \
        \(self.deleteIdleAfter, privacy: .public) to \
        \(self.deleteRecentlyUsedIdleAfter, privacy: .public) seconds
        """
      )

      let now = Date()
      let shortDeadline = now.addingTimeInterval(TimeInterval(deleteIdleAfter))
      let recentlyUsedDeadline = now.addingTimeInterval(TimeInterval(deleteRecentlyUsedIdleAfter))

      while true {
        let remainingTime: TimeInterval
        if recentlyLeased.contains(config) {
          remainingTime = recentlyUsedDeadline.timeIntervalSinceNow
        } else {
          remainingTime = shortDeadline.timeIntervalSinceNow
        }

        if remainingTime <= 0 {
          break
        }

        // Sleep for up-to 1 second before next check
        try await Task.sleep(for: .seconds(min(remainingTime, 1)))
      }

      guard case .pendingDeletion(let slotSimulator, _) = simulatorSlots[config]![slotIndex],
            simulator == slotSimulator else {
        // Simulator was reused, no need to delete
        return
      }

      // If we fail to delete, don't throw an error
      try? await delete(
        simulator,
        config: config,
        slotIndex: slotIndex,
        cleanUpSlots: true,
        context: "pendingDeletion delayed"
      )
    }

    simulatorSlots[config]![slotIndex] = .pendingDeletion(simulator, task)
  }

  private func delete(
    _ simulator: SimulatorUDID,
    config: SimulatorConfig,
    slotIndex: Int,
    cleanUpSlots: Bool,
    context: @escaping @autoclosure () -> String?
  ) async throws {
    let name = config.cloneDeviceName(index: slotIndex)

    Logger.simulatorManager.info(
      "🗑️ Deleting simulator \(simulator, privacy: .public) (\(name, privacy: .public))"
    )

    simulatorSlots[config]![slotIndex] = .deleting(simulator)

    referenceCount.removeValue(forKey: simulator)

    defer {
      // Even if we fail to delete, we need to set the slot to empty
      simulatorSlots[config]![slotIndex] = .empty

      if cleanUpSlots {
        // Shorten up the array by removing any empty slots at the end
        while case .empty = simulatorSlots[config]!.last {
          simulatorSlots[config]!.removeLast()
        }
      }
    }

    try await simulatorControl.delete(simulator, name: name, context: context())

    Logger.simulatorManager.info(
      "🗑️ Deleted simulator \(simulator, privacy: .public) (\(name, privacy: .public)"
    )
  }

  // MARK: Child Process Management

  private nonisolated func createStartChildProcessTask(path: String) -> Task<Void, Never> {
    return Task.detached { [weak self] in
      let process: Process
      do {
        guard let self else { return }
        process = try await self.createProcess(path: path)
        // `self` drops out of scope here, so `SimulatorManager` can deinit
      } catch {
        Logger.simulatorManager.info(
          """
          ❌ Failed to create child process at "\(path, privacy: .public)": \
          \(error, privacy: .public)
          """
        )
        return
      }

      await withCheckedContinuation { cont in
        process.terminationHandler = { proc in
          let exitCode = proc.terminationStatus
          Logger.simulatorManager.warning(
            """
            ⚠️ "\(path, privacy: .public)" exited with code: \(exitCode, privacy: .public)
            """
          )
          cont.resume()
        }

        do {
          Logger.simulatorManager.info(
            #"🧒 Starting "\#(path, privacy: .public)""#
          )
          try process.run()
        } catch {
          Logger.simulatorManager.info(
            """
            ❌ Failed to start "\(path, privacy: .public)": \
            \(error, privacy: .public)
            """
          )
          cont.resume()
        }
      }
    }
  }

  private func createProcess(path: String) throws -> Process {
    let process = Process()

    process.executableURL = URL(fileURLWithPath: path)

    let outPTY = try PTY()
    process.standardOutput = FileHandle(fileDescriptor: outPTY.child, closeOnDealloc: true)
    let outQueue = DispatchQueue(label: "com.example.simulator_manager.child_process.out")
    let outWatcher = watch(fd: outPTY.parent, queue: outQueue) { line in
      Logger.childProcess.info("[\(path, privacy: .public)] \(line, privacy: .public)")
    }

    let errPTY = try PTY()
    process.standardError = FileHandle(fileDescriptor: errPTY.child, closeOnDealloc: true)
    let errQueue = DispatchQueue(label: "com.example.simulator_manager.child_process.err")
    let errWatcher = watch(fd: errPTY.parent, queue: errQueue) { line in
      Logger.childProcess.error("[\(path, privacy: .public)] \(line, privacy: .public)")
    }

    childProcesses[path] = (process, outWatcher, errWatcher)

    return process
  }
}

/// Installs a DispatchSourceRead on `fd`.
private func watch(
  fd: Int32,
  queue: DispatchQueue,
  onLine: @escaping (String) -> Void
) -> DispatchSourceRead {
  let src = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
  var buffer = Data()

  src.setEventHandler {
    var tmp = [UInt8](repeating: 0, count: 4096)
    let n = read(fd, &tmp, tmp.count)
    guard n > 0 else {
      src.cancel()
      close(fd)
      return
    }

    buffer.append(contentsOf: tmp[0..<n])

    // Split on newline; last segment may be an incomplete tail
    let segments = buffer.split(
      separator: UInt8(ascii: "\n"),
      omittingEmptySubsequences: false
    )

    // Emit every complete line (all but the last segment)
    for lineData in segments.dropLast() {
      if let line = String(data: lineData, encoding: .utf8) {
        onLine(line)
      }
    }

    // Keep the last segment (possibly empty or partial) for next time
    buffer = Data(segments.last ?? Data())
  }

  src.resume()

  return src
}
