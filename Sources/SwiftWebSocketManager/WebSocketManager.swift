//
//  WebSocketManager.swift
//  WebSocketManager
//
//  Created by Iain McLaren on 9/08/23.
//

import Foundation
import SwiftUI
import SwiftProcessManager

/// Connect to a websocket server using a WebSocketStream.
@available(iOS 13, macOS 10.15, *)
public class WebSocketManager: ObservableObject {
    
    /// Base URL for each WebSocketStraem created by this manager.
    @Published public var baseURL: URL?
   
    /// URL port to optionally modify the baseURL
    @Published public var port: Int?
    
    /// Indicates whether the WebSocketManager has been cancelled.
    private var done: Bool = false

    /// subscribeWithBinary variables
    @Published public var processManager = ProcessManager()
    private var isFirstRun: Bool = true
    private var timer: Timer?
    private var pingCount = 0
    
    /// Initialise the connection to a websocket server using a WebSocketStream.
    /// - Parameters:
    ///   - baseURL: Base URL for each WebSocketStraem created by this manager.
    ///   - port: URL port to optionally modify the baseURL
    public init(
        baseURL: URL? = nil,
        port: Int? = nil
    ) {
        self.baseURL = baseURL
        self.port = port
    }
    
    /// Initialise the connection to a websocket server by creating a WebSocketStream.
    /// - Parameters:
    ///   - path:  The URL path used to connect to the websocket server.
    ///   - urlRequest: URLRequest used to connect to the websocket server.
    ///   - bearerToken: Authorization bearer token to optionally add to the urlRequest.
    /// - Returns: The WebSocketStream
    public func connect(
        path: String? = nil,
        urlRequest: URLRequest? = nil,
        bearerToken: String? = nil
    ) throws -> WebSocketStream {
        var streamURLRequest: URLRequest
        if urlRequest != nil {
            streamURLRequest = urlRequest!
        } else {
            guard var url = self.baseURL else {
                throw WebSocketError.nilURLAndURLRequest
            }
            if path != nil {
                url = url.appendingPathComponent(path!)
            }
            if self.port != nil {
                url.replacePort(port!)
            }
            streamURLRequest = URLRequest(url: url)
            if bearerToken != nil {
                streamURLRequest.addBearerToken(bearerToken!)
            }
        }
        return WebSocketStream(streamURLRequest)
    }
    
    /// Subscibe to the websocket server.
    /// - Parameters:
    ///   - stream: The WebSocketStream.
    ///   - messages: Send each URLSessionWebSocketTask.Message to this function.
    ///   - errors: Send all Error? messages to this function.
    public func subscribe(
        stream: WebSocketStream,
        messages:@escaping (URLSessionWebSocketTask.Message) -> Void = { _ in },
        errors:@escaping (Error) -> Void = { _ in }
    ) {
        Task(priority: .medium) {
            await startAsync(stream: stream, messages: messages, errors: errors)
        }
    }
    
    /// Start monitoring the stream.
    /// - Parameters:
    ///   - stream: The WebSocketStream.
    ///   - messages: The URLSessionWebSocketTask.Message stream to monitor.
    ///   - errors: Send all Error? messages to this function.
    public func startAsync(
        stream: WebSocketStream,
        messages: (URLSessionWebSocketTask.Message) -> Void,
        errors: (Error) -> Void
    ) async {
        while !self.done {
            do {
                //for try await message in self.stream {
                for try await message in stream {
                    messages(message)
                }
            } catch {
                errors(error)
            }
        }
        
        // Cancel the stream when this Manager is closed.
        stream.cancel()
    }

    /// Publish a WebsocketTypeIDAndData struct as JSON to the websocket server encoded as JSON.
    /// - Parameters:
    ///   - stream: The WebSocketStream.
    ///   - type: String.
    ///   - id: String.
    ///   - data: String.
    ///   - errors: Send all Error? messages to this function.
    public func publish(
        _ stream: WebSocketStream,
        type: String = "",
        id:   String = "",
        data: String = "",
        errors:@escaping (Error?) -> Void  = { _ in }
    ) {
        Task {
            await WebSocketTypeIDAndData(
                type: type,
                id:   id,
                data: data
            )
            .publish(
                //wsStream: self.stream,
                wsStream: stream,
                errors: errors
            )
        }
    }

    /// Publish a generic Encodable item to the websocket server encoded as JSON.
    /// - Parameters:
    ///   - stream: WebSocketStream,
    ///   - value: The Encodable item to send to the .websocket server.
    ///   - errors: Send all Error? messages to this function.
    public func publish<T>(
        _ stream: WebSocketStream,
        _ value: T,
        errors:@escaping (Error?) -> Void = { _ in }
    ) where T : Encodable {
        Task {
            do {
                try await WebSocketPublishToJSON(
                    value,
                    wsStream: stream
                )
                errors(nil)
            } catch {
                errors(error)
            }
        }
    }
    
    /// Publish a generic Encodable item to the websocket server.
    /// - Parameters:
    ///   - stream: The WebSocketStream.
    ///   - value: The Encodable item to send to the .websocket server.
    ///   - errors: Send all Error? messages to this function.
    /// - Throws: Any WebSocketPublishToJSON error.
    public func publish<T>(
        _ stream: WebSocketStream,
        _ value: T
    ) async throws where T : Encodable {
        try await WebSocketPublishToJSON(
            value,
            wsStream: stream
        )
    }

    /// Cancel any connection to the WebSocketStream (and do not restart).
    /// Note that each connected stream is cancelled in startAsync.
    public func cancel() {
        self.done = true
        
        self.processManager.cancel()
            
        if let t = self.timer {
            t.invalidate()
        }
    }

    /// Terminate the currently running binary.
    /// If the processManager withRetry option is set to true, the binary will restart.
    public func terminateCurrentTask() {
        self.processManager.terminateCurrentTask()
    }

    /// Send an external pong() to delay any pingTimeout
    public func pong() {
        self.pingCount = 0
    }
    
    /// Start a binary and connect to a a WebSocketStream (generally the bundled binary will be the websocket server).
    /// - Parameters:
    ///   - stream: The WebSocketStream.
    ///   - binName: The name of the bundled binary to run.
    ///   - withRetry: If true, restarts the binary if it exits.
    ///   - pingTimeLimit: Time before the function calls pingTimeLimit - messages received will act as a pong() as will calling self.pong().
    ///   - pingTimeout: Triggered when pingTimeLimit is reached without any pongs.  Never triggered if pingTimeLimit <= 0.
    ///   - standardOutput: Send the binary standard output to the provided function.
    ///   - taskExitNotification: Send an Error? to the provided function each time the binary exits.
    ///   - messages: Send each URLSessionWebSocketTask.Message to the provided function.
    ///   - errors: Send all websocket Error? messages to this function.
    public func subscribeWithBinary(
        stream: WebSocketStream,
        binName: String,
        withRetry: Bool = false,
        pingTimeLimit: TimeInterval = 0,
        pingTimeout: @escaping () -> Void = {},
        standardOutput: @escaping (String) -> Void  = { _ in },
        taskExitNotification: @escaping (Error?) -> Void  = { _ in },
        messages: @escaping (URLSessionWebSocketTask.Message) -> Void = { _ in },
        errors:@escaping (Error) -> Void = { _ in }
    ) async {
        await subscribeWithBinary(
            stream: stream,
            binURL: Bundle.main.url(forResource: binName, withExtension: nil)!,
            withRetry: withRetry,
            pingTimeLimit: pingTimeLimit,
            pingTimeout: pingTimeout,
            standardOutput: standardOutput,
            taskExitNotification: taskExitNotification,
            messages: messages,
            errors: errors
        )
    }
        
    /// Start a binary and connect to a a WebSocketStream (generally the bundled binary will be the websocket server).
    /// - Parameters:
    ///   - stream: The WebSocketStream.
    ///   - binURL: The url of the binary to run.
    ///   - withRetry: If true, restarts the binary if it exits.
    ///   - pingTimeLimit: Time before the function calls pingTimeLimit - messages received will act as a pong() as will calling self.pong().
    ///   - pingTimeout: Triggered when pingTimeLimit is reached without any pongs.  Never triggered if pingTimeLimit <= 0.
    ///   - standardOutput: Send the binary standard output to the provided function.
    ///   - taskExitNotification: Send an Error? to the provided function each time the binary exits.
    ///   - messages: Send each URLSessionWebSocketTask.Message to the provided function.
    ///   - errors: Send all websocket Error? messages to this function.
    public func subscribeWithBinary(
        stream: WebSocketStream,
        binURL: URL,
        withRetry: Bool = false,
        pingTimeLimit: TimeInterval = 0,
        pingTimeout: @escaping () -> Void = {},
        standardOutput: @escaping (String) -> Void  = { _ in },
        taskExitNotification: @escaping (Error?) -> Void  = { _ in },
        messages: @escaping (URLSessionWebSocketTask.Message) -> Void = { _ in },
        errors:@escaping (Error) -> Void = { _ in }
    ) async {
        
        // Ping with timeout.
        if pingTimeLimit > 0 {
            self.timer = Timer.scheduledTimer(
                withTimeInterval: pingTimeLimit / 5,
                repeats: true
            ) { timer in
                self.pingCount += 1
                if self.pingCount >= 5 {
                    self.pingCount = 0
                    pingTimeout()
                }
            }
        }
 
        // Run the binary and connect to the websocket server.
        await self.processManager.RunProces(
            binURL: binURL,
            withRetry: withRetry,
            standardOutput: { result in
                standardOutput(result)
                if self.isFirstRun {
                    self.isFirstRun = false
                    self.subscribe(
                        stream: stream,
                        messages: { message in
                            DispatchQueue.main.async {
                                self.pong()
                            }
                            messages(message)
                        },
                        errors: errors
                    )
                }
            },
            taskExitNotification: taskExitNotification
        )
    }
}
    
    
    

