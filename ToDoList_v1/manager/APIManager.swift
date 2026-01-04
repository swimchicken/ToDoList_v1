//
//  APIManager.swift
//  ToDoList_v1
//
//  API管理器 - 處理所有後端API調用
//

import Foundation

class APIManager {
    static let shared = APIManager()

    private let baseURL = "https://api.to-do-alarm.com"
    private var authToken: String?

    private init() {}

    // MARK: - 認證管理

    func setAuthToken(_ token: String) {
        self.authToken = token
        UserDefaults.standard.set(token, forKey: "api_auth_token")
    }

    func getAuthToken() -> String? {
        if let token = authToken {
            return token
        }
        let savedToken = UserDefaults.standard.string(forKey: "api_auth_token")
        authToken = savedToken
        return savedToken
    }

    func clearAuthToken() {
        authToken = nil
        UserDefaults.standard.removeObject(forKey: "api_auth_token")
    }

    // MARK: - 網路請求基礎方法

    private func createRequest(url: URL, method: HTTPMethod, body: Data? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // 添加認證header
        if let token = getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = body
        }

        return request
    }

    private func performRequest<T: Codable>(_ request: URLRequest, responseType: T.Type) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 處理API回傳資料

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // 檢查HTTP回應狀態

        if httpResponse.statusCode >= 400 {
            if let errorData = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw APIError.serverError(errorData.message)
            }
            throw APIError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // 嘗試多種日期格式
            let formatters = [
                // ISO8601 with fractional seconds (微秒)
                {
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    return formatter
                }(),
                // ISO8601 with Z (standard)
                ISO8601DateFormatter(),
                // ISO8601 without Z
                {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                    formatter.timeZone = TimeZone.current
                    return formatter
                }(),
                // Without T separator
                {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    formatter.timeZone = TimeZone.current
                    return formatter
                }(),
                // Date only
                {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    formatter.timeZone = TimeZone.current
                    return formatter
                }()
            ]

            for formatter in formatters {
                if let isoFormatter = formatter as? ISO8601DateFormatter {
                    if let date = isoFormatter.date(from: dateString) {
                        return date
                    }
                } else if let dateFormatter = formatter as? DateFormatter {
                    if let date = dateFormatter.date(from: dateString) {
                        return date
                    }
                }
            }

            // 無法解析日期格式
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "無法解析日期: \(dateString)")
        }

        do {
            let result = try decoder.decode(responseType, from: data)
            return result
        } catch {
            // JSON解碼失敗
            throw APIError.decodingError(error)
        }
    }

    // MARK: - 認證API

    func loginWithApple(identityToken: String, name: String? = nil) async throws -> AuthResponse {
        let url = URL(string: "\(baseURL)/auth/apple")!
        let body = AppleLoginRequest(identityToken: identityToken, name: name)
        let requestData = try JSONEncoder().encode(body)
        let request = createRequest(url: url, method: .POST, body: requestData)

        let response: AuthResponse = try await performRequest(request, responseType: AuthResponse.self)
        setAuthToken(response.token)
        return response
    }

    func loginWithGoogle(idToken: String) async throws -> AuthResponse {
        let url = URL(string: "\(baseURL)/auth/google")!
        let body = GoogleLoginRequest(idToken: idToken)
        let requestData = try JSONEncoder().encode(body)
        let request = createRequest(url: url, method: .POST, body: requestData)

        let response: AuthResponse = try await performRequest(request, responseType: AuthResponse.self)
        setAuthToken(response.token)
        return response
    }

    func getUserProfile() async throws -> User {
        let url = URL(string: "\(baseURL)/users/me")!
        let request = createRequest(url: url, method: .GET)

        return try await performRequest(request, responseType: User.self)
    }

    func updateUserProfile(name: String?, avatarUrl: String? = nil) async throws -> User {
        let url = URL(string: "\(baseURL)/users/me")!
        let body = UpdateUserRequest(name: name, avatarUrl: avatarUrl)
        let requestData = try JSONEncoder().encode(body)
        let request = createRequest(url: url, method: .PATCH, body: requestData)

        return try await performRequest(request, responseType: User.self)
    }

    // MARK: - TodoItem API

    func fetchTodos(date: Date? = nil, status: TodoStatus? = nil) async throws -> [APITodoItem] {
        var urlComponents = URLComponents(string: "\(baseURL)/todos")!
        var queryItems: [URLQueryItem] = []

        if let date = date {
            let formatter = ISO8601DateFormatter()
            queryItems.append(URLQueryItem(name: "date", value: formatter.string(from: date)))
        }

        if let status = status {
            queryItems.append(URLQueryItem(name: "status", value: status.rawValue))
        }

        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }

        let request = createRequest(url: urlComponents.url!, method: .GET)
        return try await performRequest(request, responseType: [APITodoItem].self)
    }

    func createTodo(_ todo: CreateTodoRequest) async throws -> APITodoItem {
        let url = URL(string: "\(baseURL)/todos")!

        // 準備請求數據
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let requestData = try encoder.encode(todo)

        let request = createRequest(url: url, method: .POST, body: requestData)

        return try await performRequest(request, responseType: APITodoItem.self)
    }

    func updateTodo(id: UUID, _ todo: UpdateTodoRequest) async throws -> APITodoItem {
        let url = URL(string: "\(baseURL)/todos/\(id.uuidString)")!
        let updateEncoder = JSONEncoder()
        updateEncoder.dateEncodingStrategy = .iso8601
        let requestData = try updateEncoder.encode(todo)
        let request = createRequest(url: url, method: .PUT, body: requestData)

        return try await performRequest(request, responseType: APITodoItem.self)
    }

    func deleteTodo(id: UUID) async throws {
        let url = URL(string: "\(baseURL)/todos/\(id.uuidString)")!
        let request = createRequest(url: url, method: .DELETE)

        let _: EmptyResponse = try await performRequest(request, responseType: EmptyResponse.self)
    }

    func updateTodoStatus(id: UUID, status: TodoStatus) async throws -> APITodoItem {
        let url = URL(string: "\(baseURL)/todos/\(id.uuidString)/status")!
        let body = UpdateStatusRequest(status: status)
        let requestData = try JSONEncoder().encode(body)
        let request = createRequest(url: url, method: .PATCH, body: requestData)

        return try await performRequest(request, responseType: APITodoItem.self)
    }

    // MARK: - 批量操作

    func batchCreateTodos(_ todos: [CreateTodoRequest]) async throws -> [APITodoItem] {
        let url = URL(string: "\(baseURL)/todos/batch")!
        let requestData = try JSONEncoder().encode(todos)
        let request = createRequest(url: url, method: .POST, body: requestData)

        return try await performRequest(request, responseType: [APITodoItem].self)
    }

    func batchUpdateTodos(_ todos: [TodoItem]) async throws -> BatchOperationResponse {
        let url = URL(string: "\(baseURL)/todos/batch")!

        let batchRequest = BatchUpdateRequest(items: todos.map { todo in
            BatchUpdateItem(
                id: todo.id,
                title: todo.title,
                status: todo.status.rawValue,
                task_date: todo.taskDate,
                priority: todo.priority,
                is_pinned: todo.isPinned,
                note: todo.note,
                corresponding_image_id: todo.correspondingImageID.isEmpty ? nil : todo.correspondingImageID
            )
        })

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let requestData = try encoder.encode(batchRequest)
        let request = createRequest(url: url, method: .PUT, body: requestData)

        return try await performRequest(request, responseType: BatchOperationResponse.self)
    }

    func batchDeleteTodos(_ ids: [UUID]) async throws {
        let url = URL(string: "\(baseURL)/todos/batch")!
        let body = BatchDeleteRequest(ids: ids)
        let requestData = try JSONEncoder().encode(body)
        let request = createRequest(url: url, method: .DELETE, body: requestData)

        let _: EmptyResponse = try await performRequest(request, responseType: EmptyResponse.self)
    }

    // MARK: - 結算和統計API

    func getCompletedDays() async throws -> [CompletedDay] {
        let url = URL(string: "\(baseURL)/users/me/completed-days")!
        let request = createRequest(url: url, method: .GET)

        return try await performRequest(request, responseType: [CompletedDay].self)
    }

    func markDayAsCompleted(date: Date) async throws -> CompletedDay {
        let url = URL(string: "\(baseURL)/users/me/completed-days")!
        let body = MarkCompletedDayRequest(date: date)
        let requestData = try JSONEncoder().encode(body)
        let request = createRequest(url: url, method: .POST, body: requestData)

        return try await performRequest(request, responseType: CompletedDay.self)
    }

    func createSettlement(data: CreateSettlementRequest) async throws -> Settlement {
        let url = URL(string: "\(baseURL)/users/me/settlements")!
        let requestData = try JSONEncoder().encode(data)
        let request = createRequest(url: url, method: .POST, body: requestData)

        return try await performRequest(request, responseType: Settlement.self)
    }

    func getLatestSettlement() async throws -> Settlement? {
        let url = URL(string: "\(baseURL)/users/me/settlements/latest")!
        let request = createRequest(url: url, method: .GET)

        // 這個端點可能返回空，所以要處理404情況
        do {
            return try await performRequest(request, responseType: Settlement.self)
        } catch APIError.httpError(404) {
            return nil
        }
    }

    // MARK: - 健康檢查

    func healthCheck() async throws -> HealthResponse {
        let url = URL(string: "\(baseURL)/health")!
        let request = createRequest(url: url, method: .GET)

        return try await performRequest(request, responseType: HealthResponse.self)
    }
    
    // MARK: - 新增的批量更新功能 (支援部分更新)

    /// 直接接收 BatchUpdateItem 列表進行更新 (用於 SettlementView 的日期遷移)
    func batchUpdateTasks(items: [BatchUpdateItem]) async throws -> BatchOperationResponse {
        // 1. 設定 URL
        // 注意：這裡使用您類別原本定義好的 baseURL
        // 根據您的現有結構，批量接口通常是 /todos/batch
        // 請確認後端：如果是部分更新 (Partial Update)，通常用 PATCH；如果後端只開了 POST/PUT 則改之
        let url = URL(string: "\(baseURL)/todos/batch")!
        
        // 2. 準備 Request Body
        let batchRequest = BatchUpdateRequest(items: items)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601 // 保持日期格式一致
        let requestData = try encoder.encode(batchRequest)
        
        // 3. 建立請求
        // 關鍵點：使用您現有的 createRequest 方法！
        // 它會自動幫您處理 "Authorization: Bearer token" 和 "Content-Type"
        let request = createRequest(url: url, method: .PUT, body: requestData)
        
        // 4. 執行請求
        // 關鍵點：使用您現有的 performRequest 方法！
        // 它會自動處理錯誤碼 (404, 500) 和 JSON 解碼
        return try await performRequest(request, responseType: BatchOperationResponse.self)
    }

}

// MARK: - 輔助類型

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case PATCH = "PATCH"
    case DELETE = "DELETE"
}

enum APIError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    case decodingError(Error)
    case noAuthToken

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "無效的響應"
        case .httpError(let code):
            return "HTTP錯誤: \(code)"
        case .serverError(let message):
            return "伺服器錯誤: \(message)"
        case .decodingError(let error):
            return "解碼錯誤: \(error.localizedDescription)"
        case .noAuthToken:
            return "未登入"
        }
    }
}

// MARK: - 空響應類型
struct EmptyResponse: Codable {}

