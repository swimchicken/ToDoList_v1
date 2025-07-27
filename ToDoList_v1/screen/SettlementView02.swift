import SwiftUI

// MARK: - S02ProgressBarSegment (專為 SettlementView02 設計的進度條樣式)
struct S02ProgressBarSegment: View {
    let isActive: Bool // true: 帶綠色邊框的灰色; false: 純灰色
    let width: CGFloat
    private let segmentHeight: CGFloat = 11
    private let segmentCornerRadius: CGFloat = 29

    var body: some View {
        ZStack {
            // 背景統一為深灰色
            Rectangle()
                .fill(Color(red: 0.13, green: 0.13, blue: 0.13))
                .frame(width: width, height: segmentHeight)
                .cornerRadius(segmentCornerRadius)

            // 如果是 active，才加上綠色邊框
            if isActive {
                RoundedRectangle(cornerRadius: segmentCornerRadius)
                    .inset(by: 0.5)
                    .stroke(Color(red: 0, green: 0.72, blue: 0.41), lineWidth: 1)
            }
        }
        .frame(width: width, height: segmentHeight) // 確保 ZStack 大小正確
    }
}

// MARK: - SettlementView02.swift
struct SettlementView02: View {
    @Environment(\.presentationMode) var presentationMode
    
    // 接收從SettlementView傳遞的未完成任務和設置
    let uncompletedTasks: [TodoItem]
    let moveTasksToTomorrow: Bool
    
    // 用於顯示的明日任務列表
    @State private var dailyTasks: [TodoItem] = []
    
    // 所有待辦事項（與 Home.swift 保持一致）
    @State private var allTodoItems: [TodoItem] = []
    
    // 初始化方法 - 接收未完成任務和是否移至明日的設置
    init(uncompletedTasks: [TodoItem], moveTasksToTomorrow: Bool) {
        self.uncompletedTasks = uncompletedTasks
        self.moveTasksToTomorrow = moveTasksToTomorrow
        
        // 如果選擇將未完成任務移至明日，則使用這些任務初始化明日任務列表
        // 否則使用空列表
        let initialDailyTasks = moveTasksToTomorrow ? uncompletedTasks : []
        self._dailyTasks = State(initialValue: initialDailyTasks)
        
        // 初始化所有待辦事項
        self._allTodoItems = State(initialValue: [])
    }
    @State private var selectedFilterInSettlement = "全部"
    @State private var showTodoQueue: Bool = false
    @State private var navigateToSettlementView03: Bool = false // 導航到下一頁
    
    // 延遲結算管理器
    private let delaySettlementManager = DelaySettlementManager.shared
    
    private var tomorrow: Date { Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date() }

    private func formatDateForDisplay(_ date: Date) -> (monthDay: String, weekday: String) {
        let dateFormatterMonthDay = DateFormatter()
        dateFormatterMonthDay.locale = Locale(identifier: "en_US_POSIX")
        dateFormatterMonthDay.dateFormat = "MMM dd"
        let dateFormatterWeekday = DateFormatter()
        dateFormatterWeekday.locale = Locale(identifier: "en_US_POSIX")
        dateFormatterWeekday.dateFormat = "EEEE"
        return (dateFormatterMonthDay.string(from: date), dateFormatterWeekday.string(from: date))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 15) {
                    HStack(spacing: 8) {
                        // 进度条部分
                        ProgressBarView()
                        
                        // 勾选图标部分
                        CheckmarkView()
                    }
                    .padding(.top, 5)
                    // ... (SettlementView02 的其餘頂部內容，如您之前提供)
                    // 分隔线
                    DividerView()
                    
                    // 唤醒文本
                    WakeUpTitleView()
                    
                    // 明日日期显示
                    TomorrowDateView(tomorrow: tomorrow, formatDateForDisplay: formatDateForDisplay)
                    
                    // 闹钟信息
                    AlarmInfoView()
                    Image("Vector 81").resizable().aspectRatio(contentMode: .fit).frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 15)

                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        // 任务列表
                        TaskListView(
                            tasks: dailyTasks, 
                            onDeleteTask: { taskToDelete in
                                deleteTask(taskToDelete)
                            },
                            onTaskAdded: {
                                loadTasksFromDataManager()
                            }
                        )
                        .padding(.top, 10)
                    }
                     // 估算底部固定UI高度，為ScrollView增加padding，避免遮擋
                    .padding(.bottom, showTodoQueue ? 380 : 200) // 简化padding计算，确保有足够空间
                }
                .scrollIndicators(.hidden)
                .padding(.horizontal, 12)
            }
            .padding(.top, 60)

            VStack(spacing: 0) {
                if showTodoQueue {
                    SettlementTodoQueueView(
                        items: $allTodoItems,
                        selectedFilter: $selectedFilterInSettlement,
                        collapseAction: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                showTodoQueue = false
                            }
                        },
                        onTaskAdded: {
                            loadTasksFromDataManager()
                        }
                    )
                    .padding(.horizontal, 12)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity).animation(.spring(response: 0.4, dampingFraction: 0.85)),
                        removal: .move(edge: .bottom).combined(with: .opacity).animation(.easeInOut(duration: 0.2))
                    ))
                    .padding(.bottom, 10)
                } else {
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            showTodoQueue.toggle()
                        }
                    }) {
                        HStack {
                            Text("待辦事項佇列")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.8))
                            Spacer()
                            Image(systemName: "chevron.up")
                                .foregroundColor(Color.white.opacity(0.8))
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .background(Color(white: 0.12))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeInOut(duration: 0.2)),
                        removal: .opacity.animation(.easeInOut(duration: 0.05))
                    ))
                }
                HStack {
                    Button(action: {
                        // 返回上一頁
                        self.presentationMode.wrappedValue.dismiss()
                    }) { 
                        Text("返回")
                            .font(Font.custom("Inria Sans", size: 20))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .center) // 使整個按鈕區域可點擊
                    }.padding()
                    Spacer()
                    Button(action: {
                        // 因為這是當天結算流程的最後一步（不再進入 SettlementView03）
                        // 所以直接標記結算完成
                        delaySettlementManager.markSettlementCompleted()
                        print("SettlementView02 - 已標記結算完成")
                        
                        // 仍然導航到 SettlementView03 來設置鬧鐘
                        navigateToSettlementView03 = true
                    }) { 
                        Text("Next")
                            .font(Font.custom("Inria Sans", size: 20).weight(.bold))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity, alignment: .center) // 使整個按鈕區域可點擊
                    }
                    .frame(width: 279, height: 60).background(.white).cornerRadius(40.5)
                }
                .padding(.horizontal, 12)
            }
            .padding(.bottom, 60)
            .background(Color.black)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // 日志输出，便于调试
            print("SettlementView02 - onAppear: 移动未完成任务设置 = \(moveTasksToTomorrow)")
            print("SettlementView02 - onAppear: 未完成任务数量 = \(uncompletedTasks.count)")
            
            // 重新載入任務列表以確保數據同步
            loadTasksFromDataManager()
        }
        .background(
            NavigationLink(destination: SettlementView03(), isActive: $navigateToSettlementView03) {
                EmptyView()
            }
        )
    }
    
    // MARK: - 任務管理功能
    
    /// 從 DataManager 重新載入任務列表
    private func loadTasksFromDataManager() {
        // 從 LocalDataManager 獲取最新的數據（與 Home.swift 保持一致）
        let allItems = LocalDataManager.shared.getAllTodoItems()
        
        // 更新所有待辦事項（與 Home.swift 同步）
        allTodoItems = allItems
        print("SettlementView02 - 載入所有待辦事項: \(allTodoItems.count) 個")
        
        if moveTasksToTomorrow {
            // 如果設置移動未完成任務到明日，顯示相關任務
            // 這裡需要找出今天未完成且已移動到明日的任務
            dailyTasks = allItems.filter { item in
                // 檢查是否為明日任務（狀態為 toBeStarted 或 undone）
                item.status == .toBeStarted || item.status == .undone
            }
            print("SettlementView02 - 重新載入明日任務: \(dailyTasks.count) 個")
        } else {
            dailyTasks = []
            print("SettlementView02 - 清空任務列表")
        }
    }
    
    /// 刪除任務
    private func deleteTask(_ task: TodoItem) {
        print("SettlementView02: 開始刪除任務 - \(task.title)")
        
        // 使用 DataSyncManager 刪除任務
        DataSyncManager.shared.deleteTodoItem(withID: task.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success():
                    print("SettlementView02: 成功刪除任務 - \(task.title)")
                    // 重新載入任務列表以確保同步
                    self.loadTasksFromDataManager()
                    
                case .failure(let error):
                    print("SettlementView02: 刪除任務失敗 - \(error.localizedDescription)")
                    // 即使雲端刪除失敗，也重新載入本地數據
                    self.loadTasksFromDataManager()
                }
            }
        }
    }
}
// MARK: - 辅助视图组件
// 进度条视图组件
struct ProgressBarView: View {
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 8) {
                let segmentWidth = (geometry.size.width - 8) / 2
                // 第一個是 active (灰底綠框)，第二個是 inactive (純灰色)
                S02ProgressBarSegment(isActive: true, width: segmentWidth)
                S02ProgressBarSegment(isActive: false, width: segmentWidth)
            }
        }
        .frame(height: 11)
    }
}

// 勾选图标组件
struct CheckmarkView: View {
    var body: some View {
        Image(systemName: "checkmark")
            .foregroundColor(.gray)
            .padding(5)
            .background(Color.gray.opacity(0.3))
            .clipShape(Circle())
    }
}

// 分隔线视图
struct DividerView: View {
    var body: some View {
        Rectangle()
            .frame(height: 1)
            .foregroundColor(Color(red: 0.34, green: 0.34, blue: 0.34))
            .padding(.vertical, 10)
    }
}

// 唤醒标题视图
struct WakeUpTitleView: View {
    var body: some View {
        HStack {
            Text("What do you want to wake up at")
                .font(Font.custom("Instrument Sans", size: 13).weight(.semibold))
                .foregroundColor(.white)
            Spacer()
        }
    }
}

// 明日日期视图
struct TomorrowDateView: View {
    let tomorrow: Date
    let formatDateForDisplay: (Date) -> (monthDay: String, weekday: String)
    
    var body: some View {
        let tomorrowParts = formatDateForDisplay(tomorrow)
        
        HStack(alignment: .bottom) {
            // 左侧"明日"文本
            Text("Tomorrow")
                .font(Font.custom("Instrument Sans", size: 31.79449).weight(.bold))
                .foregroundColor(.white)
            
            Spacer()
            
            // 右侧日期文本 - 改用 HStack 替代 Text 连接
            HStack(spacing: 2) {
                Text(tomorrowParts.monthDay)
                    .font(Font.custom("Instrument Sans", size: 20.65629).weight(.bold))
                    .foregroundColor(.white)
                
                Text("   ") // 空格
                
                Text(tomorrowParts.weekday)
                    .font(Font.custom("Instrument Sans", size: 20.65629).weight(.bold))
                    .foregroundColor(.gray)
            }
        }
    }
}

// 闹钟信息视图
struct AlarmInfoView: View {
    var body: some View {
        HStack {
            Image(systemName: "bell")
                .foregroundColor(.blue)
                .font(.system(size: 11.73462))
            
            Text("9:00 awake")
                .font(Font.custom("Inria Sans", size: 11.73462))
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
            
            Spacer()
        }
    }
}

// 任务列表视图
struct TaskListView: View {
    let tasks: [TodoItem]
    let onDeleteTask: (TodoItem) -> Void
    let onTaskAdded: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 显示任务列表（如果有任务）
            if !tasks.isEmpty {
                ForEach(tasks.indices, id: \.self) { index in
                    TaskRowView(task: tasks[index], isLast: index == tasks.count - 1, onDelete: onDeleteTask)
                }
            }
            
            // 无论有没有任务都显示添加按钮，简单地放在列表末尾
            AddTaskButton(onTaskAdded: onTaskAdded)
        }
    }
}

// 单个任务行视图
struct TaskRowView: View {
    let task: TodoItem
    let isLast: Bool
    let onDelete: (TodoItem) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 任务内容
            HStack(spacing: 12) {
                // 图标
                TaskIconView()
                
                // 标题
                Text(task.title)
                    .font(Font.custom("Inria Sans", size: 16).weight(.bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .layoutPriority(1)
                
                Spacer()
                
                // 右侧信息（优先级、时间、删除按钮）
                TaskRightInfoView(task: task, onDelete: onDelete)
            }
            .padding(.vertical, 12)
            
            // 分隔线（如果不是最后一项）
            if !isLast {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(red: 0.34, green: 0.34, blue: 0.34))
            }
        }
    }
}

// 任务图标视图
struct TaskIconView: View {
    var body: some View {
        ZStack {
            Rectangle()
                .foregroundColor(.clear)
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.15))
                .cornerRadius(40.5)
            
            Image("Vector")
                .resizable()
                .scaledToFit()
                .frame(width: 15.35494, height: 14.54678)
        }
    }
}

// 任务右侧信息视图
struct TaskRightInfoView: View {
    let task: TodoItem
    let onDelete: (TodoItem) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 置顶或优先级星星
            Group {
                if task.isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 14))
                } else {
                    PriorityStarsView(priority: task.priority)
                }
            }
            .frame(minWidth: 14 * 3 + 2 * 2, alignment: .leading)
            
            // 时间显示
            TimeDisplayView(taskDate: task.taskDate)
                .frame(width: 39.55874, height: 20.58333, alignment: .topLeading)
            
            // 删除按钮
            Button(action: {
                onDelete(task)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray.opacity(0.6))
                    .font(.system(size: 16))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

// 优先级星星视图
struct PriorityStarsView: View {
    let priority: Int
    
    var body: some View {
        HStack(spacing: 2) {
            if priority > 0 { 
                ForEach(0..<min(priority, 3), id: \.self) { _ in 
                    Image("Star")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14) 
                } 
            }
        }
    }
}

// 时间显示视图
struct TimeDisplayView: View {
    let taskDate: Date?
    
    var body: some View {
        // 创建一个基本的Text视图，然后根据条件应用不同的修饰符
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        let displayText = taskDate != nil ? 
            formatter.string(from: taskDate!) : 
            "00:00"
        
        return Text(displayText)
            .font(Font.custom("Inria Sans", size: 16).weight(.light))
            .foregroundColor(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .opacity(taskDate == nil ? 0 : 1) // 如果没有日期，则设为透明
    }
}

// 添加任务按钮
struct AddTaskButton: View {
    // 添加回調以通知父視圖重新載入數據
    let onTaskAdded: () -> Void
    
    init(onTaskAdded: @escaping () -> Void = {}) {
        self.onTaskAdded = onTaskAdded
    }
    // 添加狀態變量來管理輸入和鍵盤
    @State private var taskTitle: String = ""
    @State private var displayText: String = ""
    @State private var priority: Int = 0
    @State private var isPinned: Bool = false
    @State private var isKeyboardVisible = false
    @State private var hasNote: Bool = false
    @State private var note: String = ""
    @State private var isDateEnabled: Bool = false
    @State private var isTimeEnabled: Bool = false
    @State private var selectedDate: Date = Date()
    @State private var showAddTimeView: Bool = false
    @State private var showAddNoteView: Bool = false
    @State private var shouldRefocusAfterReturn = false
    
    // 聚焦狀態
    @FocusState private var isTextFieldFocused: Bool
    
    // 優先級追踪
    @State private var priorityLevel: Int = 0
    
    // 是否處於編輯模式
    @State private var isEditing: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            if !isEditing {
                // 默認的添加按鈕狀態
                Button(action: {
                    isEditing = true
                    // 自動聚焦文字輸入框
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isTextFieldFocused = true
                    }
                }) {
                    HStack {
                        Image(systemName: "plus")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .opacity(0.5)
                        
                        Text("Add task")
                            .font(Font.custom("Inria Sans", size: 20).weight(.bold))
                            .foregroundColor(.white)
                            .opacity(0.5)
                        
                        Spacer()
                    }
                }
                .padding(.top, 12)
            } else {
                // 編輯模式的輸入介面
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image("Check_Rec_Group 1000004070")
                        
                        TextField("", text: $displayText)
                            .foregroundColor(.white)
                            .keyboardType(.default)
                            .colorScheme(.dark)
                            .focused($isTextFieldFocused)
                            .onChange(of: isTextFieldFocused) { newValue in
                                isKeyboardVisible = newValue
                                
                                // 當失去焦點且有內容時，自動保存任務
                                if !newValue && !displayText.isEmpty {
                                    saveTask()
                                }
                            }
                            .onSubmit {
                                // 按下回車時自動保存任務
                                if !displayText.isEmpty {
                                    saveTask()
                                }
                            }
                            .onAppear {
                                setupKeyboardNotifications()
                            }
                            .onDisappear {
                                removeKeyboardNotifications()
                            }
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    ZStack {
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 9) {
                                                // 優先級按鈕
                                                Button(action: {
                                                    if isPinned {
                                                        isPinned = false
                                                    }
                                                    priorityLevel = (priorityLevel + 1) % 4
                                                    priority = priorityLevel
                                                }) {
                                                    HStack(alignment: .center, spacing: 2) {
                                                        ForEach(0..<3) { index in
                                                            Image("Star 1 (3)")
                                                                .renderingMode(.template)
                                                                .foregroundColor(index < priorityLevel ? .green : .white.opacity(0.65))
                                                                .opacity(index < priorityLevel ? 1.0 : 0.65)
                                                        }
                                                    }
                                                    .frame(width: 109, height: 33.7)
                                                    .background(Color.white.opacity(0.15))
                                                    .cornerRadius(12)
                                                }
                                                
                                                // Pin按鈕
                                                Button(action: {
                                                    isPinned.toggle()
                                                    if isPinned {
                                                        priorityLevel = 0
                                                        priority = 0
                                                    }
                                                }) {
                                                    HStack {
                                                        Image("Pin")
                                                            .renderingMode(.template)
                                                            .foregroundColor(isPinned ? .green : .white)
                                                            .opacity(isPinned ? 1.0 : 0.25)
                                                    }
                                                    .frame(width: 51.7, height: 33.7)
                                                    .background(Color.white.opacity(0.15))
                                                    .cornerRadius(12)
                                                }
                                                
                                                // 時間按鈕
                                                Button(action: {
                                                    shouldRefocusAfterReturn = true
                                                    isTextFieldFocused = false
                                                    showAddTimeView = true
                                                }) {
                                                    GeometryReader { geometry in
                                                        Text(timeButtonText)
                                                            .lineLimit(1)
                                                            .minimumScaleFactor(0.7)
                                                            .foregroundColor(shouldUseGreenColor ? .green : .white.opacity(0.65))
                                                            .font(.system(size: 18))
                                                            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
                                                    }
                                                    .frame(width: 110, height: 33.7)
                                                    .background(Color.white.opacity(0.15))
                                                    .cornerRadius(12)
                                                }
                                                
                                                // 筆記按鈕
                                                Button(action: {
                                                    isTextFieldFocused = false
                                                    showAddNoteView = true
                                                }) {
                                                    Text("note")
                                                        .foregroundColor(shouldUseGreenColorForNote ? .green : .white.opacity(0.65))
                                                        .font(.system(size: 18))
                                                        .frame(width: 110, height: 33.7)
                                                        .background(Color.white.opacity(0.15))
                                                        .cornerRadius(12)
                                                }
                                            }
                                            .padding(.vertical, 7)
                                            .padding(.horizontal, 8)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                    }
                    
                    Image("Vector 80")
                    
                }
                .padding(.top, 12)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isKeyboardVisible)
        .fullScreenCover(isPresented: $showAddTimeView) {
            AddTimeView(
                isDateEnabled: $isDateEnabled,
                isTimeEnabled: $isTimeEnabled,
                selectedDate: $selectedDate,
                onSave: {
                    showAddTimeView = false
                    isDateEnabled = true
                    isTimeEnabled = true
                    
                    if shouldRefocusAfterReturn {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isTextFieldFocused = true
                            shouldRefocusAfterReturn = false
                        }
                    }
                },
                onBack: {
                    showAddTimeView = false
                    
                    if shouldRefocusAfterReturn {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isTextFieldFocused = true
                            shouldRefocusAfterReturn = false
                        }
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showAddNoteView) {
            AddNote(noteText: note) { savedNote in
                note = savedNote
                hasNote = !note.isEmpty
                showAddNoteView = false
            }
        }
    }
    
    // 時間按鈕文字
    private var timeButtonText: String {
        if !isDateEnabled && !isTimeEnabled {
            return "time"
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let selectedDay = calendar.startOfDay(for: selectedDate)
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let timeString = timeFormatter.string(from: selectedDate)
        
        var dateText = ""
        if calendar.isDate(selectedDay, inSameDayAs: today) {
            dateText = "Today"
        } else if calendar.isDate(selectedDay, inSameDayAs: tomorrow) {
            dateText = "Tomorrow"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d"
            dateText = dateFormatter.string(from: selectedDate)
        }
        
        if isDateEnabled && isTimeEnabled {
            return "\(dateText) \(timeString)"
        } else if isDateEnabled {
            return dateText
        } else if isTimeEnabled {
            return timeString
        }
        
        return "time"
    }
    
    // 是否應該使用綠色
    private var shouldUseGreenColor: Bool {
        return isDateEnabled || isTimeEnabled
    }
    
    // 筆記按鈕是否應該使用綠色
    private var shouldUseGreenColorForNote: Bool {
        return hasNote
    }
    
    // 設置鍵盤通知
    private func setupKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { _ in
            isKeyboardVisible = true
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            isKeyboardVisible = false
        }
    }
    
    // 移除鍵盤通知
    private func removeKeyboardNotifications() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.removeObserver(
            self,
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    // 重置編輯狀態
    private func resetEditingState() {
        isEditing = false
        displayText = ""
        taskTitle = ""
        priority = 0
        isPinned = false
        priorityLevel = 0
        hasNote = false
        note = ""
        isDateEnabled = false
        isTimeEnabled = false
        selectedDate = Date()
        isTextFieldFocused = false
    }
    
    // 保存任務
    private func saveTask() {
        guard !displayText.isEmpty else { return }
        
        // 這裡可以添加保存邏輯，類似 Add.swift 中的 saveToCloudKit()
        let finalTaskDate: Date? = (isDateEnabled || isTimeEnabled) ? selectedDate : nil
        
        let newTask = TodoItem(
            id: UUID(),
            userID: "user123",
            title: displayText,
            priority: priority,
            isPinned: isPinned,
            taskDate: finalTaskDate,
            note: note,
            status: .toBeStarted,
            createdAt: Date(),
            updatedAt: Date(),
            correspondingImageID: "new_task"
        )
        
        // 使用 DataSyncManager 保存
        DataSyncManager.shared.addTodoItem(newTask) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let savedItem):
                    print("成功保存任務: \(savedItem.title)")
                    resetEditingState()
                    // 通知父視圖重新載入數據
                    onTaskAdded()
                case .failure(let error):
                    print("保存失敗: \(error.localizedDescription)")
                    resetEditingState()
                    // 即使保存失敗也通知重新載入，以防本地數據已更新
                    onTaskAdded()
                }
            }
        }
    }
}

// MARK: - SettlementTodoQueueView (基於 Home.swift 的 ToDoSheetView 邏輯)
struct SettlementTodoQueueView: View {
    @Binding var items: [TodoItem]
    @Binding var selectedFilter: String
    let collapseAction: () -> Void
    let onTaskAdded: () -> Void
    
    let filters: [String] = ["全部", "備忘錄", "未完成"]
    
    // 根據選取條件過濾待辦事項（與 ToDoSheetView 完全一致）
    private var filteredItems: [TodoItem] {
        switch selectedFilter {
        case "全部":
            // 全部項目 - 不過濾
            return items
        case "備忘錄":
            // 備忘錄 - 篩選沒有時間的項目 (taskDate == nil)
            return items.filter { $0.taskDate == nil }
        case "未完成":
            // 未完成 - 有時間且狀態為未完成
            return items.filter { 
                $0.taskDate != nil && 
                ($0.status == .undone || $0.status == .toBeStarted) 
            }
        default:
            return items
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 標題欄
            HStack {
                Text("待辦事項佇列")
                    .font(Font.custom("Inter", size: 16))
                    .foregroundColor(.white)
                Spacer()
                // 分類按鈕列
                HStack(spacing: 8) {
                    ForEach(filters, id: \.self) { filter in
                        Button(action: {
                            selectedFilter = filter
                        }) {
                            Text(filter)
                                .font(Font.custom("Inter", size: 12).weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(
                                    selectedFilter == filter ?
                                    Color(red: 0, green: 0.72, blue: 0.41) :
                                    Color.white.opacity(0.15)
                                )
                                .cornerRadius(8)
                        }
                    }
                    
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 15)

            // 待辦事項列表
            VStack(spacing: 0) {
                if filteredItems.isEmpty {
                    VStack(spacing: 8) {
                        Text(getEmptyStateMessage())
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.top, 20)
                        
                        if selectedFilter == "備忘錄" {
                            Text("點擊加號來添加一個沒有時間的備忘錄項目")
                                .font(.system(size: 12))
                                .foregroundColor(.gray.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                } else {
                    ForEach(filteredItems.indices, id: \.self) { index in
                        let item = filteredItems[index]
                        if let originalIndex = items.firstIndex(where: { $0.id == item.id }) {
                            SettlementTodoItemRow(
                                item: $items[originalIndex],
                                onAddToToday: { todayItem in
                                    // 通知重新載入數據
                                    onTaskAdded()
                                }
                            )
                            
                            if index < filteredItems.count - 1 {
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(Color(red: 0.34, green: 0.34, blue: 0.34))
                                    .padding(.leading, 56)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)

            // 收合按鈕
            Button(action: {
                collapseAction()
            }) {
                HStack {
                    Spacer()
                    Text("收合")
                        .font(Font.custom("Inter", size: 12).weight(.medium))
                        .foregroundColor(.gray)
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                        .font(.caption)
                    Spacer()
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
        .background(Color(white: 0.12, opacity: 1.0))
        .cornerRadius(12)
    }
    
    private func getEmptyStateMessage() -> String {
        switch selectedFilter {
        case "備忘錄":
            return "還沒有備忘錄項目"
        case "未完成":
            return "沒有未完成的項目"
        default:
            return "佇列是空的"
        }
    }
}

// MARK: - SettlementTodoItemRow (基於 TodoSheetItemRow 邏輯)
struct SettlementTodoItemRow: View {
    @Binding var item: TodoItem
    private let doneColor = Color(red: 0, green: 0.72, blue: 0.41)
    private let iconSize: CGFloat = 14
    
    var onAddToToday: ((TodoItem) -> Void)? = nil
    
    var body: some View {
        ZStack {
            // 完成狀態下的橫跨整行的刪除線
            if item.status == .completed {
                Rectangle()
                    .fill(doneColor)
                    .frame(height: 2)
                    .offset(y: 0)
            }
            
            HStack(spacing: 12) {
                // 矩形按鈕 (點擊前灰色，點擊後綠色)
                Button {
                    print("SettlementTodoItem: 狀態從 \(item.status) 變為 \(item.status == .completed ? TodoStatus.toBeStarted : TodoStatus.completed)")
                    withAnimation {
                        item.status = (item.status == .completed ? TodoStatus.toBeStarted : TodoStatus.completed)
                    }
                    
                    // 更新本地資料庫
                    LocalDataManager.shared.updateTodoItem(item)
                    
                    // 使用 DataSyncManager 同步更新
                    DataSyncManager.shared.updateTodoItem(item) { result in
                        switch result {
                        case .success(_):
                            print("SettlementTodoItem: 成功更新項目狀態")
                        case .failure(let error):
                            print("SettlementTodoItem: 更新項目狀態失敗 - \(error.localizedDescription)")
                        }
                    }
                } label: {
                    Rectangle()
                        .foregroundColor(.clear)
                        .frame(width: 28, height: 28)
                        .background(item.status == .completed ? doneColor : .white.opacity(0.15))
                        .cornerRadius(40.5)
                }
                .buttonStyle(PlainButtonStyle())
                
                // 任務標題
                Text(item.title)
                    .font(.system(size: 15))
                    .foregroundColor(item.status == .completed ? doneColor : .white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Spacer()
                
                // 星標（如果優先度>=1）
                if item.priority >= 1 {
                    HStack(spacing: 2) {
                        ForEach(0..<min(item.priority, 3), id: \.self) { _ in
                            Image("Star")
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: iconSize, height: iconSize)
                                .foregroundColor(item.status == .completed ? doneColor : .white.opacity(0.7))
                        }
                    }
                    .padding(.trailing, 8)
                }
                
                // 右側箭頭按鈕 - 添加到今日並賦予當前時間
                Button {
                    print("SettlementTodoItem: 將項目添加到今日 - \(item.title)")
                    
                    // 創建一個新的副本
                    var todayItem = item
                    
                    // 賦予當前時間
                    todayItem.taskDate = Date()
                    
                    // 如果之前是備忘錄（待辦佇列），更改狀態為 toBeStarted
                    if todayItem.status == .toDoList {
                        todayItem.status = .toBeStarted
                    }
                    
                    // 更新 updatedAt 時間戳
                    todayItem.updatedAt = Date()
                    
                    // 使用數據同步管理器更新項目
                    DataSyncManager.shared.updateTodoItem(todayItem) { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success(_):
                                print("SettlementTodoItem: 成功將項目添加到今日")
                                
                                // 如果有回調，傳遞新項目
                                if let onAddToToday = onAddToToday {
                                    onAddToToday(todayItem)
                                }
                                
                            case .failure(let error):
                                print("SettlementTodoItem: 添加到今日失敗 - \(error.localizedDescription)")
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.turn.right.up")
                        .font(.system(size: 12))
                        .foregroundColor(item.status == .completed ? doneColor : .white.opacity(0.5))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 0)
        .background(Color.clear)
    }
}

struct SettlementView02_Previews: PreviewProvider {
    static var previews: some View {
        // 创建一些测试数据用于预览
        let testItems = [
            TodoItem(id: UUID(), userID: "testUser", title: "测试任务1", priority: 2, isPinned: false, taskDate: Date(), note: "", status: .undone, createdAt: Date(), updatedAt: Date(), correspondingImageID: ""),
            TodoItem(id: UUID(), userID: "testUser", title: "测试任务2", priority: 1, isPinned: true, taskDate: nil, note: "", status: .undone, createdAt: Date(), updatedAt: Date(), correspondingImageID: "")
        ]
        
        SettlementView02(uncompletedTasks: testItems, moveTasksToTomorrow: true)
    }
}
