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

    // 🆕 新的狀態字段
    var taskType: TaskType
    var completionStatus: CompletionStatus

    // 🔄 保留向後兼容
    var status: TodoStatus

    var createdAt: Date
    var updatedAt: Date
    // 對應圖像 ID（若需要在前端顯示相對應的圖片）
    var correspondingImageID: String
}

// MARK: - TodoItem 便利方法
extension TodoItem {
    /// 從新字段推導舊狀態（向後兼容）
    var derivedStatus: TodoStatus {
        switch (taskType, completionStatus) {
        case (.memo, .pending):
            return .toDoList
        case (.scheduled, .pending):
            return .toBeStarted
        case (.uncompleted, .pending):
            return .undone
        case (_, .completed):
            return .completed
        }
    }

    /// 從舊狀態推導新字段（遷移輔助）
    static func deriveNewFields(from status: TodoStatus, taskDate: Date?) -> (TaskType, CompletionStatus) {
        switch status {
        case .toDoList:
            return (.memo, .pending)
        case .toBeStarted:
            return taskDate != nil ? (.scheduled, .pending) : (.memo, .pending)
        case .undone:
            return (.uncompleted, .pending)
        case .completed:
            // 根據是否有日期決定原始類型
            let originalType: TaskType = taskDate != nil ? .scheduled : .memo
            return (originalType, .completed)
        }
    }

    /// 是否為佇列中的項目（備忘錄 + 未完成）
    var isQueueItem: Bool {
        return (taskType == .memo || taskType == .uncompleted) && taskDate == nil
    }
}




