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
            print("❌ 無法訪問 App Group 容器")
            return nil
        }
        return containerURL.appendingPathComponent(fileName)
    }
    
    /// 保存今日任務到文件
    func saveTodayTasksToFile(_ allTasks: [TodoItem]) {
        guard let fileURL = sharedFileURL else {
            print("❌ 無法獲取文件路徑")
            return
        }
        
        print("Debug: 開始保存任務到文件，總任務數: \(allTasks.count)")
        
        // 過濾出今天的任務
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let todayTasks = allTasks.filter { task in
            guard let taskDate = task.taskDate else { return false }
            let taskStartOfDay = calendar.startOfDay(for: taskDate)
            return taskStartOfDay == today
        }
        
        print("Debug: 過濾後的今日任務數: \(todayTasks.count)")
        
        // 編碼並保存到文件（即使沒有今日任務也要創建空文件）
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(todayTasks)
            
            // 確保目錄存在
            let directory = fileURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
                print("✅ 已創建目錄: \(directory.path)")
            }
            
            // 寫入文件
            try data.write(to: fileURL, options: .atomic)
            
            print("✅ 已保存 \(todayTasks.count) 個今日任務到文件")
            print("   文件路徑: \(fileURL.path)")
            
            // 驗證文件存在
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let fileSize = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int ?? 0
                print("✅ 驗證：文件已成功保存，大小: \(fileSize) bytes")
                
                // 通知 Widget 更新
                WidgetCenter.shared.reloadAllTimelines()
                print("✅ 已通知 Widget 更新")
            } else {
                print("❌ 文件寫入後仍然不存在")
            }
        } catch {
            print("❌ 保存任務到文件失敗: \(error)")
            print("   錯誤詳情: \(error.localizedDescription)")
        }
    }
    
    /// 從文件載入今日任務
    func loadTodayTasksFromFile() -> [TodoItem] {
        guard let fileURL = sharedFileURL else {
            print("Widget: ❌ 無法獲取文件路徑")
            return []
        }
        
        // 檢查文件是否存在
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("Widget: ❌ 文件不存在: \(fileURL.path)")
            return []
        }
        
        do {
            // 讀取文件
            let data = try Data(contentsOf: fileURL)
            print("Widget: ✅ 成功讀取文件，大小: \(data.count) bytes")
            
            // 解碼數據
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let tasks = try decoder.decode([TodoItem].self, from: data)
            
            print("Widget: ✅ 成功載入 \(tasks.count) 個任務")
            return tasks
        } catch {
            print("Widget: ❌ 載入任務失敗: \(error)")
            return []
        }
    }
    
    /// 清除文件數據
    func clearFileData() {
        guard let fileURL = sharedFileURL else { return }
        
        do {
            try FileManager.default.removeItem(at: fileURL)
            print("✅ 已清除 Widget 文件數據")
        } catch {
            print("❌ 清除文件失敗: \(error)")
        }
    }
}