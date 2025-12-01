import SwiftUI


// MARK: - Task Selection Overlay (Refactored for TodoItem)
struct TaskSelectionOverlay: View {
    // MARK: - Properties
    @Binding var tasks: [TodoItem]
    let onCancel: () -> Void
    let onAdd: ([TodoItem]) -> Void
    let onEditTask: (TodoItem) -> Void
    
    @State private var selectedTasks: Set<UUID> = []
    
    @State private var appearing = false
    
    // MARK: - Computed Properties
    private var groupedTasks: [(String, [TodoItem])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        var groups: [String: [TodoItem]] = [:]
        
        for task in tasks {
            var groupKey = "待辦事項佇列"
            if let taskDate = task.taskDate {
                let taskStartOfDay = calendar.startOfDay(for: taskDate)
                
                if taskStartOfDay == today { groupKey = "Today" }
                else if taskStartOfDay == tomorrow { groupKey = "Tomorrow" }
                else if taskDate > Date() {
                    let formatter = DateFormatter(); formatter.dateFormat = "MM/dd"
                    groupKey = formatter.string(from: taskDate)
                } else { groupKey = "待辦事項佇列" }
            }
            
            if groups[groupKey] != nil { groups[groupKey]?.append(task) }
            else { groups[groupKey] = [task] }
        }
        
        var sortedGroups: [(String, [TodoItem])] = []
        if let todayTasks = groups["Today"] { sortedGroups.append(("Today", todayTasks)) }
        if let tomorrowTasks = groups["Tomorrow"] { sortedGroups.append(("Tomorrow", tomorrowTasks)) }
        let otherDates = groups.keys.filter { $0 != "Today" && $0 != "Tomorrow" && $0 != "待辦事項佇列" }.sorted()
        for date in otherDates { if let tasks = groups[date] { sortedGroups.append((date, tasks)) } }
        if let queueTasks = groups["待辦事項佇列"] { sortedGroups.append(("待辦事項佇列", queueTasks)) }
        
        return sortedGroups
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // 【修改重點】背景效果已完全同步為 add.swift 的樣式
            Color(red: 0.22, green: 0.22, blue: 0.22).opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) { appearing = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onCancel() }
                }
            
            VStack(spacing: 0) {
                if groupedTasks.isEmpty {
                    emptyStateView
                } else {
                    taskList
                }
                
                Spacer()
                
                bottomButtons
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(appearing ? 1 : 0.95).opacity(appearing ? 1 : 0)
        }
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appearing = true } }
        
    }
    
    // MARK: - Helper Methods
    private func deleteTask(_ taskToDelete: TodoItem) {
        selectedTasks.remove(taskToDelete.id)
        tasks.removeAll { $0.id == taskToDelete.id }
    }
}

// MARK: - Subviews
private extension TaskSelectionOverlay {
    
    var emptyStateView: some View {
        VStack {
            Spacer()
            Text("task_selection.no_todos")
                .font(.title2)
                .foregroundColor(.white.opacity(0.6))
            Spacer()
        }
    }
    
    var taskList: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(groupedTasks, id: \.0) { group in
                    TaskGroupView(
                        group: group,
                        onEdit: { task in onEditTask(task) },
                        onDelete: { task in withAnimation { deleteTask(task) } }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 50)
        }
    }
    
    var bottomButtons: some View {
        HStack {
            Button(action: {
                withAnimation(.spring(response: 0.3)) { appearing = false }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onCancel() }
            }) {
                Text("common.cancel")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding()
                    .fixedSize(horizontal: true, vertical: false)
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            Button(action: {
                if !tasks.isEmpty { onAdd(tasks) }
            }) {
                Text("common.add")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 260, height: 60)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }
}


// MARK: - Task Group View (Extracted to solve compiler issue)
private struct TaskGroupView: View {
    let group: (String, [TodoItem])
    let onEdit: (TodoItem) -> Void
    let onDelete: (TodoItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("add.title").font(.system(size: 13, weight: .regular)).foregroundStyle(.white.opacity(0.7))
                Text(group.0).font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                Spacer()
            }.padding(.horizontal, 16).padding(.vertical, 7)
            
            VStack(spacing: 0) {
                ForEach(Array(group.1.enumerated()), id: \.element.id) { index, task in
                    if index > 0 { Rectangle().fill(Color.white.opacity(0.15)).frame(height: 0.5).padding(.horizontal, 16) }
                    
                    TaskSelectionRow(
                        task: task,
                        onEdit: { onEdit(task) },
                        onDelete: { onDelete(task) }
                    )
                }
            }
        }
        .background(Color.white.opacity(0.15))
        .cornerRadius(16)
    }
}


// MARK: - Task Selection Row (無變動)
struct TaskSelectionRow: View {
    let task: TodoItem
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    private func formatTime(from date: Date?) -> String? {
        guard let date = date else { return nil }
        
        let calendar = Calendar.current
        if calendar.component(.hour, from: date) == 0 && calendar.component(.minute, from: date) == 0 {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onEdit) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(task.title).font(.system(size: 16, weight: .medium)).foregroundColor(.white).lineLimit(1)
                        if task.note.isEmpty {
                            // 如果沒有備註，顯示 "note" 佔位符
                            Text("common.note")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        } else {
                            // 如果有備註，只顯示備註內容
                            Text(task.note)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(2)
                        }
                    }
                    .padding(.leading, 16)
                    
                    Spacer()
                    
                    // --- 請貼上這段新程式碼 ---
                    HStack(spacing: 4) {
                        // 新增的判斷邏輯：
                        if task.isPinned {
                            // 如果任務被置頂，顯示旗子
                            Image("Pin") // 假設您有這個圖片資源
                                .resizable()
                                .renderingMode(.template)
                                .scaledToFit()
                                .foregroundColor(.white) // 設定為白色
                                .frame(width: 14, height: 14) // 與星星大小一致
                                // 為了讓旗子和三顆星佔據的寬度一樣，維持對齊
                                .padding(.horizontal, 16)

                        } else {
                            // 如果沒有置頂，才顯示原本的星星邏輯
                            if task.priority > 0 {
                                HStack(spacing: 2) {
                                    ForEach(0..<3, id: \.self) { index in
                                        Image("Star 1 (3)")
                                            .resizable()
                                            .renderingMode(.template)
                                            .scaledToFit()
                                            .frame(width: 14, height: 14)
                                            .foregroundColor(index < task.priority ? .white : .clear)
                                    }
                                }
                            }
                        }

                        // [時間邏輯不變]
                        Text(formatTime(from: task.taskDate) ?? "")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(minWidth: 50, alignment: .trailing)
                    }
                }
            }.buttonStyle(PlainButtonStyle())
            
            Button(action: onDelete) {
                Image(systemName: "xmark").font(.system(size: 16)).foregroundColor(.white.opacity(0.5)).padding(8).contentShape(Rectangle())
            }.buttonStyle(PlainButtonStyle()).padding(.trailing, 4)
        }
        .padding(.vertical, 8)
    }
}

