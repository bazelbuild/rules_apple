import Foundation
import NIO
import NIOExtras
import NIOHTTP1
import NIOPosix
import os.log

extension Logger {
  static let httpServer = simulatorManager(category: "server")
}

final class HTTPServer {
  private let simulatorRequestHandler: SimulatorRequestHandler

  private let version: String

  private var serverShutdownHandler: (() -> Void)?

  init(simulatorRequestHandler: SimulatorRequestHandler, version: String) {
    self.simulatorRequestHandler = simulatorRequestHandler
    self.version = version
  }

  func run(pidPath: String, unixSocketPath: String) async throws {
    let socketURL = URL(fileURLWithPath: unixSocketPath)
    let pidURL = URL(fileURLWithPath: pidPath)

    // Remove existing files if they exist
    try? FileManager.default.removeItem(at: socketURL)
    try? FileManager.default.removeItem(at: pidURL)

    try String(ProcessInfo.processInfo.processIdentifier).write(
      to: pidURL,
      atomically: true,
      encoding: .utf8
    )

    let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

    do {
      // This nested block is necessary to ensure that all the destructors for objects defined
      // inside are called before the final call to `eventLoopGroup.syncShutdownGracefully()`. A
      // possible side effect of not doing this is a run-time error "Cannot schedule tasks on an
      // EventLoop that has already shut down".
      let quiesce = ServerQuiescingHelper(group: eventLoopGroup)
      let fullyShutdownPromise: EventLoopPromise<Void> = eventLoopGroup.next().makePromise()
      serverShutdownHandler = {
        Logger.httpServer.info("⚠️ Shutting down server")
        quiesce.initiateShutdown(promise: fullyShutdownPromise)
      }

      do {
        let serverChannel = try await ServerBootstrap(group: eventLoopGroup)
          .serverChannelOption(ChannelOptions.backlog, value: 256)
          .serverChannelInitializer { channel in
            return channel.eventLoop.makeCompletedFuture {
              try channel.pipeline.syncOperations.addHandler(
                quiesce.makeServerChannelHandler(channel: channel)
              )
            }
          }
          .bind(unixDomainSocketPath: unixSocketPath, childChannelInitializer: { childChannel in
            return childChannel.eventLoop.makeCompletedFuture {
              try childChannel.pipeline.syncOperations.addHandlers([
                HTTPResponseEncoder(),
                ByteToMessageHandler(HTTPRequestDecoder()),
                AccumulatedHTTPHandler(),
                SimulatorManagerHTTPHandler(),
              ])

              return try NIOAsyncChannel<SimulatorManagerRequest, SimulatorManagerResponse>(
                wrappingChannelSynchronously: childChannel,
                configuration: .init()
              )
            }
          })

        Logger.httpServer.info("🔌 Server running on UDS at \(unixSocketPath, privacy: .public)")

        try await withThrowingDiscardingTaskGroup { group in
          try await serverChannel.executeThenClose { inbound in
            for try await connectionChannel in inbound {
              group.addTask {
                do {
                  try await self.handleConnection(
                    channel: connectionChannel
                  )
                } catch {
                  // We don't throw here, as it locks up the whole server
                  Logger.httpServer.error(
                    """
                    ❌ Caught connection error: \(error, privacy: .public)
                    """
                  )
                }
              }
            }
          }
        }
      } catch {
        Logger.httpServer.error("❌ Caught top-level error: \(error, privacy: .public)")
        try await eventLoopGroup.shutdownGracefully()
        throw error
      }

      try await fullyShutdownPromise.futureResult.get()
    }

    try await eventLoopGroup.shutdownGracefully()
    Logger.httpServer.info("✅ Server shut down")

    // Cleanup files
    try? FileManager.default.removeItem(at: socketURL)
    try? FileManager.default.removeItem(at: pidURL)
  }

  private func handleConnection(
    channel: NIOAsyncChannel<SimulatorManagerRequest, SimulatorManagerResponse>
  ) async throws {
    try await channel.executeThenClose { inbound, outbound in
      for try await request in inbound {
        try await outbound.write(handleRequest(request))
      }
    }
  }

  private func handleRequest(
    _ request: SimulatorManagerRequest
  ) async -> SimulatorManagerResponse {
    switch request.path {
    case "simulator":
      do {
        return try await simulatorRequestHandler.handleRequest(
          method: request.method,
          pathComponents: request.pathComponents,
          queryParameters: request.queryParameters
        )
      } catch {
        Logger.httpServer.error(
          "❌ simulatorRequestHandler.handleRequest error: \(error, privacy: .public)"
        )

        return .init(
          status: .internalServerError,
          message: "Internal server error: \(error)"
        )
      }

    case "version":
      return .init(
        status: .ok,
        message: version
      )

    case "shutdown":
      Logger.httpServer.info("⚠️ Shutdown request received")
      serverShutdownHandler?()
      return .init(status: .ok, message: "Server shutting down")

    default:
      return .init(status: .badRequest, message: "Unknown method: \(request.path)")
    }
  }
}
