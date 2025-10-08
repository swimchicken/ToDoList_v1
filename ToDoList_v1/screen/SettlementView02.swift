import SwiftUI
import Combine // **新增**: 為了鍵盤監聽器需要導入

fileprivate struct ViewBottomYPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        // 我們只需要最新的值，所以直接賦值
        value = nextValue()
    }
}

// 用于检测 TextEditor 内容高度的 PreferenceKey
fileprivate struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

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
    // MARK: - 狀態變數
    @State private var isRecording = false
    @State private var isTextInputMode = false
    @State private var newTodoText = ""
    @State private var isSavingRecording = false
    @State private var isSendingText = false
    
    @State private var keyboardHeight: CGFloat = 0
    @State private var isManualEditing: Bool = false
    
    // AddTime & AddNote 相關
    @State private var note: String = ""
    @State private var showAddTimeView: Bool = false
    @State private var showAddNoteView: Bool = false
    @State private var displayText: String = ""
    @State private var priority: Int = 0
    @State private var isPinned: Bool = false
    @State private var selectedDate: Date = Date()
    @State private var isDateEnabled: Bool = false
    @State private var isTimeEnabled: Bool = false
    
    @Namespace private var namespace

    @State private var showTaskSelectionOverlay: Bool = false
    @State private var pendingTasks: [TodoItem] = []
    @State private var taskToEdit: TodoItem?

    @StateObject private var speechManager = SpeechManager()
    @StateObject private var geminiService = GeminiService()
    
    @Environment(\.presentationMode) var presentationMode
    
    // 接收的數據
    let uncompletedTasks: [TodoItem]
    let moveTasksToTomorrow: Bool

    // 數據同步管理器
    private let dataSyncManager = DataSyncManager.shared
    
    // 本地狀態
    @State private var dailyTasks: [TodoItem] = []
    @State private var allTodoItems: [TodoItem] = []
    @State private var selectedFilterInSettlement = "全部"
    @State private var showTodoQueue: Bool = false
    @State private var navigateToSettlementView03: Bool = false
    
    // **新增**: 用於儲存列表內容底部在螢幕上的Y座標
    @State private var listContentBottomY: CGFloat = .zero
    
    private let delaySettlementManager = DelaySettlementManager.shared
    private var tomorrow: Date { Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date() }

    init(uncompletedTasks: [TodoItem], moveTasksToTomorrow: Bool) {
        self.uncompletedTasks = uncompletedTasks
        self.moveTasksToTomorrow = moveTasksToTomorrow

        // 如果要移動到明天，只顯示當天的未完成任務
        let initialDailyTasks: [TodoItem]
        if moveTasksToTomorrow {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())

            // 篩選當天的未完成任務（排除備忘錄）
            initialDailyTasks = uncompletedTasks.filter { task in
                guard let taskDate = task.taskDate else {
                    // 沒有日期的任務（備忘錄）不納入結算範圍
                    return false
                }
                let taskDay = calendar.startOfDay(for: taskDate)
                return taskDay == today
            }
        } else {
            initialDailyTasks = []
        }

        self._dailyTasks = State(initialValue: initialDailyTasks)
        self._allTodoItems = State(initialValue: [])
    }

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
        GeometryReader { geometry in
            ZStack {
                
                // MARK: - 圖層 1: 背景與主要內容 (列表)
                mainContent
                    .blur(radius: showTaskSelectionOverlay || taskToEdit != nil ? 13.5 : 0)
                // MARK: - 圖層 1.5: 编辑模式时的透明背景（用于检测点击外部）
                if isTextInputMode {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                isTextInputMode = false
                            }
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                        .ignoresSafeArea()
                }
                // MARK: - 圖層 2: 懸浮的 Add Task & AI 按鈕
                floatingInputButtons(screenProxy: geometry)
                
                // MARK: - 圖層 3: 底部固定 UI
                if keyboardHeight == 0 {
                    bottomNavigationView
                }

                // MARK: - 圖層 4: 彈出式 Overlay
                overlays
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
            .navigationBarBackButtonHidden(true)
            .navigationBarHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                setupKeyboardListeners()
                loadTasksFromDataManager()
            }
            .fullScreenCover(isPresented: $showAddTimeView) {
                AddTimeView(
                    isDateEnabled: $isDateEnabled, isTimeEnabled: $isTimeEnabled,
                    selectedDate: $selectedDate,
                    onSave: { self.showAddTimeView = false },
                    onBack: { self.showAddTimeView = false }
                )
            }
            .fullScreenCover(isPresented: $showAddNoteView) {
                AddNote(noteText: self.note) { savedNote in
                    self.note = savedNote
                    self.showAddNoteView = false
                }
            }
            .background(
                NavigationLink(destination: SettlementView03(), isActive: $navigateToSettlementView03) {
                    EmptyView()
                }
            )
        }
    }
    
    // MARK: - Body Subviews
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    ProgressBarView()
                    CheckmarkView()
                }
                .padding(.top, 0)
                DividerView()
                WakeUpTitleView()
                TomorrowDateView(tomorrow: tomorrow, formatDateForDisplay: formatDateForDisplay)
                AlarmInfoView()
                Image("Vector 81").resizable().aspectRatio(contentMode: .fit).frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 2)
            
            ScrollView {
                VStack(spacing: 0) {
                    TaskListView(
                        tasks: dailyTasks,
                        onDeleteTask: { taskToDelete in deleteTask(taskToDelete) }
                    )
                    
                    // 隱形錨點，用來探測列表底部的位置
                    Color.clear
                        .frame(height: 1)
                        .background(GeometryReader {
                            Color.clear.preference(key: ViewBottomYPreferenceKey.self, value: $0.frame(in: .global).maxY)
                        })
                }
            }
            .onPreferenceChange(ViewBottomYPreferenceKey.self) { newY in
                self.listContentBottomY = newY
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, 12)
        }
        .onTapGesture {
            if isManualEditing {
                isManualEditing = false
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }

    // MARK: - 懸浮按鈕視圖
        private func floatingInputButtons(screenProxy: GeometryProxy) -> some View {
            let screenHeight = screenProxy.size.height
            let safeAreaBottom = screenProxy.safeAreaInsets.bottom
            let buttonHeight: CGFloat = 70

            // ▼▼▼ 根據您的指示，組合了兩個有效公式的最終版本 ▼▼▼
            let buttonCenterY: CGFloat = {
                if keyboardHeight > 0 {
                    // --- 情況 1: 鍵盤已彈出 (根據不同輸入模式設定不同高度) ---
                                    // ▼▼▼ 從這裡開始貼上 ▼▼▼
                                    if isTextInputMode {
                                        // AI 按鈕彈出時，使用 360
                                        return 430.0
                                    } else {
                                        // Add task 手動輸入時，使用您調整好的 380
                                        return 380.0
                                    }
                                    // ▲▲▲ 在這裡結束貼上 ▲▲▲
                } else {
                    // --- 情況 2: 鍵盤已收合 (使用您指定的、先前有效的公式) ---
                    let contentBottomY = (listContentBottomY == 0) ? screenHeight : listContentBottomY
                    let idealY = contentBottomY + (buttonHeight / 2) - 60
                    let clampedY = min(idealY, screenHeight - safeAreaBottom - (buttonHeight / 2) - 80)
                    return clampedY
                }
            }()
            // ▲▲▲ 最終版計算邏輯結束 ▲▲▲
           
        return ZStack {
            AddTaskButton(
                isEditing: $isManualEditing, displayText: $displayText, priority: $priority,
                isPinned: $isPinned, note: $note, isDateEnabled: $isDateEnabled,
                isTimeEnabled: $isTimeEnabled, selectedDate: $selectedDate,
                onTaskAdded: { loadTasksFromDataManager() },
                onShowAddTime: { showAddTimeView = true },
                onShowAddNote: { showAddNoteView = true }
            )
            .opacity(isRecording || isTextInputMode ? 0 : 1)
            .animation(.easeInOut(duration: 0.3), value: isRecording || isTextInputMode)
            
            GeometryReader { geometry in
                HStack {
                    Spacer()
                    Group {
                        if isTextInputMode {
                            TextInputView(
                                namespace: namespace, isTextInputMode: $isTextInputMode,
                                isSending: $isSendingText, text: $newTodoText,
                                width: geometry.size.width - 10,
                                onSend: { text in handleSend(text: text) },
                                onCancel: cancelAPIRequest
                            )
                        } else {
                            ExpandableSoundButton(
                                namespace: namespace, isRecording: $isRecording,
                                isTextInputMode: $isTextInputMode, isSaving: $isSavingRecording,
                                audioLevel: speechManager.audioLevel,
                                onRecordingStart: startRecording, onRecordingEnd: endRecording,
                                onRecordingCancel: cancelRecording,
                                expandedWidth: geometry.size.width - 10
                            )
                        }
                    }
                    .opacity(isManualEditing ? 0 : 1)
                    .animation(.easeInOut(duration: 0.35), value: isManualEditing)
                }
            }
            .frame(height: 50)
            .offset(x: -5)
            .allowsHitTesting(!isManualEditing)
        }
        .padding(.horizontal, 12)
        .frame(height: buttonHeight)
        .position(x: screenProxy.size.width / 2, y: buttonCenterY)
        .animation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.5), value: listContentBottomY)
        .animation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.5), value: keyboardHeight)
        
    }

    @ViewBuilder
    private var bottomNavigationView: some View {
        VStack(spacing: 0) {
            Spacer()
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
                         self.presentationMode.wrappedValue.dismiss()
                     }) {
                         Text("返回")
                             .font(Font.custom("Inria Sans", size: 20))
                             .foregroundColor(.white)
                     }
                     .padding(.leading)
                     Spacer()
                     Button(action: {
                         // 如果用戶選擇移動任務到明天，在結算完成時執行移動
                         if moveTasksToTomorrow {
                             moveUncompletedTasksToTomorrowData()
                         }

                         delaySettlementManager.markSettlementCompleted()
                         navigateToSettlementView03 = true
                     }) {
                         Text("Next")
                             .font(Font.custom("Inria Sans", size: 20).weight(.bold))
                             .foregroundColor(.black)
                             .frame(maxWidth: .infinity)
                     }
                     .frame(width: 279, height: 60)
                     .background(.white)
                     .cornerRadius(40.5)
                 }
                 .padding(.horizontal, 12)
             }
             .padding(.bottom, 40)
             .background(Color.black)
        }
        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
        .ignoresSafeArea(.all, edges: .bottom)
    }
    
    @ViewBuilder
    private var overlays: some View {
        if showTaskSelectionOverlay {
            TaskSelectionOverlay(
                tasks: $pendingTasks,
                onCancel: { withAnimation { self.showTaskSelectionOverlay = false } },
                onAdd: { itemsToAdd in
                    for var item in itemsToAdd {
                        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                        if item.taskDate == nil || item.taskDate! < tomorrow {
                            item.taskDate = tomorrow
                        }
                        DataSyncManager.shared.addTodoItem(item) { _ in }
                    }
                    withAnimation { self.showTaskSelectionOverlay = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.loadTasksFromDataManager()
                    }
                },
                onEditTask: { task in
                    self.showTaskSelectionOverlay = false
                    self.taskToEdit = task
                }
            )
            .zIndex(500)
            .transition(.opacity)
        }

        if let taskToEdit = self.taskToEdit,
           let taskIndex = self.pendingTasks.firstIndex(where: { $0.id == taskToEdit.id }) {
            TaskEditView(task: $pendingTasks[taskIndex], onClose: {
                self.taskToEdit = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.showTaskSelectionOverlay = true
                }
            })
            .zIndex(600)
            .transition(.opacity.animation(.easeInOut))
        }
    }
    
    
    // MARK: - Functions
        private func setupKeyboardListeners() {
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
                guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                self.keyboardHeight = keyboardFrame.height
            }
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                self.keyboardHeight = 0
            }
        }
    // MARK: - 任務管理功能
    
    /// 從 DataManager 重新載入任務列表
    private func loadTasksFromDataManager() {
        let allItems = LocalDataManager.shared.getAllTodoItems()

        allTodoItems = allItems
        print("SettlementView02 - 載入所有待辦事項: \(allTodoItems.count) 個")

        if moveTasksToTomorrow {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())

            // 先篩選當天的未完成任務
            dailyTasks = allItems.filter { item in
                // 檢查狀態
                let isUncompleted = item.status == .toBeStarted || item.status == .undone

                // 檢查日期
                guard let taskDate = item.taskDate else {
                    // 沒有日期的任務（備忘錄）不納入結算範圍
                    return false
                }
                let taskDay = calendar.startOfDay(for: taskDate)
                let isToday = taskDay == today

                return isUncompleted && isToday
            }
            print("SettlementView02 - 重新載入當天未完成任務: \(dailyTasks.count) 個")
        } else {
            dailyTasks = []
            print("SettlementView02 - 清空任務列表")
        }
    }
    
    /// 刪除任務
    private func deleteTask(_ task: TodoItem) {
        print("SettlementView02: 開始刪除任務 - \(task.title)")
        
        DataSyncManager.shared.deleteTodoItem(withID: task.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success():
                    print("SettlementView02: 成功刪除任務 - \(task.title)")
                    self.loadTasksFromDataManager()
                    
                case .failure(let error):
                    print("SettlementView02: 刪除任務失敗 - \(error.localizedDescription)")
                    self.loadTasksFromDataManager()
                }
            }
        }
    }
    
    // MARK: - AI Button Logic

    private func startRecording() {
        isRecording = true
        speechManager.start()
    }

    private func endRecording() {
        isSavingRecording = true
        speechManager.stop { recognizedText in
            isSavingRecording = false
            isRecording = false
            
            if !recognizedText.isEmpty {
                newTodoText = recognizedText
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isTextInputMode = true
                }
            }
        }
    }

    private func cancelRecording() {
        speechManager.cancel()
        isRecording = false
    }

    private func handleSend(text: String) {
        guard !text.isEmpty else { return }
        
        isSendingText = true
        
        geminiService.analyzeText(text) { result in
            DispatchQueue.main.async {
                isSendingText = false
                newTodoText = ""
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isTextInputMode = false
                }

                switch result {
                case .success(let items):
                    print("✅ Gemini API 成功回傳! 任務總數: \(items.count)")
                    
                    self.pendingTasks = items
                    
                    if !self.pendingTasks.isEmpty {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self.showTaskSelectionOverlay = true
                        }
                    }
                    
                case .failure(let error):
                    print("❌ Gemini API 錯誤: \(error.localizedDescription)")
                }
            }
        }
    }
    // 取消 API 請求
    private func cancelAPIRequest() {
        geminiService.cancelRequest()
        isSendingText = false
        newTodoText = ""
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
            .padding(.vertical, 4)
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

// 任務列表視圖
struct TaskListView: View {
    let tasks: [TodoItem]
    let onDeleteTask: (TodoItem) -> Void
    // 我們將在 ZStack 中處理新增邏輯，所以這裡不再需要 onTaskAdded
    
    var body: some View {
        VStack(spacing: 0) {
            // 顯示任務列表（如果有任務）
            if !tasks.isEmpty {
                ForEach(tasks.indices, id: \.self) { index in
                    TaskRowView(task: tasks[index], isLast: index == tasks.count - 1, onDelete: onDeleteTask)
                }
            }
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

    private var shouldShowTime: Bool {
        guard let taskDate = taskDate else { return false }

        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: taskDate)
        let isTimeZero = (timeComponents.hour == 0 && timeComponents.minute == 0 && timeComponents.second == 0)

        return !isTimeZero
    }

    private var timeText: String {
        guard let taskDate = taskDate, shouldShowTime else { return "" }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: taskDate)
    }

    var body: some View {
        if shouldShowTime {
            Text(timeText)
                .font(Font.custom("Inria Sans", size: 16).weight(.light))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 39.55874, height: 20.58333, alignment: .topLeading)
        } else {
            Text("")
                .frame(width: 39.55874, height: 20.58333)
        }
    }
}

// 添加任务按钮
struct AddTaskButton: View {
    // 接收來自父視圖的控制
    @Binding var isEditing: Bool

    // 接收來自父視圖的綁定
    @Binding var displayText: String
    @Binding var priority: Int
    @Binding var isPinned: Bool
    @Binding var note: String
    @Binding var isDateEnabled: Bool
    @Binding var isTimeEnabled: Bool
    @Binding var selectedDate: Date

    // 通知父視圖的閉包
    let onTaskAdded: () -> Void
    let onShowAddTime: () -> Void
    let onShowAddNote: () -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        // 根視圖直接就是 HStack，代表我們的膠囊本身。它的結構永遠不變。
        HStack {
            if isEditing {
                Image("Check_Rec_Group 1000004070") // 您的勾選圖示
                
                TextField("Add task manually", text: $displayText)
                    .foregroundColor(.white)
                    .colorScheme(.dark)
                    .focused($isTextFieldFocused)
                    .submitLabel(.done)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isTextFieldFocused = true
                        }
                    }
                    .onSubmit {
                        if !displayText.isEmpty {
                            saveTask()
                        } else {
                            resetEditingState(clearText: false)
                            isEditing = false
                        }
                    }
                    .toolbar {
                        keyboardToolbarContent
                    }
            } else {
                // 未編輯狀態下的內容
                Image(systemName: "plus")
                    .foregroundColor(.white.opacity(0.8))
                Text("Add task")
                    .font(Font.custom("Inria Sans", size: 18).weight(.bold))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 70)
        .background(Color(white: 0.12))
        .clipShape(Capsule())
        .contentShape(Rectangle()) // 讓整個膠囊區域都能響應點擊
        .onTapGesture {
            // 點擊膠囊時的唯一邏輯
            if !isEditing {
                // 如果不是編輯模式，就進入編輯模式
                withAnimation(.easeInOut(duration: 0.2)) {
                    isEditing = true
                }
            }
            // 如果已經是編輯模式，這個手勢會被觸發但不做任何事，
            // 同時它會成功攔截點擊，防止事件傳遞到背景上導致輸入框關閉。
        }
        .padding(.top, 12)
        
    }
    
    // 鍵盤上方的工具列
    private var keyboardToolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    // 優先級按鈕
                    Button(action: {
                        if isPinned { isPinned = false }
                        priority = (priority + 1) % 4
                    }) {
                        HStack(alignment: .center, spacing: 2) {
                            ForEach(0..<3) { index in
                                Image("Star 1 (3)") // 您的星星圖示
                                    .renderingMode(.template)
                                    .foregroundColor(index < priority ? .green : .white.opacity(0.65))
                            }
                        }
                        .frame(width: 109, height: 33.7)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(12)
                    }
                    
                    // Pin 按鈕
                    Button(action: {
                        isPinned.toggle()
                        if isPinned { priority = 0 }
                    }) {
                        Image("Pin") // 您的 Pin 圖示
                            .renderingMode(.template)
                            .foregroundColor(isPinned ? .green : .white)
                            .frame(width: 51.7, height: 33.7)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(12)
                    }
                    
                    // 時間按鈕
                    Button(action: {
                        isTextFieldFocused = false
                        onShowAddTime()
                    }) {
                        Text(timeButtonText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundColor(isDateEnabled || isTimeEnabled ? .green : .white.opacity(0.65))
                            .frame(width: 110, height: 33.7)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(12)
                    }
                    
                    // 筆記按鈕
                    Button(action: {
                        isTextFieldFocused = false
                        onShowAddNote()
                    }) {
                        Text("note")
                            .foregroundColor(!note.isEmpty ? .green : .white.opacity(0.65))
                            .frame(width: 110, height: 33.7)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(12)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // 時間按鈕的顯示文字
    private var timeButtonText: String {
        guard isDateEnabled || isTimeEnabled else { return "time" }
        
        let formatter = DateFormatter()
        var dateText = ""
        
        if isDateEnabled {
            if Calendar.current.isDateInToday(selectedDate) {
                dateText = "Today"
            } else if Calendar.current.isDateInTomorrow(selectedDate) {
                dateText = "Tomorrow"
            } else {
                formatter.dateFormat = "MMM d"
                dateText = formatter.string(from: selectedDate)
            }
        }
        
        var timeText = ""
        if isTimeEnabled {
            formatter.dateFormat = "HH:mm"
            timeText = formatter.string(from: selectedDate)
        }
        
        return [dateText, timeText].filter { !$0.isEmpty }.joined(separator: " ")
    }
    
    // 儲存任務
    private func saveTask() {
        guard !displayText.isEmpty else { return }
        
        let finalTaskDate: Date? = (isDateEnabled || isTimeEnabled) ? selectedDate : nil
        
        // 請根據您的 TodoItem 初始化方法確認以下參數是否完整
        let newTask = TodoItem(
            id: UUID(),
            userID: "user_id", // 請替換為真實用戶ID
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
        
        DataSyncManager.shared.addTodoItem(newTask) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("手動新增任務成功: \(newTask.title)")
                    onTaskAdded() // 通知父視圖刷新
                case .failure(let error):
                    print("手動新增任務失敗: \(error.localizedDescription)")
                }
                resetEditingState()
            }
        }
    }

    // 重置編輯狀態
    private func resetEditingState(clearText: Bool = true) {
        if clearText {
            displayText = ""
        }
        priority = 0
        isPinned = false
        note = ""
        isDateEnabled = false
        isTimeEnabled = false
        selectedDate = Date()
        isEditing = false
        isTextFieldFocused = false
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
                
                // 右側箭頭按鈕 - 添加到今日，保留原時間或賦予當前時間
                Button {
                    print("SettlementTodoItem: 將項目添加到今日 - \(item.title)")

                    // 創建一個新的副本
                    var todayItem = item

                    // 檢查是否沒有時間或者時間為00:00
                    let calendar = Calendar.current
                    let isNoTimeEvent: Bool

                    if todayItem.taskDate == nil {
                        isNoTimeEvent = true
                        print("SettlementTodoItem: 項目沒有日期時間（備忘錄）")
                    } else {
                        // 檢查時間是否為 00:00:00（表示只有日期沒有時間）
                        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: todayItem.taskDate!)
                        let isTimeZero = (timeComponents.hour == 0 && timeComponents.minute == 0 && timeComponents.second == 0)
                        isNoTimeEvent = isTimeZero
                        print("SettlementTodoItem: 項目時間為 \(timeComponents.hour ?? 0):\(timeComponents.minute ?? 0):\(timeComponents.second ?? 0), 是否為無時間事件: \(isNoTimeEvent)")
                    }

                    if isNoTimeEvent {
                        // 如果是沒有時間的事件，保持為沒有時間（備忘錄狀態）
                        todayItem.taskDate = nil
                        print("SettlementTodoItem: 無時間事件保持為備忘錄狀態")
                    } else {
                        // 如果已有時間，保留原時間，只更新日期為明天
                        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()

                        // 提取原本的時間部分
                        let originalTimeComponents = calendar.dateComponents([.hour, .minute, .second], from: todayItem.taskDate!)

                        // 組合明天的日期與原本的時間
                        var tomorrowComponents = calendar.dateComponents([.year, .month, .day], from: tomorrow)
                        tomorrowComponents.hour = originalTimeComponents.hour
                        tomorrowComponents.minute = originalTimeComponents.minute
                        tomorrowComponents.second = originalTimeComponents.second

                        if let newDate = calendar.date(from: tomorrowComponents) {
                            todayItem.taskDate = newDate
                            print("SettlementTodoItem: 保留原時間 \(originalTimeComponents.hour ?? 0):\(originalTimeComponents.minute ?? 0)，設定為明天")
                        } else {
                            // 如果日期組合失敗，使用當前時間作為後備
                            todayItem.taskDate = calendar.startOfDay(for: tomorrow)
                            print("SettlementTodoItem: 日期組合失敗，使用當前時間")
                        }
                    }

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
                                let formatter = DateFormatter()
                                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                                if let taskDate = todayItem.taskDate {
                                    print("SettlementTodoItem: 更新後的任務時間為 - \(formatter.string(from: taskDate))")
                                } else {
                                    print("SettlementTodoItem: 更新後的任務沒有時間（應該不顯示時間）")
                                }

                               

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


struct TextInputView: View {
    let namespace: Namespace.ID
    @Binding var isTextInputMode: Bool
    @Binding var isSending: Bool
    @Binding var text: String
    let width: CGFloat
    var onSend: (String) -> Void
    var onCancel: () -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    @State private var showContents = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30)
                .fill(Color.white)
                .matchedGeometryEffect(id: "aiButton", in: namespace)
                .overlay(
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(Color(red: 0, green: 0.72, blue: 0.41), lineWidth: 2)
                        .shadow(color: Color(red: 0, green: 0.72, blue: 0.41).opacity(0.8), radius: 8, x: 0, y: 0)
                        .shadow(color: Color(red: 0, green: 0.72, blue: 0.41).opacity(0.5), radius: 4, x: 0, y: 0)
                )
            
            if showContents {
                HStack(alignment: .center, spacing: 0) {  // ← 改为 .center 对齐
                    // 左侧 X 按钮
                    Button(action: { closeTextInput() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .frame(width: 60, height: 60)
                    
                    // 中间文字输入区域
                    ZStack(alignment: .leading) {
                        if !isSending {
                            ZStack(alignment: .topLeading) {
                                // Placeholder
                                if text.isEmpty && !isTextFieldFocused {
                                    Text("輸入待辦事項, 或直接跟 AI 說要做什麼")
                                        .foregroundColor(.gray.opacity(0.5))
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.leading, 5)
                                        .padding(.top, 8)
                                }
                                
                                TextEditor(text: $text)
                                    .focused($isTextFieldFocused)
                                    .foregroundColor(Color(red: 0, green: 0.72, blue: 0.41))
                                    .scrollContentBackground(.hidden)
                                    .background(
                                        GeometryReader { geometry in
                                            Color.clear.preference(
                                                key: ViewHeightKey.self,
                                                value: geometry.size.height
                                            )
                                        }
                                    )
                                    .multilineTextAlignment(.leading)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .frame(minHeight: isTextFieldFocused ? 60 : nil)
                            }
                        }
                        
                        if isSending {
                            AnimatedGradientTextView(text: text)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 9)
                                .padding(.vertical, 8)
                            
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 8)
                    
                    // 右侧按钮
                    if isSending {
                        TextLoadingIndicatorView()
                            .frame(width: 44, height: 44)
                            .padding(.trailing, 8)
                    } else if !text.isEmpty {
                        Button(action: {
                            onSend(text)
                        }) {
                            ZStack {
                                Circle().fill(Color(red: 0, green: 0.72, blue: 0.41))
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .padding(.trailing, 8)
                        .transition(.scale.animation(.spring()))
                    } else {
                        // 空白占位符，保持布局一致
                        Spacer()
                            .frame(width: 44, height: 44)
                            .padding(.trailing, 8)
                    }
                }
                .transition(.opacity.animation(.easeIn(duration: 0.3).delay(0.2)))
            }
        }
        .frame(width: width)
        .frame(minHeight: 60, maxHeight: 200)  // ← 加上 minHeight: 60，确保初始高度
        .fixedSize(horizontal: false, vertical: true)  // ← 让高度根据内容自动调整
        .frame(maxWidth: width, alignment: .bottom)  // ← 底部固定
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {  // ← 缩短延迟
                showContents = true
            }
        }
        .onChange(of: isTextInputMode) { newValue in
            if !newValue {
                isTextFieldFocused = false
            }
        }
    }
    
    private func closeTextInput() {
        // 如果正在發送，取消 API 請求
        if isSending {
            onCancel()
        }
        
        text = ""
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isTextInputMode = false
        }
        isTextFieldFocused = false
    }
    
    struct TextLoadingIndicatorView: View {
        @State private var isAnimating = false
        
        var body: some View {
            GeometryReader { geometry in
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                
                ZStack {
                    ForEach(0..<4) { i in
                        Path { path in
                            path.addArc(
                                center: center, radius: 14,
                                startAngle: .degrees(Double(i) * 90 + 35),
                                endAngle: .degrees(Double(i) * 90 + 75),
                                clockwise: false
                            )
                        }
                        .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .foregroundColor(Color(red: 0, green: 0.72, blue: 0.41))
                    }
                }
                .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                .onAppear {
                    withAnimation(Animation.linear(duration: 2).repeatForever(autoreverses: false)) {
                        isAnimating = true
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }
}

struct AnimatedGradientTextView: View {
    let text: String
    @State private var gradientStartPoint: UnitPoint = .init(x: -1, y: 0.5)
    
    private let gradientColors = [
        Color.green.opacity(0.7), Color.cyan.opacity(0.7), Color.blue.opacity(0.7),
        Color.purple.opacity(0.7), Color.pink.opacity(0.7), Color.green.opacity(0.7)
    ]
    
    var body: some View {
        Text(text)
            .font(.system(size: 17))
            .foregroundColor(.clear)
            .overlay(
                LinearGradient(
                    colors: gradientColors,
                    startPoint: gradientStartPoint,
                    endPoint: .init(x: gradientStartPoint.x + 1, y: 0.5)
                )
                .mask(Text(text).font(.system(size: 17)))
            )
            .onAppear {
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    gradientStartPoint = .init(x: 1, y: 0.5)
                }
            }
    }
}

struct AudioWaveformView: View {
    let audioLevel: Double
    @Binding var isSaving: Bool
    
    private let barCount = 50
    @State private var waveformData: [Double] = Array(repeating: 0, count: 50)
    @State private var savingTimer: Timer?
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<waveformData.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.white)
                    .frame(width: 3, height: max(4, waveformData[index] * 55))
            }
        }
        .animation(.easeOut(duration: 0.1), value: waveformData)
        .onChange(of: audioLevel) { newLevel in
            if !isSaving {
                updateWaveform(with: newLevel)
            }
        }
        .onChange(of: isSaving) { newValue in
            if newValue {
                startDecayAnimation()
            } else {
                savingTimer?.invalidate()
                savingTimer = nil
            }
        }
    }
    
    private func updateWaveform(with level: Double) {
        waveformData.append(level)
        if waveformData.count > barCount {
            waveformData.removeFirst()
        }
    }
    
    private func startDecayAnimation() {
        var decaySteps = 20
        savingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard decaySteps > 0 else {
                waveformData = Array(repeating: 0, count: barCount)
                savingTimer?.invalidate()
                savingTimer = nil
                return
            }
            
            let decayFactor = Double(decaySteps) / 20.0
            let newLevel = Double.random(in: 0...0.3) * decayFactor
            updateWaveform(with: newLevel)
            
            decaySteps -= 1
        }
    }
}

struct ExpandableSoundButton: View {
    let namespace: Namespace.ID
    @Binding var isRecording: Bool
    @Binding var isTextInputMode: Bool
    @Binding var isSaving: Bool
    
    let audioLevel: Double
    let onRecordingStart: () -> Void
    let onRecordingEnd: () -> Void
    let onRecordingCancel: () -> Void
    let expandedWidth: CGFloat
    
    @State private var dragLocation: CGPoint = .zero
    @State private var isOverCancelButton = false
    @State private var isOverSendButton = true
    @State private var pressEffectScale: CGFloat = 1.0
    @State private var cancelPressEffectScale: CGFloat = 0.0
    
    @State private var showRecordingContents = false
    
    @State private var recordingHintText: String = ""
    
    private var currentWidth: CGFloat {
        isRecording || isSaving ? expandedWidth : 60
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Text(recordingHintText)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.7), radius: 5, x: 0, y: 2)
                .offset(y: -50)
                .opacity(isRecording && !recordingHintText.isEmpty ? 1 : 0)
                .animation(.easeInOut, value: recordingHintText)
                .zIndex(1)
            
            ZStack {
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color(red: 0, green: 0.72, blue: 0.41))
                    .matchedGeometryEffect(id: "aiButton", in: namespace)
                
                if isRecording || isSaving {
                    if showRecordingContents {
                        recordingView
                    }
                } else {
                    defaultView
                }
            }
            .frame(width: currentWidth, height: 60)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isRecording || isSaving)
            .onTapGesture {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isTextInputMode = true
                }
            }
            .gesture(longPressGesture)
            .onChange(of: isRecording) { newValue in
                if newValue {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        showRecordingContents = true
                    }
                } else if !isSaving {
                    showRecordingContents = false
                }
            }
            .onChange(of: isSaving) { newValue in
                if !newValue {
                    showRecordingContents = false
                }
            }
        }
    }
    
    private var defaultView: some View {
        ZStack {
            Image("Star 12")
                .resizable().scaledToFit().frame(width: 20, height: 20)
                .foregroundColor(.white).offset(x: -4, y: -4)
            Image("Star 12")
                .resizable().scaledToFit().frame(width: 11, height: 11)
                .foregroundColor(.white).offset(x: 7, y: 7)
        }
    }
    
    private var recordingView: some View {
        HStack(spacing: 0) {
            Button(action: { cancelRecording() }) {
                ZStack {
                    ZStack {
                        Circle().stroke(Color.white, lineWidth: 1.5).frame(width: 47, height: 47)
                        Image(systemName: "xmark").font(.system(size: 16, weight: .medium)).foregroundColor(.white)
                    }.opacity(isOverCancelButton ? 0 : 1)
                    ZStack {
                        Circle().fill(Color.white).frame(width: 47, height: 47)
                        Image(systemName: "xmark").font(.system(size: 16, weight: .medium)).foregroundColor(Color(red: 0, green: 0.72, blue: 0.41))
                    }.opacity(isOverCancelButton ? 1 : 0)
                }
            }
            .frame(width: 60, height: 60)
            .background(
                Circle().fill(Color.white.opacity(0.3)).frame(width: 80, height: 80)
                    .scaleEffect(cancelPressEffectScale)
                    .opacity(isOverCancelButton ? 1 : 0)
            )
            .opacity(isSaving ? 0 : 1)
            .transition(.move(edge: .leading).combined(with: .opacity))
            
            ZStack {
                AudioWaveformView(audioLevel: audioLevel, isSaving: $isSaving)
                
            }
            .frame(maxWidth: .infinity)
            .transition(.opacity.combined(with: .scale))
            
            ZStack {
                if isSaving {
                    LoadingIndicatorView()
                }
                ZStack {
                    ZStack {
                        Circle().fill(Color(red: 0, green: 0.72, blue: 0.41))
                        Circle().stroke(Color.white, lineWidth: 1.5)
                        Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                    }
                    .frame(width: 50, height: 50)
                    .opacity(isOverSendButton ? 0 : 1)
                    
                    ZStack {
                        Circle().fill(Color.white)
                        Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)).foregroundColor(Color(red: 0, green: 0.72, blue: 0.41))
                    }
                    .frame(width: 50, height: 50)
                    .opacity(isOverSendButton ? 1 : 0)
                    
                    Circle().fill(Color.white.opacity(0.3)).frame(width: 80, height: 80)
                        .scaleEffect(pressEffectScale)
                        .opacity(isOverSendButton ? 1 : 0)
                }
                .opacity(isSaving ? 0 : 1)
            }
            .frame(width: 60, height: 60)
            
            .transition(.opacity)
        }
        .transition(.opacity)
    }
    
    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .onEnded { _ in
                if !isRecording && !isTextInputMode {
                    onRecordingStart()
                }
            }
            .simultaneously(with: dragGesture)
    }
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if isRecording {
                    dragLocation = value.location
                    let sendButtonFrame = CGRect(x: currentWidth - 60, y: 0, width: 60, height: 60)
                    let cancelButtonFrame = CGRect(x: 0, y: 0, width: 60, height: 60)
                    
                    self.isOverSendButton = sendButtonFrame.contains(value.location)
                    self.isOverCancelButton = cancelButtonFrame.contains(value.location)
                    
                    if self.isOverCancelButton {
                        self.recordingHintText = "Release to cancel"
                    } else if self.isOverSendButton {
                        self.recordingHintText = "Release to send..."
                    } else {
                        self.recordingHintText = ""
                    }
                    
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        self.pressEffectScale = self.isOverSendButton ? 1.0 : 0.0
                        self.cancelPressEffectScale = self.isOverCancelButton ? 1.0 : 0.0
                    }
                }
            }
            .onEnded { value in
                if isRecording {
                    if isOverCancelButton {
                        cancelRecording()
                    } else {
                        completeRecording()
                    }
                    dragLocation = .zero
                    isOverCancelButton = false
                    isOverSendButton = true
                    pressEffectScale = 1.0
                    cancelPressEffectScale = 0.0
                    recordingHintText = ""
                }
            }
    }
    
    private func cancelRecording() {
        onRecordingCancel()
    }
    
    private func completeRecording() {
        onRecordingEnd()
    }
    
    struct LoadingIndicatorView: View {
        @State private var isAnimating = false
        
        var body: some View {
            GeometryReader { geometry in
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                
                ZStack {
                    ForEach(0..<8) { i in
                        Path { path in
                            path.addArc(
                                center: center, radius: 20,
                                startAngle: .degrees(Double(i) * 45 + 1),
                                endAngle: .degrees(Double(i) * 45 + 20),
                                clockwise: false
                            )
                        }
                        .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .foregroundColor(.white)
                    }
                }
                .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                .onAppear {
                    withAnimation(Animation.linear(duration: 2).repeatForever(autoreverses: false)) {
                        isAnimating = true
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }
}


// MARK: - SettlementView02 Extensions
extension SettlementView02 {
    // 將未完成任務移至明日的數據處理
    func moveUncompletedTasksToTomorrowData() {
        print("結算完成時開始將 \(uncompletedTasks.count) 個未完成任務移至明日")

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()

        // 再次篩選，確保只處理當天的未完成事項（排除備忘錄）
        let todayUncompletedTasks = uncompletedTasks.filter { task in
            guard let taskDate = task.taskDate else {
                // 沒有日期的任務（備忘錄）不應該被移動
                return false
            }
            let taskDay = calendar.startOfDay(for: taskDate)
            return taskDay == today
        }

        print("實際將移動的當天未完成任務: \(todayUncompletedTasks.count) 個（從總計 \(uncompletedTasks.count) 個中篩選）")

        for task in todayUncompletedTasks {
            // 決定新的任務時間
            let newTaskDate: Date?

            if let originalTaskDate = task.taskDate {
                // 如果原本有時間，檢查是否為 00:00:00
                let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: originalTaskDate)
                let isTimeZero = (timeComponents.hour == 0 && timeComponents.minute == 0 && timeComponents.second == 0)

                if isTimeZero {
                    // 原本是 00:00:00 的事件，變成沒有時間的備忘錄
                    newTaskDate = nil
                    print("任務 '\(task.title)' 原本沒有時間，移至明日後保持為備忘錄")
                } else {
                    // 原本有具體時間的事件，保留時間但改日期為明天
                    var tomorrowComponents = calendar.dateComponents([.year, .month, .day], from: tomorrow)
                    tomorrowComponents.hour = timeComponents.hour
                    tomorrowComponents.minute = timeComponents.minute
                    tomorrowComponents.second = timeComponents.second

                    newTaskDate = calendar.date(from: tomorrowComponents)
                    print("任務 '\(task.title)' 保留原時間 \(timeComponents.hour ?? 0):\(timeComponents.minute ?? 0)，移至明天")
                }
            } else {
                // 原本就沒有時間（備忘錄），保持沒有時間
                newTaskDate = nil
                print("任務 '\(task.title)' 原本是備忘錄，移至明日後保持為備忘錄")
            }

            // 創建更新後的任務
            let updatedTask = TodoItem(
                id: task.id,
                userID: task.userID,
                title: task.title,
                priority: task.priority,
                isPinned: task.isPinned,
                taskDate: newTaskDate, // 使用新的邏輯決定的時間
                note: task.note,
                status: task.status,
                createdAt: task.createdAt,
                updatedAt: Date(), // 更新修改時間
                correspondingImageID: task.correspondingImageID
            )

            // 使用 DataSyncManager 更新任務
            dataSyncManager.updateTodoItem(updatedTask) { result in
                switch result {
                case .success:
                    print("結算完成時成功將任務 '\(task.title)' 移至明日")
                case .failure(let error):
                    print("結算完成時移動任務 '\(task.title)' 失敗: \(error.localizedDescription)")
                }
            }
        }

        print("結算完成時完成未完成任務移至明日的處理")
    }
}
