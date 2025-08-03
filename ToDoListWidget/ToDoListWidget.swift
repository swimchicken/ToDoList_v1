//
//  ToDoListWidget.swift
//  ToDoListWidget
//
//  顯示當日任務的 Widget
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), tasks: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), tasks: loadTodayTasks())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []
        let currentDate = Date()
        let tasks = loadTodayTasks()
        
        // 創建一個立即更新的 entry
        let immediateEntry = SimpleEntry(date: currentDate, tasks: tasks)
        entries.append(immediateEntry)
        
        // 然後每15分鐘更新一次（更頻繁的更新）
        for minuteOffset in stride(from: 15, to: 120, by: 15) {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, tasks: loadTodayTasks())
            entries.append(entry)
        }

        // 使用 .after 政策，在5分鐘後請求新的 timeline
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: currentDate)!
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }
    
    /// 載入今日任務
    func loadTodayTasks() -> [TodoItem] {
        print("Widget: 開始載入任務...")
        
        // 嘗試從文件系統載入
        let tasks = loadTasksFromFile()
        if !tasks.isEmpty {
            return tasks
        }
        
        // 如果文件系統失敗，嘗試 UserDefaults（保留作為備份）
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.fcu.ToDolist") else {
            print("Widget: ❌ 無法訪問 App Group")
            return sampleTasks()
        }
        
        if let data = sharedDefaults.data(forKey: "widget_today_tasks") {
            print("Widget: 從 UserDefaults 找到數據")
            return decodeTaskData(data)
        }
        
        return sampleTasks()
    }
    
    /// 從文件系統載入任務
    func loadTasksFromFile() -> [TodoItem] {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.fcu.ToDolist") else {
            print("Widget: ❌ 無法訪問 App Group 容器")
            return []
        }
        
        let fileURL = containerURL.appendingPathComponent("widget_tasks.json")
        
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
            
            print("Widget: ✅ 成功從文件載入 \(tasks.count) 個任務")
            for task in tasks {
                print("  - \(task.title)")
            }
            return tasks
        } catch {
            print("Widget: ❌ 從文件載入任務失敗: \(error)")
            return []
        }
    }
    
    /// 解碼任務數據
    func decodeTaskData(_ data: Data) -> [TodoItem] {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let tasks = try decoder.decode([TodoItem].self, from: data)
            print("Widget: ✅ 成功載入 \(tasks.count) 個任務")
            for task in tasks {
                print("  - \(task.title)")
            }
            return tasks.isEmpty ? sampleTasks() : tasks
        } catch {
            print("Widget: ❌ 解碼任務失敗 - \(error)")
            return sampleTasks() // 返回範例數據
        }
    }
    
    /// 範例任務（用於測試）
    func sampleTasks() -> [TodoItem] {
        return [
            TodoItem(
                id: UUID(),
                userID: "sample",
                title: "請在主應用中添加今日任務",
                priority: 2,
                isPinned: false,
                taskDate: Date(),
                note: "如果看到這個，表示 Widget 正在運行",
                status: .toBeStarted,
                createdAt: Date(),
                updatedAt: Date(),
                correspondingImageID: "info.circle"
            )
        ]
    }
}

// MARK: - Timeline Entry
struct SimpleEntry: TimelineEntry {
    let date: Date
    let tasks: [TodoItem]
}

// MARK: - Widget Views
struct ToDoListWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(tasks: entry.tasks)
        case .systemMedium:
            MediumWidgetView(tasks: entry.tasks)
        case .systemLarge:
            LargeWidgetView(tasks: entry.tasks)
        @unknown default:
            SmallWidgetView(tasks: entry.tasks)
        }
    }
}

// MARK: - Small Widget
struct SmallWidgetView: View {
    let tasks: [TodoItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 標題
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                Text("今日任務")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if tasks.isEmpty {
                Spacer()
                Text("今天沒有任務")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                // 顯示前3個任務
                ForEach(tasks.prefix(3)) { task in
                    HStack {
                        Circle()
                            .fill(priorityColor(task.priority))
                            .frame(width: 8, height: 8)
                        Text(task.title)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                    }
                }
                
                if tasks.count > 3 {
                    Text("還有 \(tasks.count - 3) 項任務")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
    
    func priorityColor(_ priority: Int) -> Color {
        switch priority {
        case 3: return .red
        case 2: return .orange
        case 1: return .blue
        default: return .gray
        }
    }
}

// MARK: - Medium Widget
struct MediumWidgetView: View {
    let tasks: [TodoItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 標題行
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                Text("今日任務")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(tasks.count) 項")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if tasks.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack {
                        Image(systemName: "checkmark.seal")
                            .font(.largeTitle)
                            .foregroundColor(.green)
                        Text("今天沒有任務")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                // 顯示前4個任務
                VStack(spacing: 6) {
                    ForEach(tasks.prefix(4)) { task in
                        HStack {
                            Circle()
                                .fill(priorityColor(task.priority))
                                .frame(width: 10, height: 10)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                if !task.note.isEmpty {
                                    Text(task.note)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            
                            Spacer()
                            
                            if task.isPinned {
                                Image(systemName: "pin.fill")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
                
                if tasks.count > 4 {
                    HStack {
                        Spacer()
                        Text("還有 \(tasks.count - 4) 項任務")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
    
    func priorityColor(_ priority: Int) -> Color {
        switch priority {
        case 3: return .red
        case 2: return .orange
        case 1: return .blue
        default: return .gray
        }
    }
}

// MARK: - Large Widget
struct LargeWidgetView: View {
    let tasks: [TodoItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 標題行
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title)
                Text("今日任務")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                VStack(alignment: .trailing) {
                    Text(Date(), style: .date)
                        .font(.caption)
                    Text("\(tasks.count) 項待完成")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            if tasks.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    Text("今天沒有任務")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text("享受美好的一天！")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(tasks) { task in
                            HStack {
                                Circle()
                                    .fill(priorityColor(task.priority))
                                    .frame(width: 12, height: 12)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(task.title)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        if task.isPinned {
                                            Image(systemName: "pin.fill")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                    
                                    if !task.note.isEmpty {
                                        Text(task.note)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                
                                Spacer()
                                
                                // 優先級標籤
                                Text(priorityText(task.priority))
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(priorityColor(task.priority).opacity(0.2))
                                    .foregroundColor(priorityColor(task.priority))
                                    .cornerRadius(4)
                            }
                            .padding(.vertical, 4)
                            
                            if task.id != tasks.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
    
    func priorityColor(_ priority: Int) -> Color {
        switch priority {
        case 3: return .red
        case 2: return .orange
        case 1: return .blue
        default: return .gray
        }
    }
    
    func priorityText(_ priority: Int) -> String {
        switch priority {
        case 3: return "高"
        case 2: return "中"
        case 1: return "低"
        default: return "無"
        }
    }
}

// MARK: - Widget Configuration
struct ToDoListWidget: Widget {
    let kind: String = "ToDoListWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ToDoListWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("今日任務")
        .description("查看今天的待辦事項")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview
#Preview(as: .systemSmall) {
    ToDoListWidget()
} timeline: {
    SimpleEntry(date: .now, tasks: [
        TodoItem(id: UUID(), userID: "", title: "完成專案報告", priority: 3, isPinned: true,
                taskDate: Date(), note: "下午3點前提交", status: .toBeStarted,
                createdAt: Date(), updatedAt: Date(), correspondingImageID: "")
    ])
}