//
//  Item.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/2/17.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
