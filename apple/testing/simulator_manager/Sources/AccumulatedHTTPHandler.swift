import NIO
import NIOHTTP1
import os.log

extension Logger {
  static let accumulatedHTTP = simulatorManager(category: "accumulated_http")
}

struct FullHTTPRequest {
  let head: HTTPRequestHead
  var body: ByteBuffer
}

struct FullHTTPResponse {
  let head: HTTPResponseHead
  var body: ByteBuffer
}

final class AccumulatedHTTPHandler: ChannelInboundHandler, ChannelOutboundHandler {
  typealias InboundIn = HTTPServerRequestPart
  typealias InboundOut = FullHTTPRequest

  typealias OutboundIn = FullHTTPResponse
  typealias OutboundOut = HTTPServerResponsePart

  private var requestHead: HTTPRequestHead?
  private var bodyBuffer: ByteBuffer?

  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    let part = self.unwrapInboundIn(data)

    switch part {
    case .head(let head):
      self.requestHead = head
      self.bodyBuffer = context.channel.allocator.buffer(capacity: 0)

    case .body(var chunk):
      self.bodyBuffer?.writeBuffer(&chunk)

    case .end:
      if let head = requestHead, let body = bodyBuffer {
        Logger.accumulatedHTTP.info(
          """
          ▶️ Received \(head.method.rawValue, privacy: .public) request for \
          \(head.uri, privacy: .public)
          """
        )

        let fullRequest = FullHTTPRequest(head: head, body: body)
        context.fireChannelRead(self.wrapInboundOut(fullRequest))
      }

      self.requestHead = nil
      self.bodyBuffer = nil
    }
  }

  func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
    let fullResponse = unwrapOutboundIn(data)

    Logger.accumulatedHTTP.info(
      "◀️ Sending \(fullResponse.head.status, privacy: .public) response"
    )

    context.write(wrapOutboundOut(.head(fullResponse.head)), promise: nil)

    if fullResponse.body.readableBytes > 0 {
      context.write(wrapOutboundOut(.body(.byteBuffer(fullResponse.body))), promise: nil)
    }

    context.write(wrapOutboundOut(.end(nil)), promise: promise)
  }

  func errorCaught(context: ChannelHandlerContext, error: Error) {
    Logger.accumulatedHTTP.error(
      "❌ \(error.localizedDescription, privacy: .public)"
    )
    context.close(promise: nil)
  }
}
