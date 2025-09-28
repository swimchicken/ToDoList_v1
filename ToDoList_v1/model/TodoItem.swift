// MARK: - TodoItem.swift
import Foundation

/// 主資料結構：待辦事項 (TodoItem)
struct TodoItem: Identifiable, Codable {
    var id: UUID
    var userID: String
    var title: String
    var priority: Int
    var isPinned: Bool
    var taskDate: Date? // 修改為可選類型，允許 null 值
    var note: String
    var status: TodoStatus
    var createdAt: Date
    var updatedAt: Date
    // 對應圖像 ID（若需要在前端顯示相對應的圖片）
    var correspondingImageID: String
    // 新增：記錄用戶是否有啟用時間設定
    var hasTimeSet: Bool = false
}




