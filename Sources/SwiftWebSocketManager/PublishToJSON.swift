//
//  PublishToJSON.swift
//  WebSocketManager
//
//  Created by Iain McLaren on 6/9/2023.
//

import Foundation

/// Encode a value to JSON and publish as a websocket request.
/// - Parameters:
/// - value: The Encodable item to send to the WebSocketStream.
/// - wsStream:  The WebSocketStream.
/// - errors: Send any Error? messages to this function.
@available(iOS 13, macOS 10.15, *)
public func WebSocketPublishToJSON<T>(
    _ value: T,
    wsStream: WebSocketStream,
    errors:@escaping (Error?) -> Void = { _ in }
) async where T : Encodable {
    do {
        try await WebSocketPublishToJSON(
            value,
            wsStream: wsStream
        )
        errors(nil)
    } catch {
        errors(error)
    }
}

/// Encode a value to JSON and publish as a websocket request.
/// - Parameters:
/// - value: The Encodable item to send to the WebSocketStream.
/// - wsStream:  The WebSocketStream.
/// - Throws: Any WebSocketStream errors.
@available(iOS 13, macOS 10.15, *)
public func WebSocketPublishToJSON<T>(
    _ value: T,
    wsStream: WebSocketStream
) async throws where T : Encodable  {

    let jsonData = try JSONEncoder().encode(value)
    let jsonString = String(data: jsonData, encoding: .utf8)!

    guard wsStream.webSocketTask.state == .running else {
        throw WebSocketError.sendMessageFailure
    }
    let taskMessage = URLSessionWebSocketTask.Message.string(jsonString)
    try await wsStream.webSocketTask.send(taskMessage)
}
