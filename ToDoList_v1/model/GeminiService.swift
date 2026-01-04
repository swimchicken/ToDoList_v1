import Foundation

// MARK: - App Configuration & Secrets
/// 一個專門用來安全讀取專案機密資訊和設定的物件。
enum AppSecrets {
    /// 從 Info.plist 讀取 Gemini API Key。
    static let apiKey: String = {
        guard let key = value(for: "GeminiApiKey") else {
            fatalError("無法在 Info.plist 中找到 Key 'GeminiApiKey'，請檢查您的設定。")
        }
        return key
    }()

    /// API 的 URL 位址。
    static let apiURL: URL = {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
        guard let url = URL(string: urlString) else {
            fatalError("內部 URL 字串無效: \(urlString)")
        }
        return url
    }()

    /// 一個統一的輔助函式，用來從 Info.plist 讀取值。
    private static func value(for key: String) -> String? {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }
        if rawValue.starts(with: "$(") {
            return nil
        }
        return rawValue.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }
}


// MARK: - Gemini API Response Handling
/// ✨✨✨ 修改 #1: 改造 GeminiResponse，使其成為專用的解析與轉換器 ✨✨✨
/// 這個結構現在只負責一件事：將 API 回傳的 JSON，轉換成 App 標準的 `[TodoItem]` 格式。
struct GeminiResponse: Decodable {
    
    /// 提供一個計算屬性，直接將解碼後的資料轉換成 `[TodoItem]`。這是此結構最主要的功能。
    var asTodoItems: [TodoItem] {
        return geminiTasks.map { geminiTask -> TodoItem in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            
            var finalDate: Date? = nil
            if let dateString = geminiTask.date {
                let timeString = (geminiTask.time?.isEmpty ?? true) ? "00:00" : geminiTask.time!
                finalDate = dateFormatter.date(from: "\(dateString) \(timeString)")
            }

            // 使用您在 `TodoItem.swift` 中定義的結構來建立新物件
            return TodoItem(
                id: UUID(),
                userID: "user123", // TODO: 請根據您的登入系統填入實際的用戶 ID
                title: geminiTask.title,
                priority: 0,
                isPinned: false,
                taskDate: finalDate,
                note: geminiTask.notes ?? "",
                taskType: finalDate != nil ? .scheduled : .memo,
                completionStatus: .pending,
                status: .toBeStarted,
                createdAt: Date(),
                updatedAt: Date(),
                correspondingImageID: ""
            )
        }
    }
    
    // --- 內部實作細節 ---
    private struct GeminiTask: Decodable {
        let title: String
        let notes: String?
        let date: String?
        let time: String?
    }
    
    private let geminiTasks: [GeminiTask]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.geminiTasks = try container.decode([GeminiTask].self, forKey: .tasks)
    }
    
    private enum CodingKeys: String, CodingKey {
        case tasks
    }
}


// MARK: - Gemini Service Class
class GeminiService: ObservableObject {
    
    private let apiKey = AppSecrets.apiKey
    private let apiURL = AppSecrets.apiURL
    
    // 重試配置
        private let maxRetries = 5
        private let minRetries = 3
        private let retryableStatusCodes: Set<Int> = [429, 500, 502, 503, 504]
    
    // 當前正在執行的請求
    private var currentTask: URLSessionDataTask?
    private var isCancelled = false

    /// 取消當前的 API 請求
    func cancelRequest() {
        isCancelled = true
        currentTask?.cancel()
        currentTask = nil
    }
    
    func analyzeText(_ text: String, completion: @escaping (Result<[TodoItem], Error>) -> Void) {
        isCancelled = false  // 重置取消標記
        performRequestWithRetry(text: text, attemptNumber: 1, completion: completion)
    }
    
    /// 執行請求並處理重試邏輯
    private func performRequestWithRetry(
        text: String,
        attemptNumber: Int,
        completion: @escaping (Result<[TodoItem], Error>) -> Void
    ) {
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.timeoutInterval = 30
        
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        let currentDateString = formatter.string(from: Date())
        
        let prompt = """
                Analyze the following text which contains one or more tasks. Today's date is \(currentDateString).
                Extract the title, notes, date, and time for each task.
                The "title" should be the main task or event, including the action and its direct object (e.g., "開會", "買東西", "做好卡片").
                Only secondary contextual information, like "with whom" or "where", should be included in the "notes". If the text only contains the main task, "notes" should be null.
                The date should be in "YYYY-MM-DD" format.
                The time should be in "HH:mm" format (24-hour).
                If any field is not mentioned, return it as null.
                
                Your response MUST be a valid JSON object that only contains a key "tasks" which is an array of task objects. Do not include any other text or markdown formatting.
                
                Example 1:
                Text: "提醒我明天下午三點跟John在會議室開會，然後下週五要去工學院C317交報告"
                Response:
                {
                  "tasks": [
                    { "title": "開會", "notes": "跟John在會議室", "date": "2025-08-15", "time": "15:00" },
                    { "title": "交報告", "notes": "去工學院C317", "date": "2025-08-22", "time": null }
                  ]
                }
                
                Example 2:
                Text: "記得做好卡片"
                Response:
                {
                  "tasks": [
                    { "title": "做好卡片", "notes": null, "date": null, "time": null }
                  ]
                }
                
                Now, analyze this text: "\(text)"
                """
        
        let requestBody: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["responseMimeType": "application/json"]
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(.failure(NSError(domain: "GeminiService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize request body"])))
            return
        }
        
        request.httpBody = httpBody
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // 清除已完成的 task
            self.currentTask = nil
            
            
            // 檢查 HTTP 狀態碼
            if let httpResponse = response as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                
                // 如果是可重試的錯誤且未達最大重試次數
                if self.retryableStatusCodes.contains(statusCode) && attemptNumber < self.maxRetries {
                    let delay = self.calculateBackoffDelay(attemptNumber: attemptNumber)
                    
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        self.performRequestWithRetry(text: text, attemptNumber: attemptNumber + 1, completion: completion)
                    }
                    return
                }
                
                // 達到最小重試次數但仍失敗
                if self.retryableStatusCodes.contains(statusCode) && attemptNumber >= self.minRetries {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(
                            domain: "GeminiService",
                            code: statusCode,
                            userInfo: [NSLocalizedDescriptionKey: "服務暫時無法使用，已重試 \(attemptNumber) 次（HTTP \(statusCode)）"]
                        )))
                    }
                    return
                }
            }
            
            // 處理網絡錯誤
            if let error = error {
                // 檢查是否為用戶主動取消
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                    return
                }
                
                // 檢查取消標記
                if self.isCancelled {
                    return
                }
                
                
                if attemptNumber < self.maxRetries {
                    let delay = self.calculateBackoffDelay(attemptNumber: attemptNumber)
                    
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        self.performRequestWithRetry(text: text, attemptNumber: attemptNumber + 1, completion: completion)
                    }
                    return
                }
                
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "GeminiService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                }
                return
            }
            
            // 檢查是否已被取消
            if self.isCancelled {
                return
            }
            
            // 成功收到資料
            self.parseResponse(data: data, completion: completion)
            
        }
        
        // 保存當前的 task 以便取消
        currentTask = task
        task.resume()
    }
    
    /// 計算指數退避延遲時間
    private func calculateBackoffDelay(attemptNumber: Int) -> TimeInterval {
        let baseDelay: TimeInterval = 1.0
        let maxDelay: TimeInterval = 16.0
        let delay = min(baseDelay * pow(2.0, Double(attemptNumber - 1)), maxDelay)
        
        // 加入隨機抖動避免多個請求同時重試
        let jitter = Double.random(in: 0...0.3) * delay
        return delay + jitter
    }
    
    /// 解析 API 回應
    private func parseResponse(data: Data, completion: @escaping (Result<[TodoItem], Error>) -> Void) {
        // 最後檢查：即使收到資料，如果已取消就不處理
        guard !isCancelled else {
            return
        }
        
        do {
            if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = jsonObject["candidates"] as? [[String: Any]],
               let firstCandidate = candidates.first,
               let content = firstCandidate["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let firstPart = parts.first,
               let textData = firstPart["text"] as? String {
                
                if let responseData = textData.data(using: .utf8) {
                    let decoder = JSONDecoder()
                    let geminiResponse = try decoder.decode(GeminiResponse.self, from: responseData)
                    
                    DispatchQueue.main.async {
                        completion(.success(geminiResponse.asTodoItems))
                    }
                } else {
                    throw NSError(domain: "GeminiService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to convert response text to data"])
                }
            } else {
                if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                }
                throw NSError(domain: "GeminiService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON structure from Gemini"])
            }
        } catch {
            DispatchQueue.main.async { completion(.failure(error)) }
        }
    }
}
