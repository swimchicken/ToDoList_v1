// MARK: - TodoItem.swift
import Foundation

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




