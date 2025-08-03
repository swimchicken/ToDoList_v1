//
//  WidgetTestButton.swift
//  ToDoList_v1
//
//  測試 Widget 數據的按鈕
//

import SwiftUI

struct WidgetTestButton: View {
    var body: some View {
        Button(action: {
            testWidgetData()
        }) {
            Label("測試 Widget 數據", systemImage: "square.grid.2x2")
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
    }
    
    func testWidgetData() {
        // 創建測試任務
        let testTask = TodoItem(
            id: UUID(),
            userID: "test",
            title: "Widget 測試任務 - \(Date().formatted())",
            priority: 3,
            isPinned: false,
            taskDate: Date(), // 今天
            note: "如果在 Widget 看到這個，表示正常工作",
            status: .toBeStarted,
            createdAt: Date(),
            updatedAt: Date(),
            correspondingImageID: "star"
        )
        
        // 添加到本地存儲
        LocalDataManager.shared.addTodoItem(testTask)
        
        // 手動觸發 Widget 數據更新
        let allTasks = LocalDataManager.shared.getAllTodoItems()
        WidgetDataManager.shared.saveTodayTasksForWidget(allTasks)
        
        // 驗證 App Group
        if let sharedDefaults = UserDefaults(suiteName: "group.com.fcu.ToDolist") {
            print("✅ App Group 配置正確")
            
            if let data = sharedDefaults.data(forKey: "widget_today_tasks") {
                print("✅ Widget 數據已保存，大小: \(data.count) bytes")
                
                // 嘗試解碼驗證
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let tasks = try decoder.decode([TodoItem].self, from: data)
                    print("✅ 成功解碼 \(tasks.count) 個任務")
                    for task in tasks {
                        print("  - \(task.title)")
                    }
                } catch {
                    print("❌ 解碼失敗: \(error)")
                }
            } else {
                print("❌ 沒有找到 Widget 數據")
            }
        } else {
            print("❌ 無法訪問 App Group")
        }
    }
}