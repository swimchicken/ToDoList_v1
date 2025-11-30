//
//  APIModels.swift
//  ToDoList_v1
//
//  API數據模型定義
//

import Foundation


struct AppleLoginRequest: Codable {
    let identityToken: String
    let name: String?

    enum CodingKeys: String, CodingKey {
        case identityToken = "identity_token"
        case name
    }
}

struct GoogleLoginRequest: Codable {
    let idToken: String

    enum CodingKeys: String, CodingKey {
        case idToken = "id_token"
    }
}

struct AuthResponse: Codable {
    let token: String
    let user: User
}

struct User: Codable {
    let id: UUID
    let email: String
    let name: String?
    let avatarUrl: String?
    let isNewUser: Bool?

    enum CodingKeys: String, CodingKey {
        case id, email, name
        case avatarUrl = "avatar_url"
        case isNewUser = "is_new_user"
    }
}

struct UpdateUserRequest: Codable {
    let name: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case name
        case avatarUrl = "avatar_url"
    }
}

// MARK: - TodoItem相關模型

struct APITodoItem: Codable, Identifiable {
    let id: UUID
    let userId: UUID?
    let title: String
    let note: String
    let priority: Int
    let isPinned: Bool
    let taskDate: Date?
    let taskType: TaskType? // 🆕 任務類型（可能為空，需要向後兼容）
    let completionStatus: CompletionStatus? // 🆕 完成狀態（可能為空，需要向後兼容）
    let status: TodoStatus? // 🔄 舊狀態字段（後端已遷移，設為可選）
    let correspondingImageId: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title, note, priority
        case isPinned = "is_pinned"
        case taskDate = "task_date"
        case taskType = "task_type" // 🆕 映射到後端字段
        case completionStatus = "completion_status" // 🆕 映射到後端字段
        case status // 🔄 舊字段，現在可選
        case correspondingImageId = "corresponding_image_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CreateTodoRequest: Codable {
    let title: String
    let note: String
    let priority: Int
    let isPinned: Bool
    let taskDate: Date?
    let taskType: TaskType // 🆕 新增任務類型
    let completionStatus: CompletionStatus // 🆕 新增完成狀態
    let status: TodoStatus
    let correspondingImageId: String

    enum CodingKeys: String, CodingKey {
        case title, note, priority
        case isPinned = "is_pinned"
        case taskDate = "task_date"
        case taskType = "task_type" // 🆕 映射到後端字段
        case completionStatus = "completion_status" // 🆕 映射到後端字段
        case status
        case correspondingImageId = "corresponding_image_id"
    }
}

struct UpdateTodoRequest: Codable {
    let title: String?
    let note: String?
    let priority: Int?
    let isPinned: Bool?
    let taskDate: Date?
    let taskType: TaskType? // 🆕 新增任務類型
    let completionStatus: CompletionStatus? // 🆕 新增完成狀態
    let status: TodoStatus?
    let correspondingImageId: String?

    enum CodingKeys: String, CodingKey {
        case title, note, priority
        case isPinned = "is_pinned"
        case taskDate = "task_date"
        case taskType = "task_type" // 🆕 映射到後端字段
        case completionStatus = "completion_status" // 🆕 映射到後端字段
        case status
        case correspondingImageId = "corresponding_image_id"
    }
}

struct UpdateStatusRequest: Codable {
    let status: TodoStatus
}

// MARK: - 批量操作模型

struct BatchUpdateRequest: Codable {
    let items: [BatchUpdateItem]
}

struct BatchUpdateItem: Codable {
    let id: UUID
    let title: String?
    let status: String?
    let task_date: Date?
    let priority: Int?
    let is_pinned: Bool?
    let note: String?
    let corresponding_image_id: String?

    enum CodingKeys: String, CodingKey {
        case id, title, status, priority, note
        case task_date = "task_date"
        case is_pinned = "is_pinned"
        case corresponding_image_id = "corresponding_image_id"
    }
}

struct BatchDeleteRequest: Codable {
    let ids: [UUID]
}

struct BatchOperationResponse: Codable {
    // 使用 [String: Any] 的方式來處理動態JSON，但不可編碼
    // 改為直接解析原始JSON

    // 如果API返回結構簡單，可能只有基本字段
    var actualSuccessCount: Int {
        return 1 // 默認假設成功，因為API返回200
    }

    var actualFailedCount: Int {
        return 0 // 默認假設沒有失敗
    }

    var actualFailedIds: [UUID] {
        return [] // 默認空陣列
    }

    // 空的編碼/解碼，讓它接受任何JSON結構
    init(from decoder: Decoder) throws {
        // 不解析任何特定字段，接受所有JSON
    }

    func encode(to encoder: Encoder) throws {
        // 空的編碼
    }
}

// MARK: - 結算相關模型

struct CompletedDay: Codable {
    let id: UUID
    let userId: UUID
    let date: Date
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case date
        case createdAt = "created_at"
    }
}

struct MarkCompletedDayRequest: Codable {
    let date: Date
}

struct Settlement: Codable {
    let id: UUID
    let userId: UUID
    let settlementDate: Date
    let totalTasks: Int
    let completedTasks: Int
    let completionRate: Double
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case settlementDate = "settlement_date"
        case totalTasks = "total_tasks"
        case completedTasks = "completed_tasks"
        case completionRate = "completion_rate"
        case createdAt = "created_at"
    }
}

struct CreateSettlementRequest: Codable {
    let settlementDate: Date
    let totalTasks: Int
    let completedTasks: Int
    let completionRate: Double

    enum CodingKeys: String, CodingKey {
        case settlementDate = "settlement_date"
        case totalTasks = "total_tasks"
        case completedTasks = "completed_tasks"
        case completionRate = "completion_rate"
    }
}

// MARK: - 健康檢查模型

struct HealthResponse: Codable {
    let status: String
    let timestamp: Date
}

// MARK: - 錯誤響應模型

struct APIErrorResponse: Codable {
    let message: String
    let error: String?
}

// MARK: - 轉換擴展

extension APITodoItem {
    /// 轉換為本地TodoItem
    func toTodoItem() -> TodoItem {
        // 🆕 處理後端完全遷移到新字段的情況
        let finalTaskType: TaskType
        let finalCompletionStatus: CompletionStatus
        let finalStatus: TodoStatus

        if let apiTaskType = self.taskType, let apiCompletionStatus = self.completionStatus {
            // 後端已提供新字段，優先使用
            finalTaskType = apiTaskType
            finalCompletionStatus = apiCompletionStatus

            // 從新字段推導舊狀態（向後兼容）
            finalStatus = self.status ?? derivedStatusFromNewFields(taskType: apiTaskType, completionStatus: apiCompletionStatus, taskDate: taskDate)
        } else if let oldStatus = self.status {
            // 回退到舊狀態，推導新字段
            let (derivedTaskType, derivedCompletionStatus) = TodoItem.deriveNewFields(from: oldStatus, taskDate: taskDate)
            finalTaskType = derivedTaskType
            finalCompletionStatus = derivedCompletionStatus
            finalStatus = oldStatus
        } else {
            // 極端情況：既沒有新字段也沒有舊狀態，使用預設值
            finalTaskType = taskDate != nil ? .scheduled : .memo
            finalCompletionStatus = .pending
            finalStatus = .toBeStarted
        }

        return TodoItem(
            id: id,
            userID: userId?.uuidString ?? "unknown_user",
            title: title,
            priority: priority,
            isPinned: isPinned,
            taskDate: taskDate,
            note: note,
            taskType: finalTaskType,
            completionStatus: finalCompletionStatus,
            status: finalStatus,
            createdAt: createdAt,
            updatedAt: updatedAt,
            correspondingImageID: correspondingImageId
        )
    }

    // 🆕 從新字段推導舊狀態的輔助方法
    private func derivedStatusFromNewFields(taskType: TaskType, completionStatus: CompletionStatus, taskDate: Date?) -> TodoStatus {
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
}

extension TodoItem {
    /// 轉換為創建請求
    func toCreateRequest() -> CreateTodoRequest {
        return CreateTodoRequest(
            title: title,
            note: note,
            priority: priority,
            isPinned: isPinned,
            taskDate: taskDate,
            taskType: taskType, // 🆕 包含新的任務類型
            completionStatus: completionStatus, // 🆕 包含新的完成狀態
            status: status,
            correspondingImageId: correspondingImageID
        )
    }

    /// 轉換為更新請求
    func toUpdateRequest() -> UpdateTodoRequest {
        return UpdateTodoRequest(
            title: title,
            note: note,
            priority: priority,
            isPinned: isPinned,
            taskDate: taskDate,
            taskType: taskType, // 🆕 包含新的任務類型
            completionStatus: completionStatus, // 🆕 包含新的完成狀態
            status: status,
            correspondingImageId: correspondingImageID
        )
    }
}
