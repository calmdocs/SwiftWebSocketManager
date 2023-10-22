//
//  WebSocketStream.swift
//  WebSocketManager
//
//  Created by Iain McLaren on 12/7/2023.
//

import Foundation
import SwiftUI

/// Connect to a websocket server.
@available(iOS 13, macOS 10.15, *)
public class WebSocketStream: AsyncSequence {
    public var isDone: Bool = false
    
    public var webSocketTask: URLSessionWebSocketTask
    
    public var urlRequest: URLRequest
    
    public typealias Element = URLSessionWebSocketTask.Message
    public typealias AsyncIterator = AsyncThrowingStream<URLSessionWebSocketTask.Message, Error>.Iterator
    
    private var stream: AsyncThrowingStream<Element, Error>?
    private var continuation: AsyncThrowingStream<Element, Error>.Continuation?
    
    /// Connect to a websocket server.
    /// - Parameters:
    ///   - urlRequest: The URLRequest.
    ///   - session: The URLSession (defaults to URLSession.shared).
    ///   - errors: Send all Error? messages to this function.
    public init(
        _ urlRequest: URLRequest = URLRequest(url: URL(string: "wss:")!),
        session: URLSession = URLSession.shared,
        errors:@escaping (Error?) -> Void = { _ in }
    ) {
        self.urlRequest = urlRequest
        webSocketTask = session.webSocketTask(with: self.urlRequest)
        stream = newStream(
            urlRequest: urlRequest,
            errors: errors
        )
    }
    
    /// Create a new AsyncThrowingStream.
    /// - Parameters:
    ///   - urlRequest: The URLRequest.
    ///   - errors: Send all Error? messages to this function.
    /// - Returns: The AsyncThrowingStream<Element, Error>?.
    public func newStream(
        urlRequest: URLRequest,
        errors:@escaping (Error?) -> Void
    ) -> AsyncThrowingStream<Element, Error>? {
        return AsyncThrowingStream { continuation in
            self.continuation = continuation
            self.continuation?.onTermination = { @Sendable [self, webSocketTask] _ in
                errors(WebSocketError.streamTerminated)
                webSocketTask.cancel()
                streamRestarter(
                    urlRequest: urlRequest,
                    errors: errors
                )
            }
        }
    }
    
    // Cancel the WebSocketStream.
    public func cancel() {
        isDone = true
        webSocketTask.cancel()
    }
    
    /// Restart the WebSocketStream.
    /// - Parameters:
    ///   - urlRequest: The URLRequest.
    ///   - errors: Send all Error? messages to this function.
    public func streamRestarter(
        urlRequest: URLRequest,
        errors:@escaping (Error?) -> Void
    ) {
        if !isDone {
            let session = URLSession.shared
            webSocketTask = session.webSocketTask(with: urlRequest)
            stream = newStream(
                urlRequest: urlRequest,
                errors: errors
            )
        }
    }
    
    /// Make a WebSocketTask AsyncIterator
    /// - Returns: AsyncIterator
    public func makeAsyncIterator() -> AsyncIterator {
        guard let stream = stream else {
            fatalError("stream not initialized")
        }
        webSocketTask.resume()
        listenForMessages()
        return stream.makeAsyncIterator()
    }
    
    /// Listen for WebSocketTask messages
    public func listenForMessages() {
        webSocketTask.receive { [unowned self] result in
            switch result {
            case .success(let message):
                continuation?.yield(message)
                listenForMessages()
            case .failure(let error):
                continuation?.finish(throwing: error)
            }
        }
    }
}
