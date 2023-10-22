//
//  WebSocketError.swift
//  WebSocketManager
//
//  Created by Iain McLaren on 9/9/2023.
//

import Foundation

/// A WebSocketManager error.
@available(iOS 13, macOS 10.15, *)
public enum WebSocketError: Error {
    case invalidFormat
    case sendMessageFailure
    case streamTerminated
    case nilURLAndURLRequest
    case nilBearerToken
}
