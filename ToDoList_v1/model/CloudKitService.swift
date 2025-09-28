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
        print("DEBUG: 正在初始化 CloudKitService")
        self.container = CKContainer(identifier: "iCloud.com.fcu.ToDolist1")
        self.publicDatabase = container.publicCloudDatabase
        self.privateDatabase = container.privateCloudDatabase
        print("DEBUG: CloudKit container 已初始化 - ID: \(container.containerIdentifier ?? "未知")")
        
        // 設置帳號變化通知觀察者
        setupAccountChangeObserver()
        
        // 應用啟動時立即進行認證，確保重新安裝後能正確同步
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.performAuthentication()
        }
        
        print("DEBUG: CloudKitService已初始化，將在1秒後自動進行認證")
    }
    
    // MARK: - Authentication Management
    
    /// 執行認證檢查和用戶ID獲取
    private func performAuthentication() {
        guard !authenticationInProgress else {
            print("DEBUG: 認證已在進行中，跳過重複請求")
            return
        }
        
        authenticationInProgress = true
        print("DEBUG: 開始執行 CloudKit 認證檢查")
        
        // 檢查 iCloud 狀態
        container.accountStatus { [weak self] (status, error) in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.authenticationInProgress = false
                
                if let error = error {
                    print("ERROR: 無法獲取 iCloud 帳戶狀態: \(error.localizedDescription)")
                    self.consecutiveFailures += 1
                    
                    // 如果連續失敗，標記 CloudKit 為不可用並切換到本地模式
                    if self.consecutiveFailures >= self.maxConsecutiveFailures {
                        print("WARNING: 連續認證失敗 \(self.consecutiveFailures) 次，切換到本地存儲模式")
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
                    print("INFO: iCloud 帳戶可用，獲取用戶ID")
                    self.fetchAndSaveCurrentUserID { success in
                        self.handleAuthenticationResult(success)
                    }
                case .noAccount:
                    print("WARNING: 未登入 iCloud 帳戶")
                    self.handleAuthenticationResult(false)
                case .restricted:
                    print("WARNING: iCloud 帳戶受限")
                    self.handleAuthenticationResult(false)
                case .couldNotDetermine:
                    print("WARNING: 無法確定 iCloud 帳戶狀態")
                    self.handleAuthenticationResult(false)
                case .temporarilyUnavailable:
                    print("WARNING: iCloud 帳戶暫時不可用")
                    self.handleAuthenticationResult(false)
                @unknown default:
                    print("WARNING: 未知的 iCloud 帳戶狀態")
                    self.handleAuthenticationResult(false)
                }
            }
        }
    }
    
    /// 處理認證結果並執行等待中的操作
    private func handleAuthenticationResult(_ success: Bool) {
        isAuthenticated = success
        
        if success {
            print("INFO: CloudKit 認證成功")
            consecutiveFailures = 0 // 重置失敗計數
        } else {
            print("WARNING: CloudKit 認證失敗")
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
            print("NOTICE: 檢測到 iCloud 帳號變化")
            self?.handleAccountChange()
        }
    }
    
    // 處理 iCloud 帳號變化
    private func handleAccountChange() {
        print("INFO: iCloud 帳號發生變化，重置認證狀態")
        
        // 重置認證狀態
        isAuthenticated = false
        
        // 重新執行認證
        performAuthentication()
        
        // 檢查新帳號狀態
        container.accountStatus { [weak self] (status, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("ERROR: 帳號變化後無法獲取 iCloud 帳戶狀態: \(error.localizedDescription)")
                return
            }
            
            if status == .available {
                print("INFO: 帳號變化後 iCloud 帳戶可用，檢查是否為新用戶")
                // 獲取新用戶ID並與舊ID比較
                self.checkIfUserChanged()
            } else {
                print("WARNING: 帳號變化後 iCloud 不可用，狀態: \(status)")
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
                    print("ERROR: 無法獲取 iCloud 用戶ID: \(error.localizedDescription)")
                    completion(false)
                    return
                }

                if let recordID = recordID {
                    let userID = recordID.recordName
                    let oldUserID = UserDefaults.standard.string(forKey: "currentCloudKitUserID")

                    print("INFO: 當前 iCloud 用戶ID: \(userID)")

                    // 檢查是否為重新安裝或用戶變更的情況
                    let isUserChange = oldUserID != userID
                    let isReinstall = oldUserID == nil && userID != nil

                    // 保存當前用戶ID
                    UserDefaults.standard.set(userID, forKey: "currentCloudKitUserID")

                    // 如果是重新安裝或用戶變更，觸發資料同步
                    if isUserChange || isReinstall {
                        if isReinstall {
                            print("INFO: 檢測到應用重新安裝，觸發CloudKit資料同步")
                        } else {
                            print("INFO: 檢測到用戶變更，觸發CloudKit資料同步")
                        }

                        // 延遲3秒後觸發同步，確保認證狀態完全穩定
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            DataSyncManager.shared.performSync { result in
                                switch result {
                                case .success(let count):
                                    print("CloudKit認證後成功同步 \(count) 個待辦事項")
                                    // 發送資料更新通知
                                    NotificationCenter.default.post(
                                        name: Notification.Name("TodoItemsDataRefreshed"),
                                        object: nil
                                    )
                                case .failure(let error):
                                    print("CloudKit認證後同步失敗: \(error.localizedDescription)")
                                }
                            }
                        }
                    }

                    completion(true)
                } else {
                    print("WARNING: 無法獲取有效的用戶記錄ID")
                    completion(false)
                }
            }
        }
    }
    
    // 檢查用戶是否已變更
    private func checkIfUserChanged() {
        container.fetchUserRecordID { (recordID, error) in
            if let error = error {
                print("ERROR: 帳號變化後無法獲取用戶ID: \(error.localizedDescription)")
                return
            }
            
            if let recordID = recordID {
                let newUserID = recordID.recordName
                let oldUserID = UserDefaults.standard.string(forKey: "currentCloudKitUserID")
                
                if oldUserID != newUserID {
                    print("NOTICE: 檢測到新的 iCloud 用戶 (Old: \(oldUserID ?? "無"), New: \(newUserID))")
                    
                    // 保存新用戶ID
                    UserDefaults.standard.set(newUserID, forKey: "currentCloudKitUserID")
                    
                    // 發送用戶變更通知
                    NotificationCenter.default.post(
                        name: Notification.Name("iCloudUserChanged"),
                        object: nil,
                        userInfo: ["newUserID": newUserID]
                    )
                } else {
                    print("INFO: iCloud 用戶未變更")
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
                print("WARNING: 網路錯誤，建議重試 - \(error.localizedDescription)")
                completion(.failure(error))
            case CKError.notAuthenticated.rawValue:
                print("WARNING: 認證失效，嘗試重新認證 - \(error.localizedDescription)")
                // 標記為未認證並觸發重新認證
                self.isAuthenticated = false
                self.performAuthentication()
                completion(.failure(error))
            case CKError.quotaExceeded.rawValue:
                print("ERROR: 超出 CloudKit 配額")
                completion(.failure(error))
            case CKError.serverRecordChanged.rawValue:
                print("WARNING: 伺服器記錄已變更，需要處理衝突")
                completion(.failure(error))
            case CKError.badContainer.rawValue:
                print("ERROR: CloudKit 容器配置錯誤")
                completion(.failure(error))
            case CKError.serviceUnavailable.rawValue:
                print("WARNING: CloudKit 服務暫時不可用")
                completion(.failure(error))
            default:
                print("ERROR: CloudKit 錯誤 - 代碼: \(nsError.code), 描述: \(error.localizedDescription)")
                
                // 檢查錯誤描述中是否包含 auth token 相關錯誤
                if error.localizedDescription.contains("auth token") || 
                   error.localizedDescription.contains("bad or missing auth token") {
                    print("INFO: 檢測到認證 token 錯誤，觸發重新認證")
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
        print("INFO: 手動觸發 CloudKit 重新認證")
        isAuthenticated = false
        performAuthentication()
    }
    
    /// 強制重置所有認證狀態並重新開始（適用於嚴重認證問題）
    func forceResetAuthentication() {
        print("WARNING: 強制重置 CloudKit 認證狀態")
        
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
            print("INFO: 強制重置後重新嘗試認證")
            self.performAuthentication()
        }
    }
    
    /// 檢查當前認證狀態
    func isCurrentlyAuthenticated() -> Bool {
        return isAuthenticated
    }
    
    /// 測試基本的 CloudKit 連接（用於診斷）
    func testBasicCloudKitConnection() {
        print("DEBUG: 測試基本 CloudKit 連接")
        
        // 測試最基本的 container 操作
        container.accountStatus { status, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("TEST: 基本帳戶狀態檢查失敗 - \(error.localizedDescription)")
                    
                    // 嘗試等待更長時間後重試
                    print("TEST: 將在 10 秒後重試基本連接")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                        self.testBasicCloudKitConnection()
                    }
                } else {
                    print("TEST: 基本帳戶狀態檢查成功 - 狀態: \(status)")
                    
                    if status == .available {
                        print("TEST: iCloud 帳戶可用，嘗試獲取用戶記錄")
                        self.container.fetchUserRecordID { recordID, error in
                            if let error = error {
                                print("TEST: 獲取用戶記錄失敗 - \(error.localizedDescription)")
                            } else if let recordID = recordID {
                                print("TEST: 成功獲取用戶記錄 - ID: \(recordID.recordName)")
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
        print("DEBUG: 開始儲存待辦事項 - ID: \(todoItem.id.uuidString), 標題: \(todoItem.title)")
        
        // 如果 CloudKit 不可用，直接返回成功（只使用本地存儲）
        if !isCloudKitAvailable {
            print("INFO: CloudKit 不可用，使用本地存儲模式")
            completion(.success(todoItem))
            return
        }
        
        // 確保認證狀態有效
        ensureAuthenticated { [weak self] isAuthenticated in
            guard let self = self else { return }
            
            guard isAuthenticated else {
                print("WARNING: CloudKit 認證失敗，切換到本地存儲模式")
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
                print("DEBUG: 找到已存在記錄，執行更新操作 - ID: \(recordID.recordName)")
                record = existingRecord
            } else if let error = error as NSError?, error.domain == CKErrorDomain && error.code == CKError.unknownItem.rawValue {
                // 記錄不存在，創建新記錄
                print("DEBUG: 記錄不存在，創建新記錄 - ID: \(recordID.recordName)")
                record = CKRecord(recordType: "TodoItem", recordID: recordID)
            } else {
                // 其他錯誤
                print("ERROR: 獲取記錄時發生錯誤: \(error?.localizedDescription ?? "未知錯誤")")
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
        print("DEBUG: 更新記錄欄位 - recordName: \(record.recordID.recordName)")
        
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
        
        print("DEBUG: CKRecord 已設置完所有欄位，準備儲存到 CloudKit")
    }
    
    private func saveRecordToCloudKit(record: CKRecord, completion: @escaping (Result<TodoItem, Error>) -> Void) {
        print("DEBUG: CloudKit container identifier: \(container.containerIdentifier ?? "未知")")
        
        // 儲存到 CloudKit
        privateDatabase.save(record) { (savedRecord, error) in
            DispatchQueue.main.async {
                if let error = error {
                    print("ERROR: 儲存待辦事項失敗 - \(error.localizedDescription)")
                    self.handleCloudKitError(error, completion: completion)
                    return
                }
                
                guard let savedRecord = savedRecord else {
                    let error = NSError(domain: "CloudKitService", code: 500, userInfo: [NSLocalizedDescriptionKey: "無法儲存記錄"])
                    print("ERROR: 儲存成功但返回的記錄為空")
                    completion(.failure(error))
                    return
                }
                
                print("SUCCESS: 待辦事項已成功儲存到 CloudKit - ID: \(savedRecord.recordID.recordName)")
                
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
        print("DEBUG: 開始從 CloudKit 獲取所有待辦事項")
        
        // 如果 CloudKit 不可用，返回空數組（只使用本地存儲）
        if !isCloudKitAvailable {
            print("INFO: CloudKit 不可用，返回空數組（本地存儲模式）")
            completion(.success([]))
            return
        }
        
        // 確保認證狀態有效
        ensureAuthenticated { [weak self] isAuthenticated in
            guard let self = self else { return }
            
            guard isAuthenticated else {
                print("WARNING: CloudKit 認證失敗，返回空數組（本地存儲模式）")
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
        
        print("DEBUG: 查詢當前用戶數據: \(currentUserID)")
        
        // 統一使用 privateDatabase
        privateDatabase.perform(query, inZoneWith: defaultZoneID) { (records, error) in
            DispatchQueue.main.async {
                if let error = error {
                    print("ERROR: 查詢失敗 - \(error.localizedDescription)")
                    self.handleCloudKitError(error, completion: completion)
                    return
                }
                
                guard let records = records else {
                    print("INFO: 沒有找到記錄")
                    completion(.success([]))
                    return
                }
                
                print("SUCCESS: 查詢成功! 記錄數: \(records.count)")
                
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
        print("DEBUG: 開始從 CloudKit 刪除待辦事項 - ID: \(todoItemID.uuidString)")
        
        // 如果 CloudKit 不可用，直接返回成功（只使用本地存儲）
        if !isCloudKitAvailable {
            print("INFO: CloudKit 不可用，刪除操作僅限本地")
            completion(.success(()))
            return
        }
        
        let recordID = CKRecord.ID(recordName: todoItemID.uuidString, zoneID: defaultZoneID)
        
        // 統一使用 privateDatabase
        privateDatabase.delete(withRecordID: recordID) { (recordID, error) in
            DispatchQueue.main.async {
                if let error = error {
                    print("WARNING: 從 CloudKit 刪除待辦事項失敗，但本地操作已完成: \(error.localizedDescription)")
                    // 即使 CloudKit 失敗，也返回成功，因為本地已經刪除
                    completion(.success(()))
                    return
                }
                
                print("SUCCESS: 成功從 CloudKit 刪除待辦事項 - ID: \(todoItemID.uuidString)")
                completion(.success(()))
            }
        }
    }
    
    /// 更新 CloudKit 中的待辦事項
    /// - Parameters:
    ///   - todoItem: 待更新的待辦事項
    ///   - completion: 完成後的回調，返回結果或錯誤
    func updateTodoItem(_ todoItem: TodoItem, completion: @escaping (Result<TodoItem, Error>) -> Void) {
        print("DEBUG: 開始更新 CloudKit 中的待辦事項 - ID: \(todoItem.id.uuidString)")
        
        // 如果 CloudKit 不可用，直接返回成功（只使用本地存儲）
        if !isCloudKitAvailable {
            print("INFO: CloudKit 不可用，更新操作僅限本地")
            completion(.success(todoItem))
            return
        }
        
        // 創建記錄 ID
        let recordID = CKRecord.ID(recordName: todoItem.id.uuidString, zoneID: defaultZoneID)
        
        // 統一使用 privateDatabase 獲取現有記錄
        privateDatabase.fetch(withRecordID: recordID) { (record, error) in
            if let error = error {
                print("WARNING: 從 CloudKit 獲取待辦事項失敗，但本地更新已完成: \(error.localizedDescription)")
                // 即使 CloudKit 失敗，也返回成功，因為本地已經更新
                completion(.success(todoItem))
                return
            }
            
            guard var record = record else {
                print("WARNING: 找不到要更新的記錄，但本地更新已完成")
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
                        print("WARNING: 更新 CloudKit 中的待辦事項失敗，但本地更新已完成: \(error.localizedDescription)")
                        // 即使 CloudKit 失敗，也返回成功，因為本地已經更新
                        completion(.success(todoItem))
                        return
                    }
                    
                    guard let savedRecord = savedRecord else {
                        print("WARNING: 無法儲存更新的記錄，但本地更新已完成")
                        // 即使保存失敗，也返回成功，因為本地已經更新
                        completion(.success(todoItem))
                        return
                    }
                    
                    print("SUCCESS: 成功更新 CloudKit 中的待辦事項 - ID: \(todoItem.id.uuidString)")
                    // 返回更新後的 TodoItem
                    let updatedTodoItem = self.todoItemFromRecord(savedRecord)
                    completion(.success(updatedTodoItem))
                }
            }
        }
    }
}
