//
//  CloudKitService.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/5/6.
//

import Foundation
import CloudKit

class CloudKitService {
    // MARK: - Properties
    static let shared = CloudKitService()
    
    // 設定公開資料庫及識別碼
    private let container: CKContainer
    private let publicDatabase: CKDatabase
    private let privateDatabase: CKDatabase
    private let defaultZoneID = CKRecordZone.default().zoneID
    
    
    // MARK: - Initialization
    private init() {
        // 初始化 CloudKit 容器
        print("DEBUG: 正在初始化 CloudKitService")
        self.container = CKContainer(identifier: "iCloud.com.fcu.ToDolist1")
        self.publicDatabase = container.publicCloudDatabase
        self.privateDatabase = container.privateCloudDatabase // 添加私有數據庫
        print("DEBUG: CloudKit container 已初始化 - ID: \(container.containerIdentifier ?? "未知")")
        
        // 檢查 iCloud 狀態
        container.accountStatus { (status, error) in
            if let error = error {
                print("ERROR: 無法獲取 iCloud 帳戶狀態: \(error.localizedDescription)")
                return
            }
            
            switch status {
            case .available:
                print("INFO: iCloud 帳戶可用")
            case .noAccount:
                print("WARNING: 未登入 iCloud 帳戶")
            case .restricted:
                print("WARNING: iCloud 帳戶受限")
            case .couldNotDetermine:
                print("WARNING: 無法確定 iCloud 帳戶狀態")
            case .temporarilyUnavailable:
                print("WARNING: iCloud 帳戶暫時不可用")
            @unknown default:
                print("WARNING: 未知的 iCloud 帳戶狀態")
            }
        }
    }
    
    // MARK: - CRUD Operations
    
    /// 儲存待辦事項至 CloudKit
    /// - Parameters:
    ///   - todoItem: 待儲存的待辦事項
    ///   - completion: 完成後的回調，返回結果或錯誤
    func saveTodoItem(_ todoItem: TodoItem, completion: @escaping (Result<TodoItem, Error>) -> Void) {
        print("DEBUG: 開始儲存待辦事項 - ID: \(todoItem.id.uuidString), 標題: \(todoItem.title)")
        
        // 創建 CKRecord 物件
        let recordID = CKRecord.ID(recordName: todoItem.id.uuidString, zoneID: defaultZoneID)
        let record = CKRecord(recordType: "TodoItem", recordID: recordID)
        
        print("DEBUG: 使用 CKRecord.ID - recordName: \(recordID.recordName), zoneID: \(recordID.zoneID.zoneName)")
        
        // 設置記錄欄位
        record.setValue(todoItem.id.uuidString, forKey: "id")
        record.setValue(todoItem.userID, forKey: "userID")
        record.setValue(todoItem.title, forKey: "title")
        record.setValue(todoItem.priority, forKey: "priority")
        record.setValue(todoItem.isPinned, forKey: "isPinned")
        record.setValue(todoItem.taskDate, forKey: "taskDate")
        record.setValue(todoItem.note, forKey: "note")
        record.setValue(todoItem.status.rawValue, forKey: "status")
        record.setValue(todoItem.createdAt, forKey: "createdAt")
        record.setValue(todoItem.updatedAt, forKey: "updatedAt")
        record.setValue(todoItem.correspondingImageID, forKey: "correspondingImageID")
        
        print("DEBUG: CKRecord 已設置完所有欄位，準備儲存到 CloudKit")
        print("DEBUG: CloudKit container identifier: \(container.containerIdentifier ?? "未知")")
        
        // 儲存到 CloudKit
        privateDatabase.save(record) { (savedRecord, error) in
            if let error = error {
                let nsError = error as NSError
                print("ERROR: 儲存待辦事項失敗 - 錯誤代碼: \(nsError.code), 域: \(nsError.domain)")
                print("ERROR: 詳細錯誤: \(error.localizedDescription)")
                
                
                if nsError.domain == CKErrorDomain {
                    switch nsError.code {
                    case CKError.networkFailure.rawValue:
                        print("ERROR: 網絡連接失敗")
                    case CKError.networkUnavailable.rawValue:
                        print("ERROR: 網絡不可用")
                    case CKError.serverRejectedRequest.rawValue:
                        print("ERROR: 服務器拒絕請求")
                    case CKError.notAuthenticated.rawValue:
                        print("ERROR: 用戶未驗證，請確保已登入 iCloud 帳戶")
                    case CKError.permissionFailure.rawValue:
                        print("ERROR: 權限錯誤，請檢查項目權限設置")
                    case CKError.quotaExceeded.rawValue:
                        print("ERROR: 超出配額")
                    case CKError.zoneNotFound.rawValue:
                        print("ERROR: 找不到指定的區域")
                    case CKError.badContainer.rawValue:
                        print("ERROR: 容器錯誤，請檢查容器標識符配置")
                    default:
                        print("ERROR: 其他 CloudKit 錯誤，代碼: \(nsError.code)")
                    }
                    
                    // 檢查 userInfo 中的詳細資訊
                    if let retryAfter = nsError.userInfo[CKErrorRetryAfterKey] as? Double {
                        print("INFO: 建議 \(retryAfter) 秒後重試")
                    }
                }
                
                completion(.failure(error))
                return
            }
            
            guard let savedRecord = savedRecord else {
                let error = NSError(domain: "CloudKitService", code: 0, userInfo: [NSLocalizedDescriptionKey: "無法儲存記錄"])
                print("ERROR: 儲存成功但返回的記錄為空")
                completion(.failure(error))
                return
            }
            
            print("SUCCESS: 待辦事項已成功儲存到 CloudKit")
            print("INFO: 已保存記錄的 recordID: \(savedRecord.recordID.recordName)")
            
            // 從已儲存的記錄重新創建 TodoItem
            let savedTodoItem = self.todoItemFromRecord(savedRecord)
            completion(.success(savedTodoItem))
        }
    }
    
    /// 從 CloudKit 記錄轉換為 TodoItem 實例
    /// - Parameter record: CloudKit 記錄
    /// - Returns: TodoItem 實例
    private func todoItemFromRecord(_ record: CKRecord) -> TodoItem {
        // 從記錄中提取數據
        let id = UUID(uuidString: record.value(forKey: "id") as? String ?? "") ?? UUID()
        let userID = record.value(forKey: "userID") as? String ?? ""
        let title = record.value(forKey: "title") as? String ?? ""
        let priority = record.value(forKey: "priority") as? Int ?? 0
        let isPinned = record.value(forKey: "isPinned") as? Bool ?? false
        let taskDate = record.value(forKey: "taskDate") as? Date ?? Date()
        let note = record.value(forKey: "note") as? String ?? ""
        let statusRawValue = record.value(forKey: "status") as? String ?? TodoStatus.toDoList.rawValue
        let status = TodoStatus(rawValue: statusRawValue) ?? .toDoList
        let createdAt = record.value(forKey: "createdAt") as? Date ?? Date()
        let updatedAt = record.value(forKey: "updatedAt") as? Date ?? Date()
        let correspondingImageID = record.value(forKey: "correspondingImageID") as? String ?? ""
        
        // 創建並返回 TodoItem
        return TodoItem(
            id: id,
            userID: userID,
            title: title,
            priority: priority,
            isPinned: isPinned,
            taskDate: taskDate,
            note: note,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            correspondingImageID: correspondingImageID
        )
    }
    
    
    /// 從 CloudKit 獲取所有待辦事項
    /// - Parameter completion: 完成後的回調，返回結果或錯誤
    func fetchAllTodoItems(completion: @escaping (Result<[TodoItem], Error>) -> Void) {
        print("DEBUG: 開始從 CloudKit 獲取所有待辦事項（修改版）")
        
        // 使用簡單查詢，但避免依賴 recordName
        // 改用 userID 欄位作為查詢條件
        let predicate = NSPredicate(format: "id != %@", "NONEXISTENT_ID")
        let query = CKQuery(recordType: "TodoItem", predicate: predicate)
        
        print("DEBUG: 使用基於 id 欄位的查詢條件")
        print("DEBUG: 明確指定使用默認區域 zoneID: \(defaultZoneID.zoneName)")
        
        // 明確指定使用與儲存相同的默認區域
        privateDatabase.perform(query, inZoneWith: defaultZoneID) { (records, error) in
            DispatchQueue.main.async {
                if let error = error {
                    print("ERROR: 查詢失敗 - \(error.localizedDescription)")
                    completion(.success([self.createDummyErrorItem(error: error)]))
                    return
                }
                
                guard let records = records, !records.isEmpty else {
                    print("INFO: 沒有找到記錄")
                    completion(.success([self.createWelcomeItem()]))
                    return
                }
                
                print("SUCCESS: 查詢成功! 記錄數: \(records.count)")
                if !records.isEmpty {
                    print("INFO: 第一條記錄 ID: \(records.first?.recordID.recordName ?? "無")")
                }
                
                // 轉換記錄
                let todoItems = records.compactMap { self.todoItemFromRecord($0) }
                completion(.success(todoItems))
            }
        }
    }
    
    private func createDummyErrorItem(error: Error) -> TodoItem {
        return TodoItem(
            id: UUID(),
            userID: "error_user",
            title: "查詢錯誤",
            priority: 1,
            isPinned: true,
            taskDate: Date(),
            note: "錯誤: \(error.localizedDescription)",
            status: .toDoList,
            createdAt: Date(),
            updatedAt: Date(),
            correspondingImageID: "error"
        )
    }
    
    private func createWelcomeItem() -> TodoItem {
        return TodoItem(
            id: UUID(),
            userID: "test_user",
            title: "歡迎使用待辦事項",
            priority: 1,
            isPinned: true,
            taskDate: Date(),
            note: "點擊加號按鈕添加您的第一個待辦事項",
            status: .toDoList,
            createdAt: Date(),
            updatedAt: Date(),
            correspondingImageID: "welcome"
        )
    }
    
    /// 使用 CKQueryOperation 作為備選查詢方式
    /// - Parameter completion: 完成後的回調
    private func fetchTodoItemsUsingOperation(completion: @escaping (Result<[TodoItem], Error>) -> Void) {
        print("DEBUG: 嘗試方法 3 - 使用 CKQueryOperation")
        
        let query = CKQuery(recordType: "TodoItem", predicate: NSPredicate(value: true))
        // 修改查詢條件，不再依賴 recordName
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        // 使用更簡單的存取方式創建操作 
        let operation = CKQueryOperation(query: query)
        
        var fetchedRecords = [CKRecord]()
        
        print("DEBUG: 設置 CKQueryOperation 的 recordMatchedBlock 和 queryResultBlock")
        
        // 記錄匹配處理
        operation.recordMatchedBlock = { (recordID, result) in
            switch result {
            case .success(let record):
                print("INFO: 找到記錄: \(record.recordID.recordName)")
                fetchedRecords.append(record)
            case .failure(let error):
                print("ERROR: 處理記錄時出錯: \(error.localizedDescription)")
            }
        }
        
        // 查詢結果處理
        operation.queryResultBlock = { result in
            switch result {
            case .success(_):
                print("SUCCESS: 查詢操作完成，獲取記錄: \(fetchedRecords.count) 個")
                
                if fetchedRecords.isEmpty {
                    print("INFO: 沒有找到任何記錄，返回空列表")
                    
                    // 創建一個模擬記錄，以確認基本功能正常
                    let dummyItem = TodoItem(
                        id: UUID(),
                        userID: "test_user",
                        title: "測試項目 - 請嘗試添加新項目",
                        priority: 1,
                        isPinned: true,
                        taskDate: Date(),
                        note: "這是一個測試項目，表示CloudKit可能初始化成功但沒有數據",
                        status: .toDoList,
                        createdAt: Date(),
                        updatedAt: Date(),
                        correspondingImageID: "test"
                    )
                    
                    // 返回一個模擬項目，以便用戶可以看到界面而不是空白
                    completion(.success([dummyItem]))
                } else {
                    let todoItems = fetchedRecords.compactMap { self.todoItemFromRecord($0) }
                    completion(.success(todoItems))
                }
                
            case .failure(let error):
                let nsError = error as NSError
                print("ERROR: 查詢操作失敗: \(error.localizedDescription), 錯誤代碼: \(nsError.code)")
                
                // 檢查是否是 iCloud 帳戶問題
                if nsError.domain == CKErrorDomain && nsError.code == CKError.notAuthenticated.rawValue {
                    print("ERROR: 未登入 iCloud 帳戶或沒有權限")
                    
                    // 返回一個模擬記錄，而不是空結果
                    let dummyItem = TodoItem(
                        id: UUID(),
                        userID: "icloud_error",
                        title: "iCloud 登入錯誤 - 請檢查登入狀態",
                        priority: 1,
                        isPinned: true,
                        taskDate: Date(),
                        note: "此錯誤表示您可能未登入 iCloud 或應用沒有足夠權限",
                        status: .toDoList,
                        createdAt: Date(),
                        updatedAt: Date(),
                        correspondingImageID: "error"
                    )
                    
                    completion(.success([dummyItem]))
                } else {
                    // 創建一個錯誤提示項目
                    let errorItem = TodoItem(
                        id: UUID(),
                        userID: "error",
                        title: "讀取錯誤 - \(nsError.code)",
                        priority: 1,
                        isPinned: true,
                        taskDate: Date(),
                        note: "無法讀取 CloudKit 數據: \(error.localizedDescription)",
                        status: .toDoList,
                        createdAt: Date(),
                        updatedAt: Date(),
                        correspondingImageID: "error"
                    )
                    
                    // 返回一個錯誤提示項目，而不是完全失敗
                    completion(.success([errorItem]))
                }
            }
        }
        
        // 設置小批量獲取，減少超時風險
        operation.resultsLimit = 50
        print("DEBUG: 設置結果限制為 50 項")
        
        // 執行操作
        print("DEBUG: 添加操作到數據庫隊列進行執行")
        publicDatabase.add(operation)
    }
    
    /// 從 CloudKit 刪除待辦事項
    /// - Parameters:
    ///   - todoItemID: 待刪除的待辦事項 ID
    ///   - completion: 完成後的回調，返回成功或錯誤
    func deleteTodoItem(withID todoItemID: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        let recordID = CKRecord.ID(recordName: todoItemID.uuidString, zoneID: defaultZoneID)
        
        publicDatabase.delete(withRecordID: recordID) { (recordID, error) in
            if let error = error {
                print("從 CloudKit 刪除待辦事項失敗: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            completion(.success(()))
        }
    }
    
    /// 更新 CloudKit 中的待辦事項
    /// - Parameters:
    ///   - todoItem: 待更新的待辦事項
    ///   - completion: 完成後的回調，返回結果或錯誤
    func updateTodoItem(_ todoItem: TodoItem, completion: @escaping (Result<TodoItem, Error>) -> Void) {
        // 創建記錄 ID
        let recordID = CKRecord.ID(recordName: todoItem.id.uuidString, zoneID: defaultZoneID)
        
        // 先獲取現有記錄
        publicDatabase.fetch(withRecordID: recordID) { (record, error) in
            if let error = error {
                print("從 CloudKit 獲取待辦事項失敗: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard var record = record else {
                let error = NSError(domain: "CloudKitService", code: 0, userInfo: [NSLocalizedDescriptionKey: "找不到要更新的記錄"])
                completion(.failure(error))
                return
            }
            
            // 更新記錄欄位
            record.setValue(todoItem.userID, forKey: "userID")
            record.setValue(todoItem.title, forKey: "title")
            record.setValue(todoItem.priority, forKey: "priority")
            record.setValue(todoItem.isPinned, forKey: "isPinned")
            record.setValue(todoItem.taskDate, forKey: "taskDate")
            record.setValue(todoItem.note, forKey: "note")
            record.setValue(todoItem.status.rawValue, forKey: "status")
            record.setValue(todoItem.updatedAt, forKey: "updatedAt")
            record.setValue(todoItem.correspondingImageID, forKey: "correspondingImageID")
            
            // 儲存更新後的記錄
            self.publicDatabase.save(record) { (savedRecord, error) in
                if let error = error {
                    print("更新 CloudKit 中的待辦事項失敗: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let savedRecord = savedRecord else {
                    let error = NSError(domain: "CloudKitService", code: 0, userInfo: [NSLocalizedDescriptionKey: "無法儲存更新的記錄"])
                    completion(.failure(error))
                    return
                }
                
                // 返回更新後的 TodoItem
                let updatedTodoItem = self.todoItemFromRecord(savedRecord)
                completion(.success(updatedTodoItem))
            }
        }
    }
}
