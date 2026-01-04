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
    
    private init() {}
    
    /// 保存今日任務供 Widget 使用
    func saveTodayTasksForWidget(_ allTasks: [TodoItem]) {
        // 修正：使用正確的 UserDefaults 初始化方式
        let sharedDefaults = UserDefaults(suiteName: appGroupID)
        guard let defaults = sharedDefaults else {
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
            
            
            // 驗證保存
            if let savedData = defaults.data(forKey: todayTasksKey) {
                
                // 通知 Widget 更新
                WidgetCenter.shared.reloadAllTimelines()
            } else {
            }
        } catch {
        }
    }
    
    /// 從 Widget 中載入今日任務
    func loadTodayTasksFromWidget() -> [TodoItem] {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            return []
        }
        
        guard let data = sharedDefaults.data(forKey: todayTasksKey) else {
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let tasks = try decoder.decode([TodoItem].self, from: data)
            return tasks
        } catch {
            return []
        }
    }
    
    /// 清除 Widget 數據
    func clearWidgetData() {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            return
        }
        
        sharedDefaults.removeObject(forKey: todayTasksKey)
    }
}