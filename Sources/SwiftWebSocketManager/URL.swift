//
//  URL.swift
//  WebSocketManager
//
//  Created by Iain McLaren on 9/9/2023.
//

import Foundation

public extension URL {
    /// Replace the port of a URL.
    /// - Parameter port: The new port.
    mutating func replacePort(_ port: Int) {
        guard var urlComponents = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
            return
        }
        urlComponents.port = port
        self = urlComponents.url!
    }
}
    
public extension URLRequest {
    /// Add an Authorization bearer token to the URLRequest.
    /// - Parameter bearerToken: The bearer token.
    mutating func addBearerToken(_ bearerToken: String) {
        self.addValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
    }
}
