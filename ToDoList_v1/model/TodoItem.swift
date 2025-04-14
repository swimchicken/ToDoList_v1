//
//  ToDoList.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/4/14.
//
import Foundation

/// 定義待辦事項狀態
enum TodoStatus: String, Codable {
    case toDoList      // 代辦佇列
    case toBeStarted   // 尚未開始
    case undone        // 進行中，但尚未完成
    case completed     // 已完成
}

/// 主資料結構：待辦事項 (TodoItem)
struct TodoItem: Identifiable, Codable {
    
    var id: UUID
    
    var userID: String
    
    var title: String

    var priority: Int
    
    var isPinned: Bool
    
    var taskDate: Date
    
    var note: String
    
    var status: TodoStatus
    
    var createdAt: Date
    
    var updatedAt: Date
    
    // 對應圖像 ID（若需要在前端顯示相對應的圖片）
    var correspondingImageID: String
}

// MARK: - 使用範例




