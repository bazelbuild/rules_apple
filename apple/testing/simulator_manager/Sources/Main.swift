import ArgumentParser

@main
struct Main: AsyncParsableCommand {
  // This is set externally to prevent having to recompile the manager just for `start.sh` changes
  @Option(help: "Version of the simulator manager")
  var version: String

  @Option(help: "Path to where the pid should be written")
  var pidPath: String

  @Option(help: "Path to where the unix domain socket should be created")
  var unixSocketPath: String

  @Option(help: "Number of seconds to wait before deleting a recently used idle simulator")
  var deleteRecentlyUsedIdleAfter: UInt16

  @Option(help: "Number of seconds to wait before deleting a non-recently used idle simulator")
  var deleteIdleAfter: UInt16

  @Option(
    help: """
    The number of simulators to keep in the recently used list; affects wether \
    'delete-recently-used-idle-after' or 'delete-idle-after' is used when determining when to \
    delete an unused simulator
    """
  )
  var recentlyUsedCapacity = 1

  @Option(
    name: .customLong("startup-process"),
    help: """
    The path to a startup process that will be run when the simulator manager is started. This \
    process will not be relaunched if it exits.

    To pass custom arguments to the process you should wrap it in a script.

    Setting this flag multiple times will result in multiple startup process being launched.
    """
  )
  var startupProcesses: [String] = []

  @Option(help: "Path to an executable that will run after a simulator clone is booted")
  var postBoot: String

  func validate() throws {
    guard recentlyUsedCapacity > 0 else {
      throw ValidationError(
        """
        'recently-used-capacity' must be greater than 0.
        """
      )
    }

    guard Set(startupProcesses).count == startupProcesses.count else {
      throw ValidationError("'startup-process' must be unique.")
    }
  }

  func run() async throws {
    let simulatorManager = SimulatorManager(
      simulatorControl: RealSimulatorControl(),
      deleteRecentlyUsedIdleAfter: deleteRecentlyUsedIdleAfter,
      deleteIdleAfter: deleteIdleAfter,
      recentlyUsedCapacity: recentlyUsedCapacity,
      deleteOnPIDExit: true,
      startupProcesses: startupProcesses,
      postBoot: postBoot
    )
    try await simulatorManager.startChildProcesses()

    try await HTTPServer(
      simulatorRequestHandler: SimulatorRequestHandler(
        simulatorManager: simulatorManager
      ),
      version: version
    ).run(pidPath: pidPath, unixSocketPath: unixSocketPath)
  }
}
