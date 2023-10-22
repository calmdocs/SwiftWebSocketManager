//
//   URLSessionWebSocketTask.Message.swift
//  WebSocketManager
//
//  Created by Iain McLaren on 12/7/2023.
//

import Foundation
import SwiftUI

public extension URLSessionWebSocketTask.Message {
    
    /// Decode a JSON URLSessionWebSocketTask.Message.
    ///  - Returns: The decoded Decodable item.
    func decodeJSON<T: Decodable>() throws -> T {
        switch self {
        case .string(let json):
            guard let data = json.data(using: .utf8) else {
                throw WebSocketError.invalidFormat
            }
            let message = try JSONDecoder().decode(T.self, from: data)
            return message
        case .data:
            throw WebSocketError.invalidFormat
        @unknown default:
            throw WebSocketError.invalidFormat
        }
    }
}
