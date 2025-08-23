//
//  DataSyncManager.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/5/10.
//

import Foundation
import CloudKit
import Combine

/// 數據同步管理器 - 協調 CloudKit 和本地存儲之間的同步
class DataSyncManager {
    // MARK: - 單例模式
    static let shared = DataSyncManager()
    
    // MARK: - 屬性
    private let cloudKitService = CloudKitService.shared
    private let localDataManager = LocalDataManager.shared
    
    // 用於發佈同步狀態變化的主題
    private let syncStatusSubject = PassthroughSubject<SyncStatus, Never>()
    var syncStatusPublisher: AnyPublisher<SyncStatus, Never> {
        return syncStatusSubject.eraseToAnyPublisher()
    }
    
    // MARK: - 同步狀態
    enum SyncStatus {
        case idle
        case syncing
        case completed(Int)
        case failed(Error)
    }
    
    // MARK: - 初始化
    private init() {
        print("DEBUG: 初始化 DataSyncManager")
        
        // 設置監聽用戶帳號變化
        setupAccountChangeObserver()
    }
    
    /// 設置監聽用戶帳號變化的觀察者
    private func setupAccountChangeObserver() {
        // 監聽 iCloud 用戶變更通知
        NotificationCenter.default.addObserver(
            forName: Notification.Name("iCloudUserChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            
            print("NOTICE: DataSyncManager 收到用戶變更通知")
            
            // 獲取新用戶ID
            if let userInfo = notification.userInfo,
               let newUserID = userInfo["newUserID"] as? String {
                print("INFO: 新用戶ID: \(newUserID)")
                
                // 清除本地數據並重新加載
                self.handleUserChange(newUserID: newUserID)
            }
        }
        
        // 監聽 iCloud 帳號不可用通知
        NotificationCenter.default.addObserver(
            forName: Notification.Name("iCloudAccountUnavailable"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            
            print("NOTICE: DataSyncManager 收到 iCloud 帳號不可用通知")
            
            // 清除本地數據，但不嘗試從雲端加載
            self.clearLocalData()
        }
    }
    
    /// 處理用戶變更
    private func handleUserChange(newUserID: String) {
        // 首先清除本地數據
        clearLocalData()
        
        // 發送同步狀態變化通知
        syncStatusSubject.send(.syncing)
        
        // 嘗試從 CloudKit 獲取新用戶的數據
        cloudKitService.fetchAllTodoItems { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let items):
                print("INFO: 成功從 CloudKit 獲取新用戶的數據: \(items.count) 項")
                
                // 保存到本地
                self.localDataManager.saveAllTodoItems(items)
                
                // 發送完成通知
                self.syncStatusSubject.send(.completed(items.count))
                
                // 發布數據變化通知
                NotificationCenter.default.post(
                    name: Notification.Name("TodoItemsDataRefreshed"),
                    object: nil
                )
                
            case .failure(let error):
                print("ERROR: 無法獲取新用戶的數據: \(error.localizedDescription)")
                
                // 發送失敗通知
                self.syncStatusSubject.send(.failed(error))
            }
        }
    }
    
    /// 清除本地數據
    private func clearLocalData() {
        print("INFO: 清除本地數據")
        
        // 使用 LocalDataManager 清除所有數據
        localDataManager.clearAllData()
        
        // 清除與數據相關的 UserDefaults 設置
        UserDefaults.standard.removeObject(forKey: "isSleepMode")
        UserDefaults.standard.removeObject(forKey: "alarmTimeString")
        UserDefaults.standard.removeObject(forKey: "lastSyncTime")
        UserDefaults.standard.removeObject(forKey: "completedDays") // 清除已完成日期數據
        
        print("INFO: 本地數據清除完成")
    }
    
    // MARK: - 公共方法
    
    /// 獲取待辦事項列表 - 首先從本地獲取，然後嘗試從 CloudKit 同步
    func fetchTodoItems(completion: @escaping (Result<[TodoItem], Error>) -> Void) {
        // 首先從本地獲取數據
        let localItems = localDataManager.getAllTodoItems()
        print("DEBUG: fetchTodoItems - 本地項目數量: \(localItems.count)")
        
        // 發送本地數據
        completion(.success(localItems))
        
        // 然後嘗試從 CloudKit 同步數據
        print("DEBUG: fetchTodoItems - 開始從 CloudKit 同步數據")
        syncFromCloudKit { result in
            switch result {
            case .success(let updatedItems):
                print("DEBUG: fetchTodoItems - CloudKit 同步完成，獲得 \(updatedItems.count) 個項目")
                // 檢查是否真的有資料變更
                let hasChanges = updatedItems.count != localItems.count || 
                               !updatedItems.allSatisfy { updatedItem in
                                   localItems.contains { localItem in
                                       localItem.id == updatedItem.id && 
                                       localItem.status == updatedItem.status &&
                                       localItem.updatedAt == updatedItem.updatedAt
                                   }
                               }
                
                if hasChanges {
                    // 如果有更新，則再次調用完成處理程序
                    print("DEBUG: fetchTodoItems - 檢測到資料變更，重新回傳更新的資料")
                    completion(.success(updatedItems))
                } else {
                    print("DEBUG: fetchTodoItems - 沒有新的資料變更")
                }
            case .failure(let error):
                // 只記錄錯誤，不影響已經返回的本地數據
                print("WARNING: 從 CloudKit 同步時出現錯誤: \(error.localizedDescription)")
            }
        }
    }
    
    /// 添加新的待辦事項 - 首先保存到本地，然後嘗試同步到 CloudKit
    func addTodoItem(_ item: TodoItem, completion: @escaping (Result<TodoItem, Error>) -> Void) {
        // 獲取當前 iCloud 用戶 ID
        let currentUserID = UserDefaults.standard.string(forKey: "currentCloudKitUserID") ?? "unknown_user"
        
        // 創建一個新的TodoItem，確保使用當前用戶ID和正確的時間戳
        var updatedItem = item
        updatedItem.userID = currentUserID
        updatedItem.updatedAt = Date() // 確保有最新的更新時間
        
        // 使用 DispatchQueue 確保本地操作的線程安全
        DispatchQueue.main.async {
            // 保存到本地
            self.localDataManager.addTodoItem(updatedItem)
            
            // 返回成功結果，不等待 CloudKit 同步完成
            completion(.success(updatedItem))
            
            // 在後台嘗試同步到 CloudKit
            DispatchQueue.global(qos: .background).async {
                self.syncItemToCloudKit(updatedItem) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success:
                            print("INFO: 成功同步待辦事項到 CloudKit - ID: \(updatedItem.id.uuidString)")
                            self.localDataManager.updateSyncStatus(for: updatedItem.id, isSynced: true)
                        case .failure(let error):
                            print("WARNING: 同步待辦事項到 CloudKit 失敗 - ID: \(updatedItem.id.uuidString), 錯誤: \(error.localizedDescription)")
                            self.localDataManager.updateSyncStatus(for: updatedItem.id, isSynced: false, error: error.localizedDescription)
                        }
                    }
                }
            }
        }
    }
    
    /// 更新待辦事項 - 首先更新本地，然後嘗試同步到 CloudKit
    func updateTodoItem(_ item: TodoItem, completion: @escaping (Result<TodoItem, Error>) -> Void) {
        // 獲取當前 iCloud 用戶 ID
        let currentUserID = UserDefaults.standard.string(forKey: "currentCloudKitUserID") ?? "unknown_user"
        
        // 創建一個新的TodoItem，確保使用當前用戶ID和正確的時間戳
        var updatedItem = item
        updatedItem.userID = currentUserID
        updatedItem.updatedAt = Date() // 確保有最新的更新時間
        
        // 使用 DispatchQueue 確保本地操作的線程安全
        DispatchQueue.main.async {
            // 更新本地
            self.localDataManager.updateTodoItem(updatedItem)
            
            // 返回成功結果，不等待 CloudKit 同步完成
            completion(.success(updatedItem))
            
            // 在後台嘗試同步到 CloudKit
            DispatchQueue.global(qos: .background).async {
                self.syncItemToCloudKit(updatedItem) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success:
                            print("INFO: 成功同步更新的待辦事項到 CloudKit - ID: \(updatedItem.id.uuidString)")
                            self.localDataManager.updateSyncStatus(for: updatedItem.id, isSynced: true)
                        case .failure(let error):
                            print("WARNING: 同步更新的待辦事項到 CloudKit 失敗 - ID: \(updatedItem.id.uuidString), 錯誤: \(error.localizedDescription)")
                            self.localDataManager.updateSyncStatus(for: updatedItem.id, isSynced: false, error: error.localizedDescription)
                        }
                    }
                }
            }
        }
    }
    
    /// 刪除待辦事項 - 首先從本地刪除，然後嘗試從 CloudKit 刪除
    func deleteTodoItem(withID id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        // 使用 DispatchQueue 確保本地操作的線程安全
        DispatchQueue.main.async {
            // 從本地刪除
            self.localDataManager.deleteTodoItem(withID: id)
            
            // 返回成功結果，不等待 CloudKit 同步完成
            completion(.success(()))
            
            // 在後台嘗試從 CloudKit 刪除
            DispatchQueue.global(qos: .background).async {
                self.cloudKitService.deleteTodoItem(withID: id) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success:
                            print("INFO: 成功從 CloudKit 刪除待辦事項 - ID: \(id.uuidString)")
                        case .failure(let error):
                            print("WARNING: 從 CloudKit 刪除待辦事項失敗 - ID: \(id.uuidString), 錯誤: \(error.localizedDescription)")
                            // 可以考慮在這裡加入重試邏輯或者恢復本地數據
                        }
                    }
                }
            }
        }
    }
    
    /// 執行手動同步 - 同步所有未同步的項目到 CloudKit
    func performSync(completion: @escaping (Result<Int, Error>) -> Void) {
        // 更新同步狀態
        syncStatusSubject.send(.syncing)
        
        // 從 CloudKit 獲取最新數據
        syncFromCloudKit { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let items):
                // 獲取所有未同步的本地項目
                let unsyncedIDs = self.localDataManager.getUnsyncedItemIDs()
                var syncCount = 0
                
                // 如果沒有需要同步的項目，直接返回成功
                if unsyncedIDs.isEmpty {
                    self.syncStatusSubject.send(.completed(0))
                    completion(.success(0))
                    return
                }
                
                // 為每個未同步的項目創建一個同步操作
                let syncGroup = DispatchGroup()
                var syncErrors: [UUID: Error] = [:]
                
                // 同步每個未同步的項目
                for itemID in unsyncedIDs {
                    syncGroup.enter()
                    
                    if let item = self.localDataManager.getTodoItem(withID: itemID) {
                        self.syncItemToCloudKit(item) { result in
                            switch result {
                            case .success:
                                syncCount += 1
                                self.localDataManager.updateSyncStatus(for: itemID, isSynced: true)
                            case .failure(let error):
                                syncErrors[itemID] = error
                                self.localDataManager.updateSyncStatus(for: itemID, isSynced: false, error: error.localizedDescription)
                            }
                            syncGroup.leave()
                        }
                    } else {
                        // 找不到項目，可能已被刪除
                        syncGroup.leave()
                    }
                }
                
                // 等待所有同步操作完成
                syncGroup.notify(queue: .main) {
                    // 更新最後同步時間
                    self.localDataManager.updateLastSyncTime()
                    
                    // 更新同步狀態
                    if syncErrors.isEmpty {
                        self.syncStatusSubject.send(.completed(syncCount))
                        completion(.success(syncCount))
                    } else {
                        let error = NSError(
                            domain: "DataSyncManager",
                            code: 1001,
                            userInfo: [NSLocalizedDescriptionKey: "部分項目同步失敗: \(syncErrors.count)"]
                        )
                        self.syncStatusSubject.send(.failed(error))
                        completion(.failure(error))
                    }
                }
                
            case .failure(let error):
                self.syncStatusSubject.send(.failed(error))
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - 私有輔助方法
    
    /// 將單個項目同步到 CloudKit
    private func syncItemToCloudKit(_ item: TodoItem, completion: @escaping (Result<TodoItem, Error>) -> Void) {
        cloudKitService.saveTodoItem(item, completion: completion)
    }
    
    /// 從 CloudKit 獲取數據並與本地合併
    private func syncFromCloudKit(completion: @escaping (Result<[TodoItem], Error>) -> Void) {
        print("DEBUG: syncFromCloudKit - 開始從 CloudKit 獲取資料")
        cloudKitService.fetchAllTodoItems { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let cloudItems):
                print("DEBUG: syncFromCloudKit - 成功從 CloudKit 獲取 \(cloudItems.count) 個項目")
                
                // 獲取本地項目
                let localItems = self.localDataManager.getAllTodoItems()
                print("DEBUG: syncFromCloudKit - 本地現有 \(localItems.count) 個項目")
                
                var mergedItems = localItems
                var updatedItems = [TodoItem]()
                
                // 合併雲端數據，採用更智慧的衝突解決策略
                for cloudItem in cloudItems {
                    if let index = mergedItems.firstIndex(where: { $0.id == cloudItem.id }) {
                        let localItem = mergedItems[index]
                        let syncStatus = self.localDataManager.getSyncStatus(for: localItem.id)
                        
                        // 衝突解決策略：比較 updatedAt 時間戳
                        if let syncStatus = syncStatus, !syncStatus.isSynced {
                            // 本地有未同步的修改，比較時間戳決定使用哪個版本
                            if cloudItem.updatedAt > localItem.updatedAt {
                                // 雲端版本更新，使用雲端版本但標記需要重新同步本地修改
                                print("INFO: 檢測到衝突，雲端版本較新 - ID: \(cloudItem.id.uuidString)")
                                mergedItems[index] = cloudItem
                                updatedItems.append(cloudItem)
                                // 重置同步狀態，讓未來的同步處理衝突
                                self.localDataManager.updateSyncStatus(for: cloudItem.id, isSynced: false)
                            } else {
                                // 本地版本較新或相同，保持本地版本
                                print("INFO: 本地版本較新，保持本地修改 - ID: \(localItem.id.uuidString)")
                            }
                        } else {
                            // 本地已同步或無同步狀態，使用雲端版本
                            if cloudItem.updatedAt != localItem.updatedAt {
                                mergedItems[index] = cloudItem
                                updatedItems.append(cloudItem)
                                print("INFO: 更新本地項目為雲端版本 - ID: \(cloudItem.id.uuidString)")
                            }
                        }
                    } else {
                        // 雲端有新數據，添加到本地
                        mergedItems.append(cloudItem)
                        updatedItems.append(cloudItem)
                        print("INFO: 新增雲端項目到本地 - ID: \(cloudItem.id.uuidString)")
                    }
                }
                
                // 保存合併後的數據到本地
                if !updatedItems.isEmpty {
                    self.localDataManager.saveAllTodoItems(mergedItems)
                    print("INFO: 從 CloudKit 同步了 \(updatedItems.count) 個項目")
                }
                
                completion(.success(mergedItems))
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
