//
//  LocalDataManager.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/5/10.
//

import Foundation
import WidgetKit

/// 本地數據管理器 - 使用 UserDefaults 存儲待辦事項
class LocalDataManager {
    // MARK: - 單例模式
    static let shared = LocalDataManager()
    
    // MARK: - 常量
    private let todoItemsKey = "localTodoItems"
    private let syncStatusKey = "todoItemsSyncStatus"
    private let lastSyncTimeKey = "todoItemsLastSyncTime"
    
    // MARK: - 初始化
    private init() {
        print("DEBUG: 初始化 LocalDataManager")
    }
    
    // MARK: - 同步狀態
    struct SyncStatus: Codable {
        var itemID: UUID
        var isSynced: Bool
        var lastSyncTime: Date?
        var syncError: String?
        
        init(itemID: UUID, isSynced: Bool = false, lastSyncTime: Date? = nil, syncError: String? = nil) {
            self.itemID = itemID
            self.isSynced = isSynced
            self.lastSyncTime = lastSyncTime
            self.syncError = syncError
        }
    }
    
    // MARK: - 本地存儲 CRUD 方法
    
    /// 獲取所有本地待辦事項
    func getAllTodoItems() -> [TodoItem] {
        guard let data = UserDefaults.standard.data(forKey: todoItemsKey) else {
            print("DEBUG: 本地無待辦事項數據")
            return []
        }
        
        do {
            let todoItems = try JSONDecoder().decode([TodoItem].self, from: data)
            print("DEBUG: 從本地加載 \(todoItems.count) 個待辦事項")
            return todoItems
        } catch {
            print("ERROR: 解碼本地待辦事項失敗 - \(error.localizedDescription)")
            return []
        }
    }
    
    /// 保存所有待辦事項到本地
    func saveAllTodoItems(_ todoItems: [TodoItem]) {
        do {
            let data = try JSONEncoder().encode(todoItems)
            UserDefaults.standard.set(data, forKey: todoItemsKey)
            print("DEBUG: 成功保存 \(todoItems.count) 個待辦事項到本地")
            
            // 同步更新 Widget 數據
            WidgetDataManager.shared.saveTodayTasksForWidget(todoItems)
            // 使用文件系統保存，確保Widget可以找到數據文件
            WidgetFileManager.shared.saveTodayTasksToFile(todoItems)
        } catch {
            print("ERROR: 編碼待辦事項失敗 - \(error.localizedDescription)")
        }
    }
    
    /// 添加一個待辦事項
    func addTodoItem(_ item: TodoItem) {
        var items = getAllTodoItems()
        
        // 檢查是否已存在相同 ID 的項目
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            print("DEBUG: 更新本地現有待辦事項 - ID: \(item.id.uuidString)")
        } else {
            items.append(item)
            print("DEBUG: 添加新待辦事項到本地 - ID: \(item.id.uuidString)")
        }
        
        saveAllTodoItems(items)
        updateSyncStatus(for: item.id, isSynced: false, error: nil)
    }
    
    /// 更新一個待辦事項
    func updateTodoItem(_ item: TodoItem) {
        var items = getAllTodoItems()
        
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            saveAllTodoItems(items)
            updateSyncStatus(for: item.id, isSynced: false, error: nil)
            print("DEBUG: 本地更新待辦事項 - ID: \(item.id.uuidString)")
        } else {
            print("WARNING: 嘗試更新不存在的待辦事項 - ID: \(item.id.uuidString)，將添加它")
            addTodoItem(item)
        }
    }
    
    /// 刪除一個待辦事項
    func deleteTodoItem(withID id: UUID) {
        var items = getAllTodoItems()
        
        if let index = items.firstIndex(where: { $0.id == id }) {
            items.remove(at: index)
            saveAllTodoItems(items)
            print("DEBUG: 從本地刪除待辦事項 - ID: \(id.uuidString)")
        } else {
            print("WARNING: 嘗試刪除不存在的待辦事項 - ID: \(id.uuidString)")
        }
        
        // 從同步狀態中也刪除
        removeSyncStatus(for: id)
    }
    
    /// 獲取一個特定的待辦事項
    func getTodoItem(withID id: UUID) -> TodoItem? {
        let items = getAllTodoItems()
        return items.first(where: { $0.id == id })
    }
    
    // MARK: - 同步狀態管理方法
    
    /// 取得所有同步狀態
    private func getAllSyncStatus() -> [SyncStatus] {
        guard let data = UserDefaults.standard.data(forKey: syncStatusKey) else {
            return []
        }
        
        do {
            return try JSONDecoder().decode([SyncStatus].self, from: data)
        } catch {
            print("ERROR: 解碼同步狀態失敗 - \(error.localizedDescription)")
            return []
        }
    }
    
    /// 保存所有同步狀態
    private func saveAllSyncStatus(_ statusList: [SyncStatus]) {
        do {
            let data = try JSONEncoder().encode(statusList)
            UserDefaults.standard.set(data, forKey: syncStatusKey)
        } catch {
            print("ERROR: 編碼同步狀態失敗 - \(error.localizedDescription)")
        }
    }
    
    /// 更新項目的同步狀態
    func updateSyncStatus(for itemID: UUID, isSynced: Bool, lastSyncTime: Date? = Date(), error: String? = nil) {
        var statusList = getAllSyncStatus()
        
        if let index = statusList.firstIndex(where: { $0.itemID == itemID }) {
            statusList[index].isSynced = isSynced
            statusList[index].lastSyncTime = lastSyncTime
            statusList[index].syncError = error
        } else {
            let newStatus = SyncStatus(
                itemID: itemID,
                isSynced: isSynced,
                lastSyncTime: lastSyncTime,
                syncError: error
            )
            statusList.append(newStatus)
        }
        
        saveAllSyncStatus(statusList)
    }
    
    /// 移除項目的同步狀態
    private func removeSyncStatus(for itemID: UUID) {
        var statusList = getAllSyncStatus()
        statusList.removeAll { $0.itemID == itemID }
        saveAllSyncStatus(statusList)
    }
    
    /// 獲取項目的同步狀態
    func getSyncStatus(for itemID: UUID) -> SyncStatus? {
        let statusList = getAllSyncStatus()
        return statusList.first { $0.itemID == itemID }
    }
    
    /// 獲取所有需要同步的項目 ID
    func getUnsyncedItemIDs() -> [UUID] {
        let statusList = getAllSyncStatus()
        return statusList.filter { !$0.isSynced }.map { $0.itemID }
    }
    
    /// 更新最後同步時間
    func updateLastSyncTime() {
        let now = Date()
        UserDefaults.standard.set(now, forKey: lastSyncTimeKey)
        print("DEBUG: 更新最後同步時間: \(now)")
    }
    
    /// 獲取最後同步時間
    func getLastSyncTime() -> Date? {
        return UserDefaults.standard.object(forKey: lastSyncTimeKey) as? Date
    }
    
    // MARK: - 便利方法
    
    /// 清除所有本地數據
    func clearAllData() {
        UserDefaults.standard.removeObject(forKey: todoItemsKey)
        UserDefaults.standard.removeObject(forKey: syncStatusKey)
        UserDefaults.standard.removeObject(forKey: lastSyncTimeKey)
        UserDefaults.standard.removeObject(forKey: "hasShownWelcomeItem") // 確保清除歡迎項目狀態
        print("DEBUG: 已清除所有本地存儲的待辦事項和同步狀態")
    }
    
    /// 保存所有本地更改
    /// 確保所有待辦事項的更改都被同步保存到 UserDefaults
    func saveAllChanges() {
        // 獲取當前所有待辦事項並重新保存它們
        // 這可以確保所有內存中的變更都被寫入到持久化存儲
        let items = getAllTodoItems()
        saveAllTodoItems(items)
        print("DEBUG: 保存了所有本地待辦事項更改")
        
        // 更新最後同步時間，但不改變同步狀態
        // 這表示資料已保存到本地，但尚未同步到雲端
        updateLastSyncTime()
    }
}
