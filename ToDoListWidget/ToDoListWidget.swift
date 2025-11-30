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
                taskType: .scheduled,
                completionStatus: .pending,
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
    
    // 計算完成進度
    var completionProgress: Double {
        guard !tasks.isEmpty else { return 0 }
        let completedCount = tasks.filter { $0.status == .completed }.count
        return Double(completedCount) / Double(tasks.count)
    }
    
    // 排序任務：未完成優先，已完成在後，按優先級排序
    var sortedTasks: [TodoItem] {
        tasks.sorted { task1, task2 in
            // 已完成的排在後面
            if task1.status == .completed && task2.status != .completed {
                return false
            }
            if task1.status != .completed && task2.status == .completed {
                return true
            }
            // 相同完成狀態，按優先級排序
            return task1.priority > task2.priority
        }
    }
    
    var body: some View {
        ZStack {
            // 深色背景
            Color.black
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 8) {
                // 頂部：標題和進度
                HStack {
                    Text("Today")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // 進度百分比
                    Text("\(Int(completionProgress * 100))%")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // 進度條
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 背景
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 4)
                        
                        // 進度
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.green)
                            .frame(width: geometry.size.width * CGFloat(completionProgress), height: 4)
                    }
                }
                .frame(height: 4)
                .padding(.bottom, 4)
                
                if tasks.isEmpty {
                    Spacer()
                    Text("今天沒有任務")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    // 顯示前3個任務（移除圓圈，只顯示文字）
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(sortedTasks.prefix(3)) { task in
                            SmallTaskRowView(task: task)
                        }
                    }
                    
                    Spacer(minLength: 2)
                    
                    // 顯示剩餘任務數
                    if sortedTasks.count > 3 {
                        Text("+\(sortedTasks.count - 3)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .containerBackground(for: .widget) {
            Color.black
        }
    }
}

// MARK: - Small Task Row View (簡化版，無圓圈)
struct SmallTaskRowView: View {
    let task: TodoItem
    
    var body: some View {
        HStack(spacing: 4) {
            // 優先級色塊（小而簡潔）
            if task.status != .completed {
                RoundedRectangle(cornerRadius: 2)
                    .fill(priorityColor)
                    .frame(width: 3, height: 14)
            }
            
            // 任務標題
            Text(task.title)
                .font(.system(size: 12, weight: task.status == .completed ? .regular : .medium))
                .foregroundColor(task.status == .completed ? .white.opacity(0.4) : .white)
                .lineLimit(1)
                .strikethrough(task.status == .completed)
            
            Spacer(minLength: 2)
        }
    }
    
    var priorityColor: Color {
        switch task.priority {
        case 3: return .red
        case 2: return .orange
        case 1: return .green
        default: return .gray
        }
    }
}

// MARK: - Task Row View (保留給舊版本使用)
struct TaskRowView: View {
    let task: TodoItem
    
    var body: some View {
        HStack(spacing: 8) {
            // 狀態圓圈
            ZStack {
                Circle()
                    .stroke(statusColor, lineWidth: 2)
                    .frame(width: 20, height: 20)
                
                if task.status == .completed {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 20, height: 20)
                }
            }
            
            // 任務標題
            Text(task.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(task.status == .completed ? .white.opacity(0.5) : .white)
                .lineLimit(1)
                .strikethrough(task.status == .completed)
            
            Spacer()
            
            // 重要度標記
            if task.priority == 3 {
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.yellow)
            }
            
            // 時間標記
            if let taskDate = task.taskDate {
                Text(taskDate, style: .time)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
    
    var statusColor: Color {
        if task.status == .completed {
            return .green
        }
        switch task.priority {
        case 3: return .red
        case 2: return .orange
        case 1: return .green
        default: return .gray
        }
    }
}

// MARK: - Medium Widget
struct MediumWidgetView: View {
    let tasks: [TodoItem]
    
    // 計算完成進度
    var completionProgress: Double {
        guard !tasks.isEmpty else { return 0 }
        let completedCount = tasks.filter { $0.status == .completed }.count
        return Double(completedCount) / Double(tasks.count)
    }
    
    // 排序任務：未完成優先，已完成在後，按優先級排序
    var sortedTasks: [TodoItem] {
        tasks.sorted { task1, task2 in
            // 已完成的排在後面
            if task1.status == .completed && task2.status != .completed {
                return false
            }
            if task1.status != .completed && task2.status == .completed {
                return true
            }
            // 相同完成狀態，按優先級排序
            return task1.priority > task2.priority
        }
    }
    
    var body: some View {
        ZStack {
            // 深色背景
            Color.black
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 10) {
                // 頂部：標題、進度條和百分比在同一行
                HStack(spacing: 12) {
                    Text("Today")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    // 進度條
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // 背景
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 6)
                            
                            // 進度
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.green)
                                .frame(width: geometry.size.width * CGFloat(completionProgress), height: 6)
                        }
                    }
                    .frame(height: 6)
                    
                    // 進度資訊
                    Text("\(Int(completionProgress * 100))%")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 40, alignment: .trailing)
                }
                
                if tasks.isEmpty {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack {
                            Image(systemName: "checkmark.seal")
                                .font(.system(size: 40))
                                .foregroundColor(.green)
                            Text("今天沒有任務")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()
                    }
                    Spacer()
                } else {
                    // 顯示前3個任務
                    VStack(spacing: 6) {
                        ForEach(sortedTasks.prefix(3)) { task in
                            MediumTaskRowView(task: task)
                        }
                    }
                    
                    if sortedTasks.count > 3 {
                        HStack {
                            Spacer()
                            Text("還有 \(sortedTasks.count - 3) 項")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                            Spacer()
                        }
                        .padding(.top, 2)
                    }
                    
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .containerBackground(for: .widget) {
            Color.black
        }
    }
}

// MARK: - Medium Task Row View
struct MediumTaskRowView: View {
    let task: TodoItem
    
    var body: some View {
        HStack(spacing: 10) {
            // 狀態圓圈（稍微縮小）
            ZStack {
                Circle()
                    .stroke(statusColor, lineWidth: 2)
                    .frame(width: 20, height: 20)
                
                if task.status == .completed {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 20, height: 20)
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black)
                }
            }
            
            // 任務資訊
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(task.status == .completed ? .white.opacity(0.5) : .white)
                    .lineLimit(1)
                    .strikethrough(task.status == .completed)
                
                if !task.note.isEmpty {
                    Text(task.note)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // 右側資訊
            HStack(spacing: 8) {
                // 重要度標記
                if task.priority == 3 {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)
                }
                
                // 固定標記
                if task.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                }
                
                // 時間標記
                if let taskDate = task.taskDate {
                    Text(taskDate, style: .time)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
    }
    
    var statusColor: Color {
        if task.status == .completed {
            return .green
        }
        switch task.priority {
        case 3: return .red
        case 2: return .orange
        case 1: return .green
        default: return .gray
        }
    }
}

// MARK: - Large Widget
struct LargeWidgetView: View {
    let tasks: [TodoItem]
    
    // 計算完成進度
    var completionProgress: Double {
        guard !tasks.isEmpty else { return 0 }
        let completedCount = tasks.filter { $0.status == .completed }.count
        return Double(completedCount) / Double(tasks.count)
    }
    
    // 排序任務：未完成優先，已完成在後，按優先級排序
    var sortedTasks: [TodoItem] {
        tasks.sorted { task1, task2 in
            // 已完成的排在後面
            if task1.status == .completed && task2.status != .completed {
                return false
            }
            if task1.status != .completed && task2.status == .completed {
                return true
            }
            // 相同完成狀態，按優先級排序
            return task1.priority > task2.priority
        }
    }
    
    var body: some View {
        ZStack {
            // 深色背景
            Color.black
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 8) {
                // 頂部：標題和進度
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(Date(), style: .date)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    // 進度資訊
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(completionProgress * 100))%")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.green)
                        
                        Text("\(tasks.filter { $0.status == .completed }.count)/\(tasks.count) 完成")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                // 進度條
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 背景
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 8)
                        
                        // 進度
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.green)
                            .frame(width: geometry.size.width * CGFloat(completionProgress), height: 8)
                    }
                }
                .frame(height: 8)
                
                // 分隔線
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 0.5)
                    .padding(.vertical, 3)
                
                if tasks.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Text("今天沒有任務")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.6))
                        Text("享受美好的一天！")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    // 任務列表（顯示前6個任務）
                    VStack(spacing: 2) {
                        ForEach(sortedTasks.prefix(6)) { task in
                            LargeTaskRowView(task: task)
                            
                            if task.id != sortedTasks.prefix(6).last?.id {
                                Rectangle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 0.5)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // 顯示剩餘任務數
                    if sortedTasks.count > 6 {
                        HStack {
                            Spacer()
                            Text("還有 \(sortedTasks.count - 6) 項任務")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                            Spacer()
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .containerBackground(for: .widget) {
            Color.black
        }
    }
}

// MARK: - Large Task Row View
struct LargeTaskRowView: View {
    let task: TodoItem
    
    var body: some View {
        HStack(spacing: 12) {
            // 狀態圓圈
            ZStack {
                Circle()
                    .stroke(statusColor, lineWidth: 2)
                    .frame(width: 22, height: 22)
                
                if task.status == .completed {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 22, height: 22)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.black)
                }
            }
            
            // 任務資訊
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(task.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(task.status == .completed ? .white.opacity(0.5) : .white)
                        .strikethrough(task.status == .completed)
                    
                    if task.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                }
                
                if !task.note.isEmpty {
                    Text(task.note)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // 右側資訊
            VStack(alignment: .trailing, spacing: 6) {
                // 優先級標籤
                HStack(spacing: 4) {
                    if task.priority == 3 {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.yellow)
                    }
                    
                    Text(priorityText(task.priority))
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(priorityColor(task.priority).opacity(0.2))
                        .foregroundColor(priorityColor(task.priority))
                        .cornerRadius(3)
                }
                
                // 時間標記
                if let taskDate = task.taskDate {
                    Text(taskDate, style: .time)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
    }
    
    var statusColor: Color {
        if task.status == .completed {
            return .green
        }
        switch task.priority {
        case 3: return .red
        case 2: return .orange
        case 1: return .green
        default: return .gray
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
                taskDate: Date(), note: "下午3點前提交",
                taskType: .scheduled, completionStatus: .pending, status: .toBeStarted,
                createdAt: Date(), updatedAt: Date(), correspondingImageID: "")
    ])
}