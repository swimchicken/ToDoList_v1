import Foundation

// MARK: - Gemini API Data Structures

// 這個結構對應 Gemini API 回傳的整個 JSON 物件
struct GeminiResponse: Codable {
    let tasks: [TaskDetail]
    
    // 我們可以添加一個計算屬性來符合您最初的需求
    var taskCount: Int {
        return tasks.count
    }
}

// 這個結構代表單一一個被辨識出來的任務
struct TaskDetail: Codable, Identifiable {
    // Identifiable 協議需要一個 id 屬性，我們用 UUID 自動產生
    let id = UUID()
    let title: String
    let notes: String? // 備註可能是可選的
    let date: String?  // 日期可能是可選的
    let time: String?  // 時間可能是可選的
    
    // 為了讓 Codable 能正確運作，我們需要告訴它 JSON 的 key 和我們的屬性名如何對應
    private enum CodingKeys: String, CodingKey {
        case title, notes, date, time
    }
}


// MARK: - Gemini Service Class

class GeminiService: ObservableObject {
    
    // 請在此處貼上您的 Gemini API 金鑰
    private let apiKey = "AIzaSyCBn5Pbv6GKjItOsMIloa_nUTry-x5qtsw"
    
    // 修正：將模型名稱更新為 gemini-2.5-flash-lite
    private let apiURL = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent")!

    /// 分析使用者輸入的文字，並回傳結構化的任務資料
    /// - Parameters:
    ///   - text: 使用者輸入的文字或語音轉文字的結果
    ///   - completion: 完成時的回調，回傳 Result 型別，包含成功時的 GeminiResponse 或失敗時的 Error
    func analyzeText(_ text: String, completion: @escaping (Result<GeminiResponse, Error>) -> Void) {
        
        // 準備網路請求
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        
        // 使用 DateFormatter 來產生正確的日期字串
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        let currentDateString = formatter.string(from: Date())
        
        // 修正：更新 prompt 指令
        let prompt = """
        Analyze the following text which contains one or more tasks. Today's date is \(currentDateString).
        Extract the title, notes, date, and time for each task.
        The "title" should only be the core action (e.g., "開會", "買東西").
        Information about "with whom" or "where" should be included in the "notes".
        The date should be in "YYYY-MM-DD" format.
        The time should be in "HH:mm" format (24-hour).
        If any field is not mentioned, return it as null.
        
        Your response MUST be a valid JSON object that only contains a key "tasks" which is an array of task objects. Do not include any other text or markdown formatting.
        
        Example 1:
        Text: "提醒我明天下午三點跟John在會議室開會，然後下週五要去工學院C317交報告"
        Response:
        {
          "tasks": [
            {
              "title": "開會",
              "notes": "跟John在會議室",
              "date": "2025-08-04",
              "time": "15:00"
            },
            {
              "title": "交報告",
              "notes": "去工學院C317",
              "date": "2025-08-15",
              "time": null
            }
          ]
        }
        
        Example 2:
         Text: "我明天下午三點和禮拜三晚上各有一場會議要開，明天的是和林泳慶，然後禮拜三的是和教授"
         Response:
         {
           "tasks": [
             {
               "title": "開會",
               "notes": "和林泳慶",
               "date": "2025-08-04",
               "time": "15:00"
             },
             {
               "title": "交報告",
               "notes": "和教授",
               "date": "2025-08-15",
               "time": null
             }
           ]
         }       
        
        
        Now, analyze this text: "\(text)"
        """
        
        // 建立請求的 JSON Body
        let requestBody: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            "generationConfig": [
                "responseMimeType": "application/json"
            ]
        ]
        
        // 將 requestBody 轉換為 JSON data
        guard let httpBody = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(.failure(NSError(domain: "GeminiService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize request body"])))
            return
        }
        
        request.httpBody = httpBody
        
        // 在終端機印出準備發送的 JSON 請求
        print("--- Sending to Gemini ---")
        print(String(data: httpBody, encoding: .utf8) ?? "Could not print request body")
        print("-------------------------")
        
        // 發送網路請求
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "GeminiService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                }
                return
            }
            
            // 在終端機印出收到的原始 JSON 回應
            print("--- Gemini Raw Response ---")
            print(String(data: data, encoding: .utf8) ?? "Could not print response data")
            print("---------------------------")
            
            // 解析 Gemini API 的回傳內容
            do {
                // Gemini 的回傳格式是巢狀的，我們先解析最外層
                if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let candidates = jsonObject["candidates"] as? [[String: Any]],
                   let firstCandidate = candidates.first,
                   let content = firstCandidate["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let firstPart = parts.first,
                   let textData = firstPart["text"] as? String {
                    
                    // 將取出的純文字 JSON 再解碼成我們定義的 GeminiResponse 結構
                    if let responseData = textData.data(using: .utf8) {
                        let decoder = JSONDecoder()
                        let geminiResponse = try decoder.decode(GeminiResponse.self, from: responseData)
                        DispatchQueue.main.async {
                            completion(.success(geminiResponse))
                        }
                    } else {
                        throw NSError(domain: "GeminiService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to convert response text to data"])
                    }
                } else {
                    // 如果 Gemini 回傳錯誤訊息，也印出來
                    if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("❌ Gemini returned an error or unexpected structure: \(jsonObject)")
                    }
                    throw NSError(domain: "GeminiService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON structure from Gemini"])
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
}
