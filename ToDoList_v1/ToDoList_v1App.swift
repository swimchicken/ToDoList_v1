//
//  ToDoList_v1App.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/2/17.
//

import SwiftUI
import SwiftData
import GoogleSignIn
import UserNotifications
import WidgetKit

@main
struct ToDoList_v1App: App {
    @StateObject private var alarmStateManager = AlarmStateManager()
    
    // 暫時註解掉 Cloud 版的 ModelContainer 初始化
    /*
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    */
    
    init() {
        // 應用啟動時更新 Widget 數據
        updateWidgetData()
    }

    var body: some Scene {
        WindowGroup {
            //ContentView()
            ContentView()
                .environmentObject(alarmStateManager)
                .onOpenURL(perform: handleURL)  // 處理 Google Sign-In 回調
        }
        // 也暫時移除綁定 ModelContainer
        // .modelContainer(sharedModelContainer)
    }
    
    // MARK: - Google Sign-In URL 處理
    private func handleURL(_ url: URL) {
        if GIDSignIn.sharedInstance.handle(url) {
            return
        }
        print("收到 URL: \(url)")
    }
    
    
    
    // MARK: - Widget 數據管理
    /// 更新 Widget 數據
    private func updateWidgetData() {
        print("=== App 啟動：開始更新 Widget 數據 ===")
        
        // 獲取所有任務並更新 Widget
        let allTasks = LocalDataManager.shared.getAllTodoItems()
        print("從本地獲取到 \(allTasks.count) 個任務")
        
        // 使用 UserDefaults 保存
        WidgetDataManager.shared.saveTodayTasksForWidget(allTasks)
        
        // 使用文件系統保存，確保Widget可以找到數據文件
        WidgetFileManager.shared.saveTodayTasksToFile(allTasks)
        
        print("=== App 啟動：Widget 數據更新完成 ===")
        print()
        
        // 測試 Widget 數據存取
        testWidgetDataAccess()
    }
    
    /// 測試 Widget 數據存取
    private func testWidgetDataAccess() {
        print("\n=== 測試 Widget 數據存取 ===")
        
        // 檢查 App Group
        if let sharedDefaults = UserDefaults(suiteName: "group.com.fcu.ToDolist") {
            print("✅ App Group 'group.com.fcu.ToDolist' 配置正確")
            
            // 測試寫入
            sharedDefaults.set("test_from_main_app", forKey: "main_app_test_key")
            sharedDefaults.synchronize()
            
            // 檢查 Widget 是否有寫入數據
            if let widgetTest = sharedDefaults.string(forKey: "widget_test_key") {
                print("✅ 找到 Widget 寫入的測試數據: \(widgetTest)")
            }
            
            // 檢查是否有保存的數據
            if let data = sharedDefaults.data(forKey: "widget_today_tasks") {
                print("✅ 找到 Widget 數據，大小: \(data.count) bytes")
                
                // 嘗試解碼
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let tasks = try decoder.decode([TodoItem].self, from: data)
                    print("✅ 成功解碼 \(tasks.count) 個任務:")
                    for (index, task) in tasks.enumerated() {
                        print("  \(index + 1). \(task.title)")
                    }
                } catch {
                    print("❌ 解碼失敗: \(error)")
                }
            } else {
                print("⚠️ 沒有找到 Widget 數據")
                print("  提示：請在應用中添加今天的任務")
            }
        } else {
            print("❌ 無法訪問 App Group 'group.com.fcu.ToDolist'")
            print("  請檢查：")
            print("  1. 主應用和 Widget Extension 都已添加 App Groups capability")
            print("  2. 兩個 targets 都使用相同的 App Group ID: group.com.fcu.ToDolist")
        }
        
        print("=== 測試結束 ===\n")
    }
}
