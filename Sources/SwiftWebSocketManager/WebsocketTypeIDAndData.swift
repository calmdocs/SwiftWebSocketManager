//
//  WebSocketTypeIDAndData.swift
//  WebSocketManager
//
//  Created by Iain McLaren on 6/9/2023.
//

import Foundation

/// Struct to publish websocket requests in a standardised format.
/// - Parameters:
///   - type: String.
///   - id: String.
///   - data: String.
@available(iOS 13, macOS 10.15, *)
public struct WebSocketTypeIDAndData: Codable {
    let type: String
    let id:   String
    let data: String
    
    public enum CodingKeys: String, CodingKey {
        case type = "Type"
        case id   = "ID"
        case data = "Data"
    }
    
    public init(type: String, id: String, data: String) {
        self.type = type
        self.id   = id
        self.data = data
    }
    
    /// Publish the contents of this struct.
    /// - Parameters:
    /// - wsStream:  The WebSocketStream.
    /// - errors: Send all Error? messages to this function.
    public func publish(
        wsStream: WebSocketStream,
        errors:@escaping (Error?) -> Void
    ) async {
        await WebSocketPublishToJSON(
            self,
            wsStream: wsStream,
            errors: errors
        )
    }
}
