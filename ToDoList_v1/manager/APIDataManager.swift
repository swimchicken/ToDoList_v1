//
//  APIDataManager.swift
//  ToDoList_v1
//
//  API數據管理器 - 替換LocalDataManager的API版本
//

import Foundation

class APIDataManager: ObservableObject {
    static let shared = APIDataManager()

    private let apiManager = APIManager.shared

    private init() {}

    // MARK: - TodoItem管理

    /// 獲取所有TodoItems
    func getAllTodoItems() async throws -> [TodoItem] {
        let apiItems = try await apiManager.fetchTodos()
        return apiItems.map { $0.toTodoItem() }
    }

    /// 獲取指定日期的TodoItems
    func getTodoItems(for date: Date) async throws -> [TodoItem] {
        let apiItems = try await apiManager.fetchTodos(date: date)
        return apiItems.map { $0.toTodoItem() }
    }

    /// 獲取指定狀態的TodoItems
    func getTodoItems(status: TodoStatus) async throws -> [TodoItem] {
        let apiItems = try await apiManager.fetchTodos(status: status)
        return apiItems.map { $0.toTodoItem() }
    }

    /// 創建TodoItem
    func addTodoItem(_ item: TodoItem) async throws -> TodoItem {
        let createRequest = item.toCreateRequest()
        let apiItem = try await apiManager.createTodo(createRequest)
        let newItem = apiItem.toTodoItem()

        // 更新Widget數據
        await updateWidgetData()

        return newItem
    }

    /// 更新TodoItem
    func updateTodoItem(_ item: TodoItem) async throws -> TodoItem {
        let updateRequest = item.toUpdateRequest()
        let apiItem = try await apiManager.updateTodo(id: item.id, updateRequest)
        let updatedItem = apiItem.toTodoItem()

        // 更新Widget數據
        await updateWidgetData()

        return updatedItem
    }

    /// 刪除TodoItem
    func deleteTodoItem(withID id: UUID) async throws {
        try await apiManager.deleteTodo(id: id)

        // 更新Widget數據
        await updateWidgetData()
    }

    /// 快速更新狀態
    func updateTodoStatus(id: UUID, status: TodoStatus) async throws -> TodoItem {
        let apiItem = try await apiManager.updateTodoStatus(id: id, status: status)
        let updatedItem = apiItem.toTodoItem()

        // 更新Widget數據
        await updateWidgetData()

        return updatedItem
    }

    // MARK: - 用戶管理

    /// 獲取用戶資料
    func getUserProfile() async throws -> User {
        return try await apiManager.getUserProfile()
    }

    /// 更新用戶資料
    func updateUserProfile(name: String) async throws -> User {
        return try await apiManager.updateUserProfile(name: name, avatarUrl: nil)
    }

    // MARK: - 認證相關

    /// Apple登入
    func loginWithApple(identityToken: String, name: String? = nil) async throws -> AuthResponse {
        return try await apiManager.loginWithApple(identityToken: identityToken, name: name)
    }

    /// Google登入
    func loginWithGoogle(idToken: String) async throws -> AuthResponse {
        return try await apiManager.loginWithGoogle(idToken: idToken)
    }


    // MARK: - 批量操作（用於結算等場景）

    /// 批量創建TodoItems
    func batchCreateTodoItems(_ items: [TodoItem]) async throws -> [TodoItem] {
        let createRequests = items.map { $0.toCreateRequest() }
        let apiItems = try await apiManager.batchCreateTodos(createRequests)
        let newItems = apiItems.map { $0.toTodoItem() }

        // 更新Widget數據
        await updateWidgetData()

        return newItems
    }

    /// 批量更新TodoItems（結算時移動任務到明天）
    func batchUpdateTodoItems(_ items: [TodoItem]) async throws -> [TodoItem] {
        let batchResponse = try await apiManager.batchUpdateTodos(items)

        // 檢查是否有失敗的更新
        if batchResponse.actualFailedCount > 0 {
            print("⚠️ 批次更新部分失敗: 成功 \(batchResponse.actualSuccessCount) 個，失敗 \(batchResponse.actualFailedCount) 個")
            print("失敗的ID: \(batchResponse.actualFailedIds)")
        } else {
            print("✅ 批次更新全部成功: \(batchResponse.actualSuccessCount) 個任務")
        }

        // 更新Widget數據
        await updateWidgetData()

        // 返回成功更新的項目
        let successfulItems = items.filter { !batchResponse.actualFailedIds.contains($0.id) }
        return successfulItems
    }

    /// 批量刪除TodoItems
    func batchDeleteTodoItems(ids: [UUID]) async throws {
        try await apiManager.batchDeleteTodos(ids)

        // 更新Widget數據
        await updateWidgetData()
    }

    // MARK: - 結算和統計功能

    /// 獲取已完成的日期列表
    func getCompletedDays() async throws -> [CompletedDay] {
        return try await apiManager.getCompletedDays()
    }

    /// 標記某日為已完成
    func markDayAsCompleted(date: Date) async throws -> CompletedDay {
        return try await apiManager.markDayAsCompleted(date: date)
    }

    /// 創建結算記錄
    func createSettlement(date: Date, totalTasks: Int, completedTasks: Int, completionRate: Double) async throws -> Settlement {
        let request = CreateSettlementRequest(
            settlementDate: date,
            totalTasks: totalTasks,
            completedTasks: completedTasks,
            completionRate: completionRate
        )
        return try await apiManager.createSettlement(data: request)
    }

    /// 獲取最近的結算記錄
    func getLatestSettlement() async throws -> Settlement? {
        return try await apiManager.getLatestSettlement()
    }

    // MARK: - 系統功能

    /// 健康檢查
    func healthCheck() async throws -> HealthResponse {
        return try await apiManager.healthCheck()
    }

    // MARK: - 用戶狀態管理

    /// 檢查是否已登入
    func isLoggedIn() -> Bool {
        return apiManager.getAuthToken() != nil
    }

    /// 登出
    func logout() {
        apiManager.clearAuthToken()
    }

    // MARK: - Widget數據更新

    /// 更新Widget數據（靜默模式）
    private func updateWidgetData() async {
        do {
            let allTasks = try await getAllTodoItems()
            // 靜默更新Widget，不打印日誌
            WidgetFileManager.shared.saveTodayTasksToFileQuietly(allTasks)
        } catch {
            // 只在錯誤時才打印日誌
            print("❌ 更新Widget數據失敗: \(error.localizedDescription)")
        }
    }
}

// MARK: - 同步方法（兼容現有代碼）

extension APIDataManager {
    /// 同步版本的getAllTodoItems（兼容現有代碼）
    func getAllTodoItems() -> [TodoItem] {
        // 使用Task來處理async調用
        var result: [TodoItem] = []
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                result = try await self.getAllTodoItems()
            } catch {
                print("❌ APIDataManager getAllTodoItems error: \(error)")
                result = []
            }
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    /// 同步版本的addTodoItem
    func addTodoItem(_ item: TodoItem, completion: @escaping (Result<TodoItem, Error>) -> Void) {
        Task {
            do {
                let newItem = try await self.addTodoItem(item)
                DispatchQueue.main.async {
                    completion(.success(newItem))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    /// 同步版本的updateTodoItem
    func updateTodoItem(_ item: TodoItem, completion: @escaping (Result<TodoItem, Error>) -> Void) {
        Task {
            do {
                let updatedItem = try await self.updateTodoItem(item)
                DispatchQueue.main.async {
                    completion(.success(updatedItem))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    /// 同步版本的deleteTodoItem
    func deleteTodoItem(withID id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try await self.deleteTodoItem(withID: id)
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    /// 同步版本的updateTodoStatus
    func updateTodoStatus(id: UUID, status: TodoStatus, completion: @escaping (Result<TodoItem, Error>) -> Void) {
        Task {
            do {
                let updatedItem = try await self.updateTodoStatus(id: id, status: status)
                DispatchQueue.main.async {
                    completion(.success(updatedItem))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}

// MARK: - DataSyncManager兼容接口

extension APIDataManager {
    /// 模擬fetchTodoItems（DataSyncManager接口兼容）
    func fetchTodoItems(completion: @escaping (Result<[TodoItem], Error>) -> Void) {
        Task {
            do {
                let items = try await self.getAllTodoItems()
                DispatchQueue.main.async {
                    // 發送數據刷新通知
                    NotificationCenter.default.post(
                        name: Notification.Name("TodoItemsDataRefreshed"),
                        object: nil
                    )
                    completion(.success(items))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}