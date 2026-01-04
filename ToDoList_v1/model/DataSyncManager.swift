//
//  DataSyncManager.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/5/10.
//

import Foundation
import Combine

/// 數據同步管理器 - 協調 CloudKit 和本地存儲之間的同步
class DataSyncManager {
    // MARK: - 單例模式
    static let shared = DataSyncManager()
    
    // MARK: - 屬性
    // CloudKit已移除，改為純API架構
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
        // print("DEBUG: 初始化 DataSyncManager") // 已廢棄，使用 API
        
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
            
            
            // 獲取新用戶ID
            if let userInfo = notification.userInfo,
               let newUserID = userInfo["newUserID"] as? String {
                
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
        
        // CloudKit已移除，改為純API架構

        // 發送完成通知
        syncStatusSubject.send(.completed(0))

        // 發布數據變化通知
        NotificationCenter.default.post(
            name: Notification.Name("TodoItemsDataRefreshed"),
            object: nil
        )
    }
    
    /// 清除本地數據
    private func clearLocalData() {
        
        // 使用 LocalDataManager 清除所有數據
        localDataManager.clearAllData()
        
        // 清除與數據相關的 UserDefaults 設置
        UserDefaults.standard.removeObject(forKey: "isSleepMode")
        UserDefaults.standard.removeObject(forKey: "alarmTimeString")
        UserDefaults.standard.removeObject(forKey: "lastSyncTime")
        UserDefaults.standard.removeObject(forKey: "completedDays") // 清除已完成日期數據
        
    }
    
    // MARK: - 公共方法
    
    /// 獲取待辦事項列表 - 首先從本地獲取，然後嘗試從 CloudKit 同步
    func fetchTodoItems(completion: @escaping (Result<[TodoItem], Error>) -> Void) {
        // 首先從本地獲取數據
        let localItems = localDataManager.getAllTodoItems()
        
        // 發送本地數據
        completion(.success(localItems))
        
        // 然後嘗試從 CloudKit 同步數據
        syncFromCloudKit { result in
            switch result {
            case .success(let updatedItems):
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
                    completion(.success(updatedItems))
                } else {
                    // 沒有更新，不需要額外操作
                }
            case .failure(let error):
                // 記錄錯誤，但不影響已經返回的本地數據
                break
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
                            self.localDataManager.updateSyncStatus(for: updatedItem.id, isSynced: true)
                        case .failure(let error):
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

            // 發送數據更新通知，讓 UI 重新載入
            NotificationCenter.default.post(name: Notification.Name("TodoItemsDataRefreshed"), object: nil)

            // 返回成功結果，不等待 CloudKit 同步完成
            completion(.success(updatedItem))
            
            // 在後台嘗試同步到 CloudKit
            DispatchQueue.global(qos: .background).async {
                self.syncItemToCloudKit(updatedItem) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success:
                            self.localDataManager.updateSyncStatus(for: updatedItem.id, isSynced: true)
                        case .failure(let error):
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
            
            // CloudKit已移除，改為純API架構
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
        // CloudKit已移除，改為純API架構
        completion(.success(item))
    }
    
    /// 從 CloudKit 獲取數據並與本地合併
    private func syncFromCloudKit(completion: @escaping (Result<[TodoItem], Error>) -> Void) {
        // 直接返回本地數據
        let localItems = localDataManager.getAllTodoItems()
        completion(.success(localItems))
    }
}
