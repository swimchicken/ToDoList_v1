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

    // 防止重複請求的機制
    private var ongoingUpdateRequests: Set<UUID> = []
    private let requestQueue = DispatchQueue(label: "APIDataManager.requests", attributes: .concurrent)

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

        // 🔧 註解自動 Widget 更新，避免觸發額外 API 調用干擾樂觀更新
        // Widget 會在其他時機（如應用啟動、手動刷新）更新
        // await updateWidgetData()

        return newItem
    }

    /// 更新TodoItem（帶去重機制）
    func updateTodoItem(_ item: TodoItem) async throws -> TodoItem {
        // 檢查是否已有相同任務的更新請求正在進行
        return try await withCheckedThrowingContinuation { continuation in
            requestQueue.async(flags: .barrier) {
                // 如果已經有相同任務的請求正在進行，拒絕新請求
                if self.ongoingUpdateRequests.contains(item.id) {
                    // 返回一個自訂錯誤表示重複請求
                    let duplicateError = NSError(domain: "APIDataManager", code: 409, userInfo: [NSLocalizedDescriptionKey: "重複的更新請求"])
                    continuation.resume(throwing: duplicateError)
                    return
                }

                // 標記該任務正在更新
                self.ongoingUpdateRequests.insert(item.id)

                // 執行實際的更新請求
                Task {
                    do {
                        let updateRequest = item.toUpdateRequest()
                        let apiItem = try await self.apiManager.updateTodo(id: item.id, updateRequest)
                        let updatedItem = apiItem.toTodoItem()

                        // Widget 數據將在結算完成時統一更新
                        // await self.updateWidgetData()

                        // 移除請求追蹤
                        await self.removeOngoingRequest(item.id)

                        continuation.resume(returning: updatedItem)
                    } catch {
                        // 移除請求追蹤
                        await self.removeOngoingRequest(item.id)
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    /// 安全地移除正在進行的請求追蹤
    private func removeOngoingRequest(_ id: UUID) async {
        await withCheckedContinuation { continuation in
            requestQueue.async(flags: .barrier) {
                self.ongoingUpdateRequests.remove(id)
                continuation.resume()
            }
        }
    }

    /// 刪除TodoItem
    func deleteTodoItem(withID id: UUID) async throws {
        try await apiManager.deleteTodo(id: id)

        // 🔧 註解自動 Widget 更新，避免觸發額外 API 調用
        // await updateWidgetData()
    }

    /// 快速更新狀態
    func updateTodoStatus(id: UUID, status: TodoStatus) async throws -> TodoItem {
        let apiItem = try await apiManager.updateTodoStatus(id: id, status: status)
        let updatedItem = apiItem.toTodoItem()

        // 🔧 註解自動 Widget 更新，避免觸發額外 API 調用
        // await updateWidgetData()

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
                // 批次更新部分失敗，記錄失敗信息
        } else {
            // 批次更新全部成功
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
            // 更新Widget數據失敗，靜默處理
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
                // 發生錯誤，返回空數組
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

    /// 手動觸發 Widget 數據更新（用於結算完成等場景）
    func forceUpdateWidgetData() async {
        await updateWidgetData()
        // 手動觸發 Widget 數據更新完成
    }
}