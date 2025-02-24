//
//  User.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/2/23.
//

import Foundation


struct User: Identifiable, Codable {
    let id: UUID = UUID()
    var name: String
    var email: String
    
    private enum CodingKeys: String, CodingKey {
        case name, email
    }
}
