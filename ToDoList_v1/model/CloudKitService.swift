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
        
        // 延遲檢查 iCloud 狀態，確保初始化完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.performAuthentication()
        }
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
                    print("INFO: 當前 iCloud 用戶ID: \(userID)")
                    // 保存當前用戶ID
                    UserDefaults.standard.set(userID, forKey: "currentCloudKitUserID")
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
    
    /// 檢查當前認證狀態
    func isCurrentlyAuthenticated() -> Bool {
        return isAuthenticated
    }
    
    // MARK: - CRUD Operations
    
    /// 儲存待辦事項至 CloudKit
    /// - Parameters:
    ///   - todoItem: 待儲存的待辦事項
    ///   - completion: 完成後的回調，返回結果或錯誤
    func saveTodoItem(_ todoItem: TodoItem, completion: @escaping (Result<TodoItem, Error>) -> Void) {
        print("DEBUG: 開始儲存待辦事項 - ID: \(todoItem.id.uuidString), 標題: \(todoItem.title)")
        
        // 確保認證狀態有效
        ensureAuthenticated { [weak self] isAuthenticated in
            guard let self = self else { return }
            
            guard isAuthenticated else {
                print("ERROR: CloudKit 認證失敗，無法儲存待辦事項")
                let error = NSError(domain: "CloudKitService", code: 401, userInfo: [NSLocalizedDescriptionKey: "CloudKit 認證失敗"])
                completion(.failure(error))
                return
            }
            
            self.performSaveTodoItem(todoItem, completion: completion)
        }
    }
    
    /// 實際執行儲存操作
    private func performSaveTodoItem(_ todoItem: TodoItem, completion: @escaping (Result<TodoItem, Error>) -> Void) {
        // 獲取當前 iCloud 用戶 ID
        let currentUserID = UserDefaults.standard.string(forKey: "currentCloudKitUserID") ?? "unknown_user"
        
        // 創建 CKRecord 物件
        let recordID = CKRecord.ID(recordName: todoItem.id.uuidString, zoneID: defaultZoneID)
        let record = CKRecord(recordType: "TodoItem", recordID: recordID)
        
        print("DEBUG: 使用 CKRecord.ID - recordName: \(recordID.recordName), zoneID: \(recordID.zoneID.zoneName)")
        
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
        
        // 確保認證狀態有效
        ensureAuthenticated { [weak self] isAuthenticated in
            guard let self = self else { return }
            
            guard isAuthenticated else {
                print("ERROR: CloudKit 認證失敗，無法獲取待辦事項")
                let error = NSError(domain: "CloudKitService", code: 401, userInfo: [NSLocalizedDescriptionKey: "CloudKit 認證失敗"])
                completion(.failure(error))
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
        let recordID = CKRecord.ID(recordName: todoItemID.uuidString, zoneID: defaultZoneID)
        
        print("DEBUG: 開始從 CloudKit 刪除待辦事項 - ID: \(todoItemID.uuidString)")
        
        // 統一使用 privateDatabase
        privateDatabase.delete(withRecordID: recordID) { (recordID, error) in
            DispatchQueue.main.async {
                if let error = error {
                    print("ERROR: 從 CloudKit 刪除待辦事項失敗: \(error.localizedDescription)")
                    self.handleCloudKitError(error, completion: completion)
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
        
        // 創建記錄 ID
        let recordID = CKRecord.ID(recordName: todoItem.id.uuidString, zoneID: defaultZoneID)
        
        // 統一使用 privateDatabase 獲取現有記錄
        privateDatabase.fetch(withRecordID: recordID) { (record, error) in
            if let error = error {
                print("ERROR: 從 CloudKit 獲取待辦事項失敗: \(error.localizedDescription)")
                self.handleCloudKitError(error, completion: completion)
                return
            }
            
            guard var record = record else {
                print("ERROR: 找不到要更新的記錄")
                let error = NSError(domain: "CloudKitService", code: 404, userInfo: [NSLocalizedDescriptionKey: "找不到要更新的記錄"])
                completion(.failure(error))
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
                        print("ERROR: 更新 CloudKit 中的待辦事項失敗: \(error.localizedDescription)")
                        self.handleCloudKitError(error, completion: completion)
                        return
                    }
                    
                    guard let savedRecord = savedRecord else {
                        let error = NSError(domain: "CloudKitService", code: 500, userInfo: [NSLocalizedDescriptionKey: "無法儲存更新的記錄"])
                        completion(.failure(error))
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
