//
//  APIModels.swift
//  ToDoList_v1
//
//  API數據模型定義
//

import Foundation

// MARK: - 認證相關模型

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
    let status: TodoStatus
    let correspondingImageId: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title, note, priority
        case isPinned = "is_pinned"
        case taskDate = "task_date"
        case status
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
    let status: TodoStatus
    let correspondingImageId: String

    enum CodingKeys: String, CodingKey {
        case title, note, priority
        case isPinned = "is_pinned"
        case taskDate = "task_date"
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
    let status: TodoStatus?
    let correspondingImageId: String?

    enum CodingKeys: String, CodingKey {
        case title, note, priority
        case isPinned = "is_pinned"
        case taskDate = "task_date"
        case status
        case correspondingImageId = "corresponding_image_id"
    }
}

struct UpdateStatusRequest: Codable {
    let status: TodoStatus
}

// MARK: - 批量操作模型

struct BatchUpdateRequest: Codable {
    let updates: [BatchUpdateItem]
}

struct BatchUpdateItem: Codable {
    let id: UUID
    let data: UpdateTodoRequest
}

struct BatchDeleteRequest: Codable {
    let ids: [UUID]
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
        return TodoItem(
            id: id,
            userID: userId?.uuidString ?? "unknown_user",
            title: title,
            priority: priority,
            isPinned: isPinned,
            taskDate: taskDate,
            note: note,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            correspondingImageID: correspondingImageId
        )
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
            status: status,
            correspondingImageId: correspondingImageID
        )
    }
}