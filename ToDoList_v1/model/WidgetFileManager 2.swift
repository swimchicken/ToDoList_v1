//
//  WidgetFileManager.swift
//  ToDoList_v1
//
//  使用文件系統來共享 Widget 數據
//

import Foundation
import WidgetKit

class WidgetFileManager {
    static let shared = WidgetFileManager()
    
    // App Group ID
    private let appGroupID = "group.com.fcu.ToDolist"
    
    // 文件名
    private let fileName = "widget_tasks.json"
    
    private init() {}
    
    /// 獲取共享文件路徑
    private var sharedFileURL: URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }
        return containerURL.appendingPathComponent(fileName)
    }
    
    /// 保存今日任務到文件
    func saveTodayTasksToFile(_ allTasks: [TodoItem]) {
        guard let fileURL = sharedFileURL else {
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
        
        // 編碼並保存到文件
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(todayTasks)
            
            // 寫入文件
            try data.write(to: fileURL)
            
            
            // 驗證文件存在
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let fileSize = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int ?? 0
                
                // 通知 Widget 更新
                WidgetCenter.shared.reloadAllTimelines()
            }
        } catch {
        }
    }
    
    /// 從文件載入今日任務
    func loadTodayTasksFromFile() -> [TodoItem] {
        guard let fileURL = sharedFileURL else {
            return []
        }
        
        // 檢查文件是否存在
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        
        do {
            // 讀取文件
            let data = try Data(contentsOf: fileURL)
            
            // 解碼數據
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let tasks = try decoder.decode([TodoItem].self, from: data)
            
            return tasks
        } catch {
            return []
        }
    }
    
    /// 清除文件數據
    func clearFileData() {
        guard let fileURL = sharedFileURL else { return }
        
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
        }
    }
}