//
//  ArrayReplaceInPlace.swift
//  SwiftWebSocketManager
//
//  Created by Iain McLaren on 12/7/2023.
//

import Foundation
import SwiftUI

public extension Array where Element: Identifiable {
    
    /// Replaces all of the items in an array
    /// - Parameter items: The replacement array ([Element]).
    mutating func replaceInPlace(items:[Element]) {
        
        // Upsert
        for x in items {
            if let i = self.firstIndex(where: { $0.id == x.id }) {
                self[i] = x
            } else {
                self.append(x)
            }
        }
        
        // Remove
        for (i, x) in self.enumerated() {
            if items.firstIndex(where: { $0.id == x.id }) == nil {
                self.remove(at: i)
            }
        }
    }
}
