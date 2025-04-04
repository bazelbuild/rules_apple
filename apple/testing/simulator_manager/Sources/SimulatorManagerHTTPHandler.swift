import Foundation
import NIO
import NIOHTTP1

struct SimulatorManagerRequest {
  let method: HTTPMethod
  let path: String
  let pathComponents: [String]
  let queryParameters: [String: String]
}

struct SimulatorManagerResponse {
  let status: HTTPResponseStatus
  let message: String
}

final class SimulatorManagerHTTPHandler: ChannelInboundHandler, ChannelOutboundHandler {
  public typealias InboundIn = FullHTTPRequest
  public typealias InboundOut = SimulatorManagerRequest

  public typealias OutboundIn = SimulatorManagerResponse
  public typealias OutboundOut = FullHTTPResponse

  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    let request = self.unwrapInboundIn(data)

    guard let url = URL(string: "http://x\(request.head.uri)"),
          let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      write(context: context, response: .init(status: .badRequest, message: "Invalid URL"))
      context.flush()
      return
    }

    let pathComponents = url.pathComponents.filter { $0 != "/" && $0 != "" }
    var queryParameters: [String: String] = [:]
    for queryItem in urlComponents.queryItems ?? [] {
      if let value = queryItem.value {
        queryParameters[queryItem.name] = value
      }
    }

    guard let path = pathComponents.first else {
      write(context: context, response: .init(status: .badRequest, message: "Method required"))
      context.flush()
      return
    }

    context.fireChannelRead(
      self.wrapInboundOut(
        .init(
          method: request.head.method,
          path: path,
          pathComponents: Array(pathComponents.dropFirst()),
          queryParameters: queryParameters
        )
      )
    )
  }

  func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
    let response = unwrapOutboundIn(data)

    write(context: context, response: response)
  }

  private func write(context: ChannelHandlerContext, response: SimulatorManagerResponse) {
    let message = response.message + "\n"

    context.write(
      wrapOutboundOut(
        .init(
          head: .init(
            version: .http1_1,
            status: response.status,
            headers: .defaultHeaders(for: message)
          ),
          body: context.channel.allocator.buffer(string: message)
        )
      ),
      promise: nil
    )
  }
}

extension HTTPHeaders {
  static func defaultHeaders(for message: String) -> HTTPHeaders {
    var headers = HTTPHeaders()
    headers.add(name: "Content-Length", value: "\(message.utf8.count)")
    headers.add(name: "Content-Type", value: "text/plain")
    return headers
  }
}
