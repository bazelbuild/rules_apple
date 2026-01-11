import NIOHTTP1

final class SimulatorRequestHandler {
  private let simulatorManager: SimulatorManager

  init(simulatorManager: SimulatorManager) {
    self.simulatorManager = simulatorManager
  }

  func handleRequest(
    method: HTTPMethod,
    pathComponents: [String],
    queryParameters: [String: String]
  ) async throws -> SimulatorManagerResponse {
    switch method {
    case .POST:
      guard pathComponents.count >= 1 else {
        return .init(
          status: .badRequest,
          message: "Must specify <leaser PID>"
        )
      }

      guard let leaser = PID(pathComponents[0]) else {
        return .init(status: .badRequest, message: "Leaser PID must be an integer")
      }
      guard let exclusiveString = queryParameters["exclusive"] else {
        return .init(status: .badRequest, message: "Must specify 'exclusive' query parameter")
      }
      let exclusive = exclusiveString == "1"
      guard let deviceType = queryParameters["deviceType"] else {
        return .init(status: .badRequest, message: "Must specify 'deviceType' query parameter")
      }
      guard let os = queryParameters["os"] else {
        return .init(status: .badRequest, message: "Must specify 'os' query parameter")
      }
      guard let version = queryParameters["version"] else {
        return .init(status: .badRequest, message: "Must specify 'version' query parameter")
      }

      let config = SimulatorConfig(
        deviceType: deviceType,
        os: os,
        version: version
      )

      do {
        return try await .init(
          status: .created,
          message: simulatorManager
            .lease(to: leaser, exclusive: exclusive, config: config)
        )
      } catch SimulatorManagerError.alreadyLeased(let udid) {
        return .init(
          status: .badRequest,
          // FIXME: Get this from the error itself
          message: "PID \(leaser) has already leased another simulator: \(udid)"
        )
      }

    case .DELETE:
      guard pathComponents.count >= 1 else {
        return .init(
          status: .badRequest,
          message: "Must specify <leaser PID>"
        )
      }

      guard let leaser = PID(pathComponents[0]) else {
        return .init(status: .badRequest, message: "Leaser PID must be an integer")
      }

      do {
        try await simulatorManager.release(for: leaser)

        return .init(
          status: .ok,
          message: "Success"
        )
      } catch SimulatorManagerError.noLease {
        return .init(
          status: .notFound,
          // FIXME: Get this message from the error itself
          message: "PID \(leaser) doesn't have a simulator leased"
        )
      }

    default:
      return .init(status: .methodNotAllowed, message: "Unsupported HTTP method: \(method)")
    }
  }
}
