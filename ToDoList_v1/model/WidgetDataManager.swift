//
//  WidgetDataManager.swift
//  ToDoList_v1
//
//  管理 Widget 數據的共享
//

import Foundation
import WidgetKit

class WidgetDataManager {
    static let shared = WidgetDataManager()
    
    // App Group ID - 需要與 Widget Extension 共享
    private let appGroupID = "group.com.fcu.ToDolist"
    
    // UserDefaults key
    private let todayTasksKey = "widget_today_tasks"
    private let widgetUpdatedKey = "widget_data_updated"
    private let widgetLastUpdateKey = "widget_last_update"
    
    private init() {}
    
    /// 保存今日任務供 Widget 使用
    func saveTodayTasksForWidget(_ allTasks: [TodoItem]) {
        // 修正：使用正確的 UserDefaults 初始化方式
        let sharedDefaults = UserDefaults(suiteName: appGroupID)
        guard let defaults = sharedDefaults else {
            print("❌ 無法訪問 App Group UserDefaults")
            return
        }
        
        // 過濾出今天的任務
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let todayTasks = allTasks.filter { task in
            guard let taskDate = task.taskDate else { return false }
            let taskStartOfDay = calendar.startOfDay(for: taskDate)
            return taskStartOfDay == today
        }
        
        // 編碼並保存
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(todayTasks)
            defaults.set(data, forKey: todayTasksKey)
            
            // 強制同步到磁盤
            defaults.synchronize()
            
            print("✅ 已保存 \(todayTasks.count) 個今日任務給 Widget")
            
            // 驗證保存
            if let savedData = defaults.data(forKey: todayTasksKey) {
                print("✅ 驗證：數據已成功保存，大小: \(savedData.count) bytes")
                
                // 通知 Widget 更新
                WidgetCenter.shared.reloadAllTimelines()
                print("✅ 已通知 Widget 更新")
            } else {
                print("❌ 驗證：數據保存失敗")
            }
        } catch {
            print("❌ 編碼任務失敗: \(error)")
        }
    }
    
    /// 從 Widget 中載入今日任務
    func loadTodayTasksFromWidget() -> [TodoItem] {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            print("❌ 無法訪問 App Group UserDefaults")
            return []
        }
        
        guard let data = sharedDefaults.data(forKey: todayTasksKey) else {
            print("⚠️ 沒有找到 Widget 任務數據")
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let tasks = try decoder.decode([TodoItem].self, from: data)
            print("✅ 從 Widget 載入了 \(tasks.count) 個任務")
            return tasks
        } catch {
            print("❌ 解碼任務失敗: \(error)")
            return []
        }
    }
    
    /// 清除 Widget 數據
    func clearWidgetData() {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            return
        }
        
        sharedDefaults.removeObject(forKey: todayTasksKey)
        print("✅ 已清除 Widget 數據")
    }
    
    /// 檢查 Widget 是否有更新
    func checkForWidgetUpdates() -> Bool {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            return false
        }
        
        return sharedDefaults.bool(forKey: widgetUpdatedKey)
    }
    
    /// 清除 Widget 更新標記
    func clearWidgetUpdateFlag() {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            return
        }
        
        sharedDefaults.set(false, forKey: widgetUpdatedKey)
        sharedDefaults.synchronize()
    }
    
    /// 同步 Widget 的更新到本地數據
    func syncWidgetUpdatesToLocal() -> [TodoItem]? {
        guard checkForWidgetUpdates() else {
            return nil
        }
        
        // 載入 Widget 更新後的數據
        let updatedTasks = loadTodayTasksFromWidget()
        
        // 清除更新標記
        clearWidgetUpdateFlag()
        
        print("✅ 已同步 Widget 更新的 \(updatedTasks.count) 個任務")
        return updatedTasks
    }
}