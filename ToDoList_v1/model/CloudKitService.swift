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
    
    // 認證狀態管理
    private var isAuthenticated = false
    private var authenticationInProgress = false
    private var pendingOperations: [(Bool) -> Void] = []
    private var consecutiveFailures = 0
    private let maxConsecutiveFailures = 2
    private var isCloudKitAvailable = true  // 新增：CloudKit 可用性標記
    
    
    // MARK: - Initialization
    private init() {
        // 初始化 CloudKit 容器
        // print("DEBUG: 正在初始化 CloudKitService") // 已移轉到 API
        self.container = CKContainer(identifier: "iCloud.com.fcu.ToDolist1")
        self.publicDatabase = container.publicCloudDatabase
        self.privateDatabase = container.privateCloudDatabase
        // print("DEBUG: CloudKit container 已初始化 - ID: \(container.containerIdentifier ?? "未知")") // 已移轉到 API
        
        // 設置帳號變化通知觀察者
        setupAccountChangeObserver()
        
        // 應用啟動時立即進行認證，確保重新安裝後能正確同步
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.performAuthentication()
        }
        
    }
    
    // MARK: - Authentication Management
    
    /// 執行認證檢查和用戶ID獲取
    private func performAuthentication() {
        guard !authenticationInProgress else {
            return
        }
        
        authenticationInProgress = true
        
        // 檢查 iCloud 狀態
        container.accountStatus { [weak self] (status, error) in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.authenticationInProgress = false
                
                if let error = error {
                    self.consecutiveFailures += 1
                    
                    // 如果連續失敗，標記 CloudKit 為不可用並切換到本地模式
                    if self.consecutiveFailures >= self.maxConsecutiveFailures {
                        self.isCloudKitAvailable = false
                        self.isAuthenticated = false
                        self.handleAuthenticationResult(false)
                        return
                    }
                    
                    self.handleAuthenticationResult(false)
                    return
                }
                
                switch status {
                case .available:
                    self.fetchAndSaveCurrentUserID { success in
                        self.handleAuthenticationResult(success)
                    }
                case .noAccount:
                    self.handleAuthenticationResult(false)
                case .restricted:
                    self.handleAuthenticationResult(false)
                case .couldNotDetermine:
                    self.handleAuthenticationResult(false)
                case .temporarilyUnavailable:
                    self.handleAuthenticationResult(false)
                @unknown default:
                    self.handleAuthenticationResult(false)
                }
            }
        }
    }
    
    /// 處理認證結果並執行等待中的操作
    private func handleAuthenticationResult(_ success: Bool) {
        isAuthenticated = success
        
        if success {
            consecutiveFailures = 0 // 重置失敗計數
        } else {
        }
        
        // 執行所有等待中的操作
        for operation in pendingOperations {
            operation(success)
        }
        pendingOperations.removeAll()
    }
    
    /// 確保認證狀態有效，如果需要會觸發重新認證
    private func ensureAuthenticated(completion: @escaping (Bool) -> Void) {
        if isAuthenticated && !authenticationInProgress {
            completion(true)
            return
        }
        
        // 加入等待隊列
        pendingOperations.append(completion)
        
        // 如果沒有正在進行認證，開始認證
        if !authenticationInProgress {
            performAuthentication()
        }
    }
    
    // 設置 iCloud 帳號變化觀察者
    private func setupAccountChangeObserver() {
        NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAccountChange()
        }
    }
    
    // 處理 iCloud 帳號變化
    private func handleAccountChange() {
        
        // 重置認證狀態
        isAuthenticated = false
        
        // 重新執行認證
        performAuthentication()
        
        // 檢查新帳號狀態
        container.accountStatus { [weak self] (status, error) in
            guard let self = self else { return }
            
            if let error = error {
                return
            }
            
            if status == .available {
                // 獲取新用戶ID並與舊ID比較
                self.checkIfUserChanged()
            } else {
                // 當帳號不可用時，通知清除本地數據
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: Notification.Name("iCloudAccountUnavailable"),
                        object: nil
                    )
                }
            }
        }
    }
    
    // 獲取並保存當前用戶ID
    private func fetchAndSaveCurrentUserID(completion: @escaping (Bool) -> Void = { _ in }) {
        container.fetchUserRecordID { (recordID, error) in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false)
                    return
                }

                if let recordID = recordID {
                    let userID = recordID.recordName
                    let oldUserID = UserDefaults.standard.string(forKey: "currentCloudKitUserID")


                    // 檢查是否為重新安裝或用戶變更的情況
                    let isUserChange = oldUserID != userID
                    let isReinstall = oldUserID == nil && userID != nil

                    // 保存當前用戶ID
                    UserDefaults.standard.set(userID, forKey: "currentCloudKitUserID")

                    // 如果是重新安裝或用戶變更，觸發資料同步
                    if isUserChange || isReinstall {
                        if isReinstall {
                        } else {
                        }

                        // 延遲3秒後觸發同步，確保認證狀態完全穩定
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            // TODO: Replace with API sync when needed
                            // DataSyncManager.shared.performSync { result in
                            //     switch result {
                            //     case .success(let count):
                            //         print("CloudKit認證後成功同步 \(count) 個待辦事項")
                            //         // 發送資料更新通知
                            //         NotificationCenter.default.post(
                            //             name: Notification.Name("TodoItemsDataRefreshed"),
                            //             object: nil
                            //         )
                            //     case .failure(let error):
                            //         print("CloudKit認證後同步失敗: \(error.localizedDescription)")
                            //     }
                            // }
                        }
                    }

                    completion(true)
                } else {
                    completion(false)
                }
            }
        }
    }
    
    // 檢查用戶是否已變更
    private func checkIfUserChanged() {
        container.fetchUserRecordID { (recordID, error) in
            if let error = error {
                return
            }
            
            if let recordID = recordID {
                let newUserID = recordID.recordName
                let oldUserID = UserDefaults.standard.string(forKey: "currentCloudKitUserID")
                
                if oldUserID != newUserID {
                    
                    // 保存新用戶ID
                    UserDefaults.standard.set(newUserID, forKey: "currentCloudKitUserID")
                    
                    // 發送用戶變更通知
                    NotificationCenter.default.post(
                        name: Notification.Name("iCloudUserChanged"),
                        object: nil,
                        userInfo: ["newUserID": newUserID]
                    )
                } else {
                }
            }
        }
    }
    
    // MARK: - Error Handling
    
    /// 統一處理 CloudKit 錯誤，包含自動重新認證
    private func handleCloudKitError<T>(_ error: Error, completion: @escaping (Result<T, Error>) -> Void) {
        let nsError = error as NSError
        
        // 檢查是否是需要重試的錯誤
        if nsError.domain == CKErrorDomain {
            switch nsError.code {
            case CKError.networkFailure.rawValue, CKError.networkUnavailable.rawValue:
                completion(.failure(error))
            case CKError.notAuthenticated.rawValue:
                // 標記為未認證並觸發重新認證
                self.isAuthenticated = false
                self.performAuthentication()
                completion(.failure(error))
            case CKError.quotaExceeded.rawValue:
                completion(.failure(error))
            case CKError.serverRecordChanged.rawValue:
                completion(.failure(error))
            case CKError.badContainer.rawValue:
                completion(.failure(error))
            case CKError.serviceUnavailable.rawValue:
                completion(.failure(error))
            default:
                
                // 檢查錯誤描述中是否包含 auth token 相關錯誤
                if error.localizedDescription.contains("auth token") || 
                   error.localizedDescription.contains("bad or missing auth token") {
                    self.isAuthenticated = false
                    self.performAuthentication()
                }
                
                completion(.failure(error))
            }
        } else {
            completion(.failure(error))
        }
    }
    
    // MARK: - Public Methods
    
    /// 手動觸發重新認證（當遇到認證錯誤時可調用）
    func refreshAuthentication() {
        isAuthenticated = false
        performAuthentication()
    }
    
    /// 強制重置所有認證狀態並重新開始（適用於嚴重認證問題）
    func forceResetAuthentication() {
        
        // 重置所有狀態
        isAuthenticated = false
        authenticationInProgress = false
        
        // 清除所有等待中的操作
        for operation in pendingOperations {
            operation(false)
        }
        pendingOperations.removeAll()
        
        // 清除儲存的用戶ID
        UserDefaults.standard.removeObject(forKey: "currentCloudKitUserID")
        
        // 延遲更長時間後重新嘗試認證
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.performAuthentication()
        }
    }
    
    /// 檢查當前認證狀態
    func isCurrentlyAuthenticated() -> Bool {
        return isAuthenticated
    }
    
    /// 測試基本的 CloudKit 連接（用於診斷）
    func testBasicCloudKitConnection() {
        
        // 測試最基本的 container 操作
        container.accountStatus { status, error in
            DispatchQueue.main.async {
                if let error = error {
                    
                    // 嘗試等待更長時間後重試
                    DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                        self.testBasicCloudKitConnection()
                    }
                } else {
                    
                    if status == .available {
                        self.container.fetchUserRecordID { recordID, error in
                            if let error = error {
                            } else if let recordID = recordID {
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - CRUD Operations
    
    /// 儲存待辦事項至 CloudKit
    /// - Parameters:
    ///   - todoItem: 待儲存的待辦事項
    ///   - completion: 完成後的回調，返回結果或錯誤
    func saveTodoItem(_ todoItem: TodoItem, completion: @escaping (Result<TodoItem, Error>) -> Void) {
        
        // 如果 CloudKit 不可用，直接返回成功（只使用本地存儲）
        if !isCloudKitAvailable {
            completion(.success(todoItem))
            return
        }
        
        // 確保認證狀態有效
        ensureAuthenticated { [weak self] isAuthenticated in
            guard let self = self else { return }
            
            guard isAuthenticated else {
                completion(.success(todoItem))
                return
            }
            
            self.performSaveTodoItem(todoItem, completion: completion)
        }
    }
    
    /// 實際執行儲存操作
    private func performSaveTodoItem(_ todoItem: TodoItem, completion: @escaping (Result<TodoItem, Error>) -> Void) {
        // 獲取當前 iCloud 用戶 ID
        let currentUserID = UserDefaults.standard.string(forKey: "currentCloudKitUserID") ?? "unknown_user"
        
        let recordID = CKRecord.ID(recordName: todoItem.id.uuidString, zoneID: defaultZoneID)
        
        // 先嘗試獲取已存在的記錄，如果不存在再創建新的
        privateDatabase.fetch(withRecordID: recordID) { [weak self] existingRecord, error in
            guard let self = self else { return }
            
            let record: CKRecord
            
            if let existingRecord = existingRecord {
                // 記錄已存在，使用現有記錄進行更新
                record = existingRecord
            } else if let error = error as NSError?, error.domain == CKErrorDomain && error.code == CKError.unknownItem.rawValue {
                // 記錄不存在，創建新記錄
                record = CKRecord(recordType: "TodoItem", recordID: recordID)
            } else {
                // 其他錯誤
                DispatchQueue.main.async {
                    completion(.failure(error ?? NSError(domain: "CloudKitService", code: 500, userInfo: [NSLocalizedDescriptionKey: "獲取記錄失敗"])))
                }
                return
            }
            
            self.updateRecordFields(record: record, todoItem: todoItem, currentUserID: currentUserID)
            self.saveRecordToCloudKit(record: record, completion: completion)
        }
    }
    
    private func updateRecordFields(record: CKRecord, todoItem: TodoItem, currentUserID: String) {
        
        // 設置記錄欄位
        record.setValue(todoItem.id.uuidString, forKey: "id")
        // 使用當前 iCloud 用戶 ID 而不是傳入的 userID
        record.setValue(currentUserID, forKey: "userID")
        record.setValue(todoItem.title, forKey: "title")
        record.setValue(todoItem.priority, forKey: "priority")
        record.setValue(todoItem.isPinned, forKey: "isPinned")
        
        // 處理可選的任務日期
        if let taskDate = todoItem.taskDate {
            record.setValue(taskDate, forKey: "taskDate")
        } else {
            record.setValue(nil, forKey: "taskDate")
        }
        
        record.setValue(todoItem.note, forKey: "note")
        record.setValue(todoItem.status.rawValue, forKey: "status")
        record.setValue(todoItem.createdAt, forKey: "createdAt")
        record.setValue(todoItem.updatedAt, forKey: "updatedAt")
        record.setValue(todoItem.correspondingImageID, forKey: "correspondingImageID")
        
    }
    
    private func saveRecordToCloudKit(record: CKRecord, completion: @escaping (Result<TodoItem, Error>) -> Void) {
        
        // 儲存到 CloudKit
        privateDatabase.save(record) { (savedRecord, error) in
            DispatchQueue.main.async {
                if let error = error {
                    self.handleCloudKitError(error, completion: completion)
                    return
                }
                
                guard let savedRecord = savedRecord else {
                    let error = NSError(domain: "CloudKitService", code: 500, userInfo: [NSLocalizedDescriptionKey: "無法儲存記錄"])
                    completion(.failure(error))
                    return
                }
                
                
                // 從已儲存的記錄重新創建 TodoItem
                let savedTodoItem = self.todoItemFromRecord(savedRecord)
                completion(.success(savedTodoItem))
            }
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
        
        // 讀取可選的任務日期
        let taskDate = record.value(forKey: "taskDate") as? Date
        
        let note = record.value(forKey: "note") as? String ?? ""
        let statusRawValue = record.value(forKey: "status") as? String ?? TodoStatus.toDoList.rawValue
        let status = TodoStatus(rawValue: statusRawValue) ?? .toDoList
        let createdAt = record.value(forKey: "createdAt") as? Date ?? Date()
        let updatedAt = record.value(forKey: "updatedAt") as? Date ?? Date()
        let correspondingImageID = record.value(forKey: "correspondingImageID") as? String ?? ""
        
        // 創建並返回 TodoItem
        // 從舊狀態推導新字段
        let (taskType, completionStatus) = TodoItem.deriveNewFields(from: status, taskDate: taskDate)

        return TodoItem(
            id: id,
            userID: userID,
            title: title,
            priority: priority,
            isPinned: isPinned,
            taskDate: taskDate,
            note: note,
            taskType: taskType,
            completionStatus: completionStatus,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            correspondingImageID: correspondingImageID
        )
    }
    
    
    /// 從 CloudKit 獲取所有待辦事項
    /// - Parameter completion: 完成後的回調，返回結果或錯誤
    func fetchAllTodoItems(completion: @escaping (Result<[TodoItem], Error>) -> Void) {
        
        // 如果 CloudKit 不可用，返回空數組（只使用本地存儲）
        if !isCloudKitAvailable {
            completion(.success([]))
            return
        }
        
        // 確保認證狀態有效
        ensureAuthenticated { [weak self] isAuthenticated in
            guard let self = self else { return }
            
            guard isAuthenticated else {
                completion(.success([]))
                return
            }
            
            self.performFetchAllTodoItems(completion: completion)
        }
    }
    
    /// 實際執行獲取操作
    private func performFetchAllTodoItems(completion: @escaping (Result<[TodoItem], Error>) -> Void) {
        // 獲取當前 iCloud 用戶 ID
        let currentUserID = UserDefaults.standard.string(forKey: "currentCloudKitUserID") ?? "unknown_user"
        
        // 使用 userID 欄位進行查詢，確保只獲取當前用戶的待辦事項
        let predicate = NSPredicate(format: "userID == %@", currentUserID)
        let query = CKQuery(recordType: "TodoItem", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        
        // 統一使用 privateDatabase
        privateDatabase.perform(query, inZoneWith: defaultZoneID) { (records, error) in
            DispatchQueue.main.async {
                if let error = error {
                    self.handleCloudKitError(error, completion: completion)
                    return
                }
                
                guard let records = records else {
                    completion(.success([]))
                    return
                }
                
                
                // 轉換記錄
                let todoItems = records.compactMap { self.todoItemFromRecord($0) }
                completion(.success(todoItems))
            }
        }
    }
    
    
    /// 從 CloudKit 刪除待辦事項
    /// - Parameters:
    ///   - todoItemID: 待刪除的待辦事項 ID
    ///   - completion: 完成後的回調，返回成功或錯誤
    func deleteTodoItem(withID todoItemID: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        
        // 如果 CloudKit 不可用，直接返回成功（只使用本地存儲）
        if !isCloudKitAvailable {
            completion(.success(()))
            return
        }
        
        let recordID = CKRecord.ID(recordName: todoItemID.uuidString, zoneID: defaultZoneID)
        
        // 統一使用 privateDatabase
        privateDatabase.delete(withRecordID: recordID) { (recordID, error) in
            DispatchQueue.main.async {
                if let error = error {
                    // 即使 CloudKit 失敗，也返回成功，因為本地已經刪除
                    completion(.success(()))
                    return
                }
                
                completion(.success(()))
            }
        }
    }
    
    /// 更新 CloudKit 中的待辦事項
    /// - Parameters:
    ///   - todoItem: 待更新的待辦事項
    ///   - completion: 完成後的回調，返回結果或錯誤
    func updateTodoItem(_ todoItem: TodoItem, completion: @escaping (Result<TodoItem, Error>) -> Void) {
        
        // 如果 CloudKit 不可用，直接返回成功（只使用本地存儲）
        if !isCloudKitAvailable {
            completion(.success(todoItem))
            return
        }
        
        // 創建記錄 ID
        let recordID = CKRecord.ID(recordName: todoItem.id.uuidString, zoneID: defaultZoneID)
        
        // 統一使用 privateDatabase 獲取現有記錄
        privateDatabase.fetch(withRecordID: recordID) { (record, error) in
            if let error = error {
                // 即使 CloudKit 失敗，也返回成功，因為本地已經更新
                completion(.success(todoItem))
                return
            }
            
            guard var record = record else {
                // 即使找不到雲端記錄，也返回成功，因為本地已經更新
                completion(.success(todoItem))
                return
            }
            
            // 獲取當前用戶ID確保一致性
            let currentUserID = UserDefaults.standard.string(forKey: "currentCloudKitUserID") ?? "unknown_user"
            
            // 更新記錄欄位
            record.setValue(currentUserID, forKey: "userID")
            record.setValue(todoItem.title, forKey: "title")
            record.setValue(todoItem.priority, forKey: "priority")
            record.setValue(todoItem.isPinned, forKey: "isPinned")
            record.setValue(todoItem.taskDate, forKey: "taskDate")
            record.setValue(todoItem.note, forKey: "note")
            record.setValue(todoItem.status.rawValue, forKey: "status")
            record.setValue(todoItem.updatedAt, forKey: "updatedAt")
            record.setValue(todoItem.correspondingImageID, forKey: "correspondingImageID")
            
            // 統一使用 privateDatabase 儲存更新後的記錄
            self.privateDatabase.save(record) { (savedRecord, error) in
                DispatchQueue.main.async {
                    if let error = error {
                        // 即使 CloudKit 失敗，也返回成功，因為本地已經更新
                        completion(.success(todoItem))
                        return
                    }
                    
                    guard let savedRecord = savedRecord else {
                        // 即使保存失敗，也返回成功，因為本地已經更新
                        completion(.success(todoItem))
                        return
                    }
                    
                    // 返回更新後的 TodoItem
                    let updatedTodoItem = self.todoItemFromRecord(savedRecord)
                    completion(.success(updatedTodoItem))
                }
            }
        }
    }
}
