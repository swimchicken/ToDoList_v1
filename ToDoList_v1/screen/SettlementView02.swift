import SwiftUI
import Combine // **新增**: 為了鍵盤監聽器需要導入

// MARK: - 共享的暫存操作類型定義
enum SettlementOperation {
    case addItem(TodoItem)
    case deleteItem(UUID)
    case updateItem(TodoItem)
}

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
    @State private var textInputViewHeight: CGFloat = 60
    // AddTime & AddNote 相關
    @State private var note: String = ""
    @State private var showAddTimeView: Bool = false
    @State private var showAddNoteView: Bool = false
    @State private var displayText: String = ""
    @State private var priority: Int = 0
    @State private var isPinned: Bool = false
    @State private var selectedDate: Date = Date()  // 📝 修改：暫時設為當前時間，將在 onAppear 中根據結算類型調整
    @State private var isDateEnabled: Bool = false
    @State private var isTimeEnabled: Bool = true  // 📝 修改：預設開啟時間設定
    
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
    private let apiDataManager = APIDataManager.shared
    
    // 本地狀態
    @State private var dailyTasks: [TodoItem] = []
    @State private var allTodoItems: [TodoItem] = []
    @State private var originalTodoItems: [TodoItem] = []  // 📝 新增：保存原始數據，不受暫存操作影響
    @State private var selectedFilterInSettlement = "全部"
    @State private var showTodoQueue: Bool = false
    @State private var navigateToSettlementView03: Bool = false
    @State private var navigateToHome: Bool = false  // 新增：導航回 Home

    // 記錄settlement開始時明天已有的任務ID，用於過濾
    @State private var existingTomorrowTaskIDs: Set<UUID> = []

    // 新增：暫存操作記錄，只有在 SettlementView03 完成時才提交
    @State private var pendingOperations: [SettlementOperation] = []
    @State private var tempDeletedItemIDs: Set<UUID> = []  // 暫時標記為刪除的項目ID
    @State private var tempAddedItems: [TodoItem] = []     // 暫時添加的新項目
    @State private var hasAppearedOnce = false             // 追蹤是否已經appear過
    @State private var isExecutingSettlement = false      // 📝 新增：防止重複執行結算
    
    // **新增**: 用於儲存列表內容底部在螢幕上的Y座標
    @State private var listContentBottomY: CGFloat = .zero
    
    private let delaySettlementManager = DelaySettlementManager.shared
    private var tomorrow: Date { Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date() }

    init(uncompletedTasks: [TodoItem], moveTasksToTomorrow: Bool) {
        self.uncompletedTasks = uncompletedTasks
        self.moveTasksToTomorrow = moveTasksToTomorrow

        // 如果要移動到明天，顯示當天未完成任務和明天的任務
        let initialDailyTasks: [TodoItem]
        if moveTasksToTomorrow {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date())

            // 先使用空陣列，將在onAppear中加載
            let allItems: [TodoItem] = []

            // 記錄settlement開始時明天已有的任務ID，這些不應該顯示在事件列表中
            let existingTomorrowTasks = allItems.filter { task in
                guard let taskDate = task.taskDate else { return false }
                let taskDay = calendar.startOfDay(for: taskDate)
                return taskDay == tomorrow
            }

            // 篩選要顯示在事件列表的任務：只顯示當天的未完成任務
            initialDailyTasks = allItems.filter { task in
                guard let taskDate = task.taskDate else { return false }
                let taskDay = calendar.startOfDay(for: taskDate)

                // 只顯示當天的未完成任務（準備移動到明天的）
                return (taskDay == today) && (task.status == .toBeStarted || task.status == .undone)
            }
        } else {
            initialDailyTasks = []
        }

        // 根據toggle狀態決定初始顯示數據
        if moveTasksToTomorrow {
            // 如果要移動到明天，顯示未完成任務（樂觀更新）
            self._dailyTasks = State(initialValue: uncompletedTasks)
        } else {
            // 如果不移動，顯示空列表（用戶要自己手動添加）
            self._dailyTasks = State(initialValue: [])
        }
        // 初始化 allTodoItems 包含傳入的任務
        self._allTodoItems = State(initialValue: uncompletedTasks)
        // 📝 新增：同時初始化原始數據
        self._originalTodoItems = State(initialValue: uncompletedTasks)

        // 設定已存在的明天任務ID
        if moveTasksToTomorrow {
            let calendar = Calendar.current
            let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date())
            // 將在onAppear中加載數據
            let allItems: [TodoItem] = []
            let existingTomorrowTaskIDs: Set<UUID> = Set(allItems.compactMap { task -> UUID? in
                guard let taskDate = task.taskDate else { return nil }
                let taskDay = calendar.startOfDay(for: taskDate)
                return taskDay == tomorrow ? task.id : nil
            })
            // 靜默日誌: print("🔧 SettlementView02 初始化：記錄明天已存在的任務ID數量：\(existingTomorrowTaskIDs.count)")
            for id in existingTomorrowTaskIDs {
                if let task = allItems.first(where: { $0.id == id }) {
                    print("  - 明天已存在任務：\(task.title) (ID: \(id))")
                }
            }
            self._existingTomorrowTaskIDs = State(initialValue: existingTomorrowTaskIDs)
        } else {
            self._existingTomorrowTaskIDs = State(initialValue: [])
        }
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
                    .blur(radius: showTaskSelectionOverlay || taskToEdit != nil ? 13.5 : 0)

                // MARK: - 圖層 3: 底部固定 UI
                if keyboardHeight == 0 {
                    bottomNavigationView
                        .blur(radius: showTaskSelectionOverlay || taskToEdit != nil ? 13.5 : 0)
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

                // 📝 修改：根據結算類型設定預設日期
                setupDefaultDate()

                // \u53ea\u5728\u7b2c\u4e00\u6b21\u9032\u5165\u6642\u91cd\u7f6e\u66ab\u5b58\u72c0\u614b
                if !hasAppearedOnce {
                    pendingOperations.removeAll()
                    tempDeletedItemIDs.removeAll()
                    tempAddedItems.removeAll()
                    hasAppearedOnce = true
                    print("First time entering SettlementView02, resetting temp state")
                    print("SettlementView02 - 初始化樂觀更新：已顯示 \(dailyTasks.count) 個傳入任務")
                } else {
                    print("Re-entering SettlementView02, keeping temp state")
                    // 非首次進入才調用完整的資料載入
                    loadTasksFromDataManager()
                }

                // 移除不必要的 API 調用 - SettlementView 已提供正確的過濾數據
                // loadInitialData()
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
                Group {
                    NavigationLink(destination: SettlementView03(
                        uncompletedTasks: uncompletedTasks,
                        moveTasksToTomorrow: moveTasksToTomorrow,
                        pendingOperations: pendingOperations  // 傳遞暫存操作
                    ), isActive: $navigateToSettlementView03) {
                        EmptyView()
                    }

                    // 新增：延期結算完成後導航回 Home
                    NavigationLink(
                        destination: Home()
                            .navigationBarHidden(true)
                            .navigationBarBackButtonHidden(true)
                            .toolbar(.hidden, for: .navigationBar),
                        isActive: $navigateToHome
                    ) {
                        EmptyView()
                    }
                    .isDetailLink(false) // 重置導航堆疊
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
                .padding(.bottom, 180) 
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
    
    private func calculateButtonCenterY(screenProxy: GeometryProxy) -> CGFloat {
        let screenHeight = screenProxy.size.height
        
        if keyboardHeight > 0 {
            // --- 情況 1: 鍵盤已彈出 ---
            if isTextInputMode {
                // **套用【公式 B】**
                let startY: CGFloat = 400.0
                let initialHeight: CGFloat = 60.0
                let heightDifference = textInputViewHeight - initialHeight
                
                return startY - (heightDifference)
            } else {
                // Add task 手動輸入時，使用您調整好的 380
                return 380.0
            }
        } else {
            // --- 情況 2: 鍵盤已收合 (保持您原本的邏輯) ---
            let safeAreaBottom = screenProxy.safeAreaInsets.bottom
            let buttonHeight: CGFloat = 70
            let contentBottomY = (listContentBottomY == 0) ? screenHeight : listContentBottomY
            let idealY = contentBottomY + (buttonHeight / 2) - 60
            let clampedY = min(idealY, screenHeight - safeAreaBottom - (buttonHeight / 2) - 100) // **<-- 將 80 修改為 170**
            return clampedY
        }
    }
    
    // MARK: - 懸浮按鈕視圖
        private func floatingInputButtons(screenProxy: GeometryProxy) -> some View {
            
        return ZStack {
            AddTaskButton(
                isEditing: $isManualEditing, displayText: $displayText, priority: $priority,
                isPinned: $isPinned, note: $note, isDateEnabled: $isDateEnabled,
                isTimeEnabled: $isTimeEnabled, selectedDate: $selectedDate,
                onTaskAdded: { loadTasksFromDataManager() },
                onShowAddTime: { showAddTimeView = true },
                onShowAddNote: { showAddNoteView = true },
                onTaskCreated: { newTask in
                    // 處理暫存新任務
                    pendingOperations.append(.addItem(newTask))
                    tempAddedItems.append(newTask)
                    print("SettlementView02: 已暫存新任務 - \(newTask.title)")
                }
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
                            // **▼▼▼ 從這裡開始新增 ▼▼▼**
                            .onPreferenceChange(ViewHeightKey.self) { newHeight in
                                // 當 TextEditor 內容高度變化時，更新狀態變數
                                // 只有在高度真的有變時才更新，避免不必要的畫面重繪
                                // 60 是 TextEditor 的最小高度
                                let currentHeight = max(newHeight, 60)
                                if self.textInputViewHeight != currentHeight {
                                    self.textInputViewHeight = currentHeight
                                }
                            }
                            // **▲▲▲ 在這裡結束新增 ▲▲▲**
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
            .frame(height: 70) // 直接使用 70，因為 buttonHeight 在這裡已經不可見
            // **▼▼▼ 從這裡開始修改 ▼▼▼**
            .position(x: screenProxy.size.width / 2, y: calculateButtonCenterY(screenProxy: screenProxy))
            .animation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.5), value: listContentBottomY)
            .animation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.5), value: keyboardHeight)
            // **▲▲▲ 在這裡結束修改 ▲▲▲**
        
    }

    @ViewBuilder
    private var bottomNavigationView: some View {
        let isSameDaySettlement = delaySettlementManager.isSameDaySettlement(isActiveEndDay: UserDefaults.standard.bool(forKey: "isActiveEndDay"))

        VStack(spacing: 0) {
            Spacer()
             VStack(spacing: 0) {
                // 📝 修改：代辦事項佇列只在主動結算時顯示
                if showTodoQueue && isSameDaySettlement {
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
                         },
                         onItemUpdated: { updatedItem in
                             // 處理項目狀態更新的暫存操作
                             pendingOperations.append(.updateItem(updatedItem))

                             // 如果這個項目在暫存新增列表中，直接更新它
                             if let index = tempAddedItems.firstIndex(where: { $0.id == updatedItem.id }) {
                                 tempAddedItems[index] = updatedItem
                                 print("SettlementView02: 更新暫存新增項目的狀態")
                             }

                             print("SettlementView02: 已暫存項目更新 - \(updatedItem.title)")
                         },
                         onItemMoved: { newItem, originalId in
                             // 處理項目移動的暫存操作
                             pendingOperations.append(.addItem(newItem))
                             pendingOperations.append(.deleteItem(originalId))
                             tempAddedItems.append(newItem)
                             tempDeletedItemIDs.insert(originalId)

                             print("SettlementView02: 已暫存項目移動 - 新增 \(newItem.title)，刪除原項目")

                             // 立即更新UI以反映移動
                             DispatchQueue.main.async {
                                 loadTasksFromDataManager()
                             }
                         }
                     )
                     .padding(.horizontal, 12)
                     .transition(.asymmetric(
                         insertion: .move(edge: .bottom).combined(with: .opacity).animation(.spring(response: 0.4, dampingFraction: 0.85)),
                         removal: .move(edge: .bottom).combined(with: .opacity).animation(.easeInOut(duration: 0.2))
                     ))
                     .padding(.bottom, 10)
                 } else if isSameDaySettlement {
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
                         /*
                         // 🔧 修復：根據結算類型決定後續流程
                         let isSameDaySettlement = delaySettlementManager.isSameDaySettlement(isActiveEndDay: UserDefaults.standard.bool(forKey: "isActiveEndDay"))

                         if isSameDaySettlement {
                             // 主動結算：跳轉到 SettlementView03 設置鬧鐘
                             print("SettlementView02: 主動結算，跳轉到 SettlementView03")
                             navigateToSettlementView03 = true
                         } else {
                             // 延期結算：直接完成結算流程，不需要鬧鐘設置
                             print("SettlementView02: 延期結算，直接完成結算流程")
                             executeDelayedSettlement()
                          */
                         print("SettlementView02: 準備跳轉到 SettlementView03，傳遞 \(pendingOperations.count) 個暫存操作")
                         navigateToSettlementView03 = true
                         
                     }) {
                         let isSameDaySettlement = delaySettlementManager.isSameDaySettlement(isActiveEndDay: UserDefaults.standard.bool(forKey: "isActiveEndDay"))
                         Text(isSameDaySettlement ? "Next" : "完成結算")
                             .font(Font.custom("Inria Sans", size: 20).weight(.bold))
                             .foregroundColor(.black)
                             .frame(maxWidth: .infinity)
                     }
                     .frame(width: 279, height: 60)
                     .background(.white)
                     .cornerRadius(40.5)
                     .disabled(isExecutingSettlement)  // 📝 新增：結算執行中時禁用按鈕
                     .opacity(isExecutingSettlement ? 0.6 : 1.0)  // 📝 視覺反饋
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
                        let now = Date()
                        let calendar = Calendar.current
                        let currentHour = calendar.component(.hour, from: now)
                        let isEarlyMorning = currentHour >= 0 && currentHour < 6

                        let targetDate: Date
                        if isEarlyMorning {
                            // 凌晨時段(0:00-6:00)，任務移到今天
                            targetDate = calendar.startOfDay(for: now)
                        } else {
                            // 其他時段，任務移到明天
                            targetDate = calendar.date(byAdding: .day, value: 1, to: now) ?? Date()
                        }

                        if item.taskDate == nil || item.taskDate! < targetDate {
                            item.taskDate = targetDate
                        }
                        Task {
                            do {
                                let _ = try await apiDataManager.addTodoItem(item)
                            } catch {
                                print("SettlementView02 - 添加任務失敗: \(error.localizedDescription)")
                            }
                        }
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

    /// 📝 新增：根據結算類型設定預設日期
    private func setupDefaultDate() {
        let now = Date()
        let calendar = Calendar.current
        let isSameDaySettlement = delaySettlementManager.isSameDaySettlement(isActiveEndDay: UserDefaults.standard.bool(forKey: "isActiveEndDay"))

        if isSameDaySettlement {
            // 主動結算：預設為明天
            let currentHour = calendar.component(.hour, from: now)
            let isEarlyMorning = currentHour >= 0 && currentHour < 6

            if isEarlyMorning {
                // 凌晨時段，設為今天
                selectedDate = now
                print("SettlementView02: 主動結算，凌晨時段，預設日期為今天")
            } else {
                // 其他時段，設為明天
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? Date()
                let tomorrowWithCurrentTime = calendar.date(bySettingHour: calendar.component(.hour, from: now),
                                                          minute: calendar.component(.minute, from: now),
                                                          second: 0,
                                                          of: calendar.startOfDay(for: tomorrow)) ?? tomorrow
                selectedDate = tomorrowWithCurrentTime
                print("SettlementView02: 主動結算，預設日期為明天")
            }
        } else {
            // 📝 延遲結算：預設為今天
            selectedDate = now
            print("SettlementView02: 延遲結算，預設日期為今天")
        }
    }

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
    
    /// 從 DataManager 重新載入任務列表（包含暫存操作的處理）
    private func loadTasksFromDataManager() {
        // 🔧 修復：使用原始數據作為基礎，避免暫存項目重複累積
        let originalItems = originalTodoItems

        // 處理暫存操作：過濾掉暫時刪除的項目，添加暫時新增的項目（但排除被暫存刪除的）
        var processedItems = originalItems.filter { !tempDeletedItemIDs.contains($0.id) }

        // 🔧 修復：暫存新增的項目也要檢查是否被暫存刪除了
        let filteredTempAddedItems = tempAddedItems.filter { !tempDeletedItemIDs.contains($0.id) }
        processedItems.append(contentsOf: filteredTempAddedItems)

        print("🔧 原始項目數量: \(originalItems.count)")
        print("🔧 暫存新增項目數量: \(tempAddedItems.count)")
        print("🔧 過濾後暫存新增項目數量: \(filteredTempAddedItems.count)")
        print("🔧 暫存刪除項目數量: \(tempDeletedItemIDs.count)")

        allTodoItems = processedItems
        print("SettlementView02 - 載入所有待辦事項: \(allTodoItems.count) 個（已處理 \(tempDeletedItemIDs.count) 個暫存刪除，\(tempAddedItems.count) 個暫存新增）")

        // 🔧 修復：無論 moveTasksToTomorrow 狀態如何，都需要處理任務顯示邏輯
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date())

        // 🔧 修復：根據結算類型決定要顯示的任務
        let isSameDaySettlement = delaySettlementManager.isSameDaySettlement(isActiveEndDay: UserDefaults.standard.bool(forKey: "isActiveEndDay"))
        // 靜默日誌: print("🔧 SettlementView02 - loadTasksFromDataManager: 結算類型判斷 = \(isSameDaySettlement ? "主動" : "延期")")
        print("🔧 existingTomorrowTaskIDs 數量: \(existingTomorrowTaskIDs.count)")

        dailyTasks = processedItems.filter { item in
            guard let taskDate = item.taskDate else { return false }
            let taskDay = calendar.startOfDay(for: taskDate)

            // 當天的未完成任務（所有結算類型都需要）
            let isTodayUncompleted = (taskDay == today) && (item.status == .toBeStarted || item.status == .undone)

            // 延遲結算需要包含的過去未完成任務
            let isPastUncompleted = (taskDay < today) && (item.status == .toBeStarted || item.status == .undone)

            if isSameDaySettlement {
                // 🎯 主動結算：顯示當天未完成 + 明天所有任務 + 新增任務
                let isTomorrowTask = (taskDay == tomorrow)
                let shouldInclude = isTodayUncompleted || isTomorrowTask
                if shouldInclude {
                    print("🔧 主動結算 - 包含任務: \(item.title) (今天未完成: \(isTodayUncompleted), 明天任務: \(isTomorrowTask))")
                }
                return shouldInclude
            } else {
                // 🎯 延期結算：根據 toggle 狀態決定要顯示的任務
                let isTomorrowTask = (taskDay == tomorrow)
                let isExistingTomorrowTask = existingTomorrowTaskIDs.contains(item.id)
                let isTomorrowNewTask = isTomorrowTask && !isExistingTomorrowTask

                let shouldInclude: Bool
                if moveTasksToTomorrow {
                    // Toggle 開啟：顯示當天未完成 + 過去未完成 + 新增任務
                    shouldInclude = isTodayUncompleted || isPastUncompleted || isTomorrowNewTask
                } else {
                    // Toggle 關閉：只顯示 settlement 期間新增的任務
                    shouldInclude = isTomorrowNewTask
                }

                if shouldInclude {
                    print("🔧 延期結算 - 包含任務: \(item.title) (今天未完成: \(isTodayUncompleted), 過去未完成: \(isPastUncompleted), 明天新任務: \(isTomorrowNewTask), toggle開啟: \(moveTasksToTomorrow))")
                }

                return shouldInclude
            }
        }
        print("SettlementView02 - 重新載入事件列表任務: \(dailyTasks.count) 個（結算類型：\(isSameDaySettlement ? "主動" : "延期")，已處理暫存操作）")
    }
    
    /// 暫存刪除任務（不立即執行，等到 SettlementView03 完成時才執行）
    private func deleteTask(_ task: TodoItem) {
        // 靜默日誌: print("🔧 SettlementView02: 開始刪除任務 - \(task.title) (ID: \(task.id))")
        print("🔧 刪除前 tempDeletedItemIDs 數量: \(tempDeletedItemIDs.count)")
        print("🔧 刪除前 pendingOperations 數量: \(pendingOperations.count)")

        // 添加到暫存操作記錄
        pendingOperations.append(.deleteItem(task.id))

        // 標記為暫時刪除
        tempDeletedItemIDs.insert(task.id)

        print("🔧 刪除後 tempDeletedItemIDs 數量: \(tempDeletedItemIDs.count)")
        print("🔧 刪除後 pendingOperations 數量: \(pendingOperations.count)")

        // 立即更新 UI 顯示
        print("🔧 開始重新載入任務列表...")
        loadTasksFromDataManager()

        // 靜默日誌: print("🔧 SettlementView02: 任務已標記為暫存刪除，等待結算完成後才會真正刪除")
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

    // 加載初始數據
    private func loadInitialData() {
        Task {
            do {
                let allItems = try await apiDataManager.getAllTodoItems()
                await MainActor.run {
                    processInitialData(allItems)
                }
            } catch {
                await MainActor.run {
                    print("SettlementView02 - 加載初始數據失敗: \(error.localizedDescription)")
                }
            }
        }
    }

    // 處理初始數據
    private func processInitialData(_ allItems: [TodoItem]) {
        // 先更新 allTodoItems 以確保有完整的數據
        self.allTodoItems = allItems
        // 📝 新增：同時更新原始數據
        self.originalTodoItems = allItems

        if moveTasksToTomorrow {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date())

            // 記錄settlement開始時明天已有的任務ID
            let existingTomorrowTaskIDs: Set<UUID> = Set(allItems.compactMap { task -> UUID? in
                guard let taskDate = task.taskDate else { return nil }
                let taskDay = calendar.startOfDay(for: taskDate)
                return taskDay == tomorrow ? task.id : nil
            })

            // 判斷結算類型
            let isActiveEndDay = UserDefaults.standard.bool(forKey: "isActiveEndDay")
            let isSameDaySettlement = delaySettlementManager.isSameDaySettlement(isActiveEndDay: isActiveEndDay)

            // 根據結算類型篩選要顯示的任務
            let settlementTasks: [TodoItem]

            if isSameDaySettlement {
                // 當天結算：只顯示當天的未完成任務
                settlementTasks = allItems.filter { task in
                    guard let taskDate = task.taskDate else { return false }
                    let taskDay = calendar.startOfDay(for: taskDate)
                    return (taskDay == today) && (task.status == .toBeStarted || task.status == .undone)
                }
            } else {
                // 延遲結算：顯示從上次結算日期到昨天的未完成任務
                let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
                let lastSettlementDate = delaySettlementManager.getLastSettlementDate()

                if let lastSettlement = lastSettlementDate {
                    let lastSettlementDay = calendar.startOfDay(for: lastSettlement)
                    let dayAfterLastSettlement = calendar.date(byAdding: .day, value: 1, to: lastSettlementDay) ?? lastSettlementDay

                    settlementTasks = allItems.filter { task in
                        guard let taskDate = task.taskDate else { return false }
                        let taskDay = calendar.startOfDay(for: taskDate)
                        let isInRange = taskDay >= dayAfterLastSettlement && taskDay <= yesterday
                        let isUncompleted = task.status == .toBeStarted || task.status == .undone
                        return isInRange && isUncompleted
                    }
                } else {
                    // 沒有上次結算記錄，只看昨天的未完成任務
                    settlementTasks = allItems.filter { task in
                        guard let taskDate = task.taskDate else { return false }
                        let taskDay = calendar.startOfDay(for: taskDate)
                        return (taskDay == yesterday) && (task.status == .toBeStarted || task.status == .undone)
                    }
                }
            }

            // 只有在 API 數據與樂觀更新數據不同時才更新 dailyTasks
            if dailyTasks.count != settlementTasks.count ||
               !Set(dailyTasks.map { $0.id }).isSuperset(of: Set(settlementTasks.map { $0.id })) {
                self.dailyTasks = settlementTasks
                print("SettlementView02 - 已更新事件列表: \(settlementTasks.count) 個任務")
            }
            // 移除 "數據一致" 的日誌，因為這是正常情況

            self.existingTomorrowTaskIDs = existingTomorrowTaskIDs
        } else {
            // 如果不移動任務到明天，清空任務列表
            self.dailyTasks = []
            print("SettlementView02 - processInitialData: toggle關閉，清空任務列表")
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

// 目標日期視圖（根據時間段顯示"Today"或"Tomorrow"）
struct TomorrowDateView: View {
    let tomorrow: Date
    let formatDateForDisplay: (Date) -> (monthDay: String, weekday: String)

    // 計算目標日期和顯示文字
    private var targetInfo: (date: Date, text: String) {
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        let isEarlyMorning = currentHour >= 0 && currentHour < 6

        // 檢查是否是延遲結算
        let delaySettlementManager = DelaySettlementManager.shared
        let isActiveEndDay = UserDefaults.standard.bool(forKey: "isActiveEndDay")
        let isSameDaySettlement = delaySettlementManager.isSameDaySettlement(isActiveEndDay: isActiveEndDay)


        if !isSameDaySettlement {
            // 延遲結算：任務移動到今天，顯示"Today"
            let today = calendar.startOfDay(for: now)
            return (today, "Today")
        } else if isEarlyMorning {
            // 當天結算 + 凌晨時段：顯示"Today"
            let today = calendar.startOfDay(for: now)
            return (today, "Today")
        } else {
            // 當天結算 + 其他時間：顯示"Tomorrow"
            return (tomorrow, "Tomorrow")
        }
    }

    var body: some View {
        let targetDateParts = formatDateForDisplay(targetInfo.date)

        HStack(alignment: .bottom) {
            // 左側日期文字（動態顯示）
            Text(targetInfo.text)
                .font(Font.custom("Instrument Sans", size: 31.79449).weight(.bold))
                .foregroundColor(.white)

            Spacer()

            // 右側日期文本
            HStack(spacing: 2) {
                Text(targetDateParts.monthDay)
                    .font(Font.custom("Instrument Sans", size: 20.65629).weight(.bold))
                    .foregroundColor(.white)

                Text("   ") // 空格

                Text(targetDateParts.weekday)
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
    let onTaskCreated: (TodoItem) -> Void  // 新增：處理任務創建的回調
    
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

        // 📝 修復：根據用戶的日期/時間設定決定任務類型
        let finalTaskDate: Date?
        if isDateEnabled || isTimeEnabled {
            // 如果用戶有明確選擇日期/時間，使用用戶選擇的
            finalTaskDate = selectedDate
            print("SettlementView02: 用戶選擇的日期/時間: \(selectedDate)")
        } else {
            // 📝 修復：根據結算類型決定預設日期
            let now = Date()
            let calendar = Calendar.current
            let isSameDaySettlement = DelaySettlementManager.shared.isSameDaySettlement(isActiveEndDay: UserDefaults.standard.bool(forKey: "isActiveEndDay"))

            if isSameDaySettlement {
                // 主動結算：新增任務預設為明天
                let currentHour = calendar.component(.hour, from: now)
                let isEarlyMorning = currentHour >= 0 && currentHour < 6

                if isEarlyMorning {
                    // 凌晨時段，設為今天開始時間（00:00）
                    finalTaskDate = calendar.startOfDay(for: now)
                    print("SettlementView02: 主動結算，凌晨時段設為今天開始時間")
                } else {
                    // 其他時段，設為明天開始時間（00:00）
                    let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? Date()
                    finalTaskDate = calendar.startOfDay(for: tomorrow)
                    print("SettlementView02: 主動結算，設為明天開始時間")
                }
            } else {
                // 📝 延遲結算：新增任務預設為當天
                finalTaskDate = calendar.startOfDay(for: now)
                print("SettlementView02: 延遲結算，設為今天開始時間")
            }
        }
        
        // 請根據您的 TodoItem 初始化方法確認以下參數是否完整
        let newTask = TodoItem(
            id: UUID(),
            userID: "user_id", // 請替換為真實用戶ID
            title: displayText,
            priority: priority,
            isPinned: isPinned,
            taskDate: finalTaskDate,
            note: note,
            taskType: finalTaskDate != nil ? .scheduled : .memo,
            completionStatus: .pending,
            status: .toBeStarted,
            createdAt: Date(),
            updatedAt: Date(),
            correspondingImageID: "new_task"
        )
        
        // 在保存前再次確認任務日期
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let taskDate = newTask.taskDate {
            print("SettlementView02: 即將保存的任務日期 - \(formatter.string(from: taskDate))")
        } else {
            print("SettlementView02: 即將保存的任務沒有日期（備忘錄）")
        }

        // 通過回調函數通知父視圖處理暫存操作
        print("SettlementView02: 創建新任務，通知父視圖進行暫存處理: \(newTask.title)")
        if let taskDate = newTask.taskDate {
            print("SettlementView02: 新任務的日期 - \(formatter.string(from: taskDate))")
        } else {
            print("SettlementView02: 新任務沒有日期（備忘錄）")
        }

        // 通過回調通知父視圖處理任務創建
        onTaskCreated(newTask)

        // 立即更新 UI 顯示
        onTaskAdded()

        print("SettlementView02: 任務創建已通知父視圖處理")
        resetEditingState()
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
        // 重置selectedDate時也要考慮早晨時段邏輯
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let isEarlyMorning = currentHour >= 0 && currentHour < 6

        if isEarlyMorning {
            // 凌晨時段重置為今天的當前時間
            selectedDate = now
        } else {
            // 其他時段重置為明天的當前時間
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? Date()
            let tomorrowWithCurrentTime = calendar.date(bySettingHour: calendar.component(.hour, from: now),
                                                      minute: calendar.component(.minute, from: now),
                                                      second: 0,
                                                      of: calendar.startOfDay(for: tomorrow)) ?? tomorrow
            selectedDate = tomorrowWithCurrentTime
        }
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
    let onItemUpdated: ((TodoItem) -> Void)?  // 新增：處理項目更新的回調
    let onItemMoved: ((TodoItem, UUID) -> Void)?  // 新增：處理項目移動的回調
    
    let filters: [String] = ["全部", "備忘錄", "未完成"]
    
    // 根據選取條件過濾待辦事項（與 ToDoSheetView 完全一致）
    private var filteredItems: [TodoItem] {
        switch selectedFilter {
        case "全部":
            // 全部項目 - 備忘錄 + 未完成項目（排除已完成項目）
            let today = Calendar.current.startOfDay(for: Date())
            return items.filter { item in
                // 排除已完成項目
                guard item.status != .completed else { return false }

                // 包含備忘錄項目（沒有日期）
                if item.taskDate == nil {
                    return true
                }

                // 包含過去日期的未完成項目
                let taskDay = Calendar.current.startOfDay(for: item.taskDate!)
                return taskDay < today &&
                       (item.status == .undone || item.status == .toBeStarted)
            }
        case "備忘錄":
            // 備忘錄 - 篩選沒有時間的項目且非已完成狀態
            return items.filter {
                $0.taskDate == nil && $0.status != .completed
            }
        case "未完成":
            // 未完成 - 過去日期且狀態為未完成（不包含今天和未來）
            let today = Calendar.current.startOfDay(for: Date())
            return items.filter {
                guard let taskDate = $0.taskDate else { return false }
                let taskDay = Calendar.current.startOfDay(for: taskDate)
                return taskDay < today &&
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

            // 待辦事項列表 - 使用 ScrollView 並限制高度
            ScrollView {
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
                                    },
                                    onItemUpdated: onItemUpdated,
                                    onItemMoved: onItemMoved
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
            }
            .frame(maxHeight: 300) // 限制最大高度為 300
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
    var onItemUpdated: ((TodoItem) -> Void)? = nil  // 新增：處理項目更新的回調
    var onItemMoved: ((TodoItem, UUID) -> Void)? = nil  // 新增：處理項目移動的回調（新項目, 原項目ID）
    
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

                    // 通過回調通知父視圖處理狀態更新
                    print("SettlementTodoItem: 項目狀態更新 - \(item.title) 狀態變更為 \(item.status)")

                    if let onItemUpdated = onItemUpdated {
                        onItemUpdated(item)
                    }

                    print("SettlementTodoItem: 狀態更新已通知父視圖處理")
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
                
                // 右側箭頭按鈕 - 添加到明天事件列表
                Button {
                    print("SettlementTodoItem: 將項目添加到明天事件列表 - \(item.title)")

                    // 創建一個新的副本
                    var tomorrowItem = item

                    // 檢查是否沒有時間或者時間為00:00，同時考慮早晨時段邏輯
                    let calendar = Calendar.current
                    let now = Date()
                    let currentHour = calendar.component(.hour, from: now)
                    let isEarlyMorning = currentHour >= 0 && currentHour < 6

                    let targetDate: Date
                    if isEarlyMorning {
                        // 凌晨時段(0:00-6:00)，任務移到今天
                        targetDate = calendar.startOfDay(for: now)
                        print("SettlementTodoItem: 凌晨時段，任務移到今天")
                    } else {
                        // 其他時段，任務移到明天
                        targetDate = calendar.date(byAdding: .day, value: 1, to: now) ?? Date()
                        print("SettlementTodoItem: 其他時段，任務移到明天")
                    }

                    if tomorrowItem.taskDate == nil {
                        // 如果是備忘錄（沒有日期時間），設定目標日期的開始時間
                        tomorrowItem.taskDate = calendar.startOfDay(for: targetDate)
                        print("SettlementTodoItem: 備忘錄項目設定為目標日期 00:00:00")
                    } else {
                        // 檢查時間是否為 00:00:00（表示只有日期沒有時間）
                        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: tomorrowItem.taskDate!)
                        let isTimeZero = (timeComponents.hour == 0 && timeComponents.minute == 0 && timeComponents.second == 0)

                        if isTimeZero {
                            // 如果原本是 00:00:00，設定為目標日期的 00:00:00
                            tomorrowItem.taskDate = calendar.startOfDay(for: targetDate)
                            print("SettlementTodoItem: 日期無時間事件設定為目標日期 00:00:00")
                        } else {
                            // 如果已有具體時間，保留原時間但更新日期為目標日期
                            var targetComponents = calendar.dateComponents([.year, .month, .day], from: targetDate)
                            targetComponents.hour = timeComponents.hour
                            targetComponents.minute = timeComponents.minute
                            targetComponents.second = timeComponents.second

                            if let newDate = calendar.date(from: targetComponents) {
                                tomorrowItem.taskDate = newDate
                                print("SettlementTodoItem: 保留原時間 \(timeComponents.hour ?? 0):\(timeComponents.minute ?? 0)，設定為目標日期")
                            } else {
                                // 如果日期組合失敗，使用目標日期的開始時間作為後備
                                tomorrowItem.taskDate = calendar.startOfDay(for: targetDate)
                                print("SettlementTodoItem: 日期組合失敗，使用目標日期開始時間")
                            }
                        }
                    }

                    // 如果之前是備忘錄（待辦佇列），更改狀態為 toBeStarted
                    if tomorrowItem.status == .toDoList {
                        tomorrowItem.status = .toBeStarted
                    }

                    // 更新 updatedAt 時間戳
                    tomorrowItem.updatedAt = Date()

                    // 創建一個新的項目而不是更新現有項目
                    let newTomorrowItem = TodoItem(
                        id: UUID(),  // 新的 ID
                        userID: tomorrowItem.userID,
                        title: tomorrowItem.title,
                        priority: tomorrowItem.priority,
                        isPinned: tomorrowItem.isPinned,
                        taskDate: tomorrowItem.taskDate,
                        note: tomorrowItem.note,
                        taskType: tomorrowItem.taskDate != nil ? .scheduled : .memo,
                        completionStatus: tomorrowItem.status == .completed ? .completed : .pending,
                        status: tomorrowItem.status,
                        createdAt: Date(),  // 新的創建時間
                        updatedAt: Date(),
                        correspondingImageID: tomorrowItem.correspondingImageID
                    )

                    // 通過回調通知父視圖處理項目移動
                    print("SettlementTodoItem: 項目移動操作 - 添加新項目到明天事件列表")
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    if let taskDate = newTomorrowItem.taskDate {
                        print("SettlementTodoItem: 新項目的任務時間為 - \(formatter.string(from: taskDate))")
                    }

                    // 通過回調通知父視圖處理移動操作
                    if let onItemMoved = onItemMoved {
                        onItemMoved(newTomorrowItem, item.id)
                    }

                    print("SettlementTodoItem: 項目移動操作已通知父視圖處理")

                    // 通知重新載入數據以更新 UI
                    if let onAddToToday = onAddToToday {
                        onAddToToday(newTomorrowItem)
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
            TodoItem(id: UUID(), userID: "testUser", title: "测试任务1", priority: 2, isPinned: false, taskDate: Date(), note: "", taskType: .scheduled, completionStatus: .pending, status: .undone, createdAt: Date(), updatedAt: Date(), correspondingImageID: ""),
            TodoItem(id: UUID(), userID: "testUser", title: "测试任务2", priority: 1, isPinned: true, taskDate: nil, note: "", taskType: .memo, completionStatus: .pending, status: .undone, createdAt: Date(), updatedAt: Date(), correspondingImageID: "")
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
        print("結算完成時開始將 \(uncompletedTasks.count) 個未完成任務移至適當日期")

        let calendar = Calendar.current
        let now = Date()

        // 檢查是否在凌晨0:00-6:00時間段
        let currentHour = calendar.component(.hour, from: now)
        let isEarlyMorning = currentHour >= 0 && currentHour < 6

        // 檢查結算類型
        let delaySettlementManager = DelaySettlementManager.shared
        let isActiveEndDay = UserDefaults.standard.bool(forKey: "isActiveEndDay")
        let isSameDaySettlement = delaySettlementManager.isSameDaySettlement(isActiveEndDay: isActiveEndDay)


        // 根據結算類型和時間段決定移動邏輯
        let sourceDay: Date
        let targetDay: Date

        if !isSameDaySettlement {
            // 延遲結算：統一將所有未完成任務移動到今天
            let today = calendar.startOfDay(for: now)
            // 對於延遲結算，源日期應該是任務原本的日期，不需要特別限制
            // 但我們仍需要為過濾邏輯設定一個參考日期
            sourceDay = today // 這個值在延遲結算中可能需要重新思考
            targetDay = today
            print("延遲結算：將未完成任務移至今天 \(today)")
        } else if isEarlyMorning {
            // 當天結算 + 凌晨0:00-6:00：昨天的任務移到今天
            let today = calendar.startOfDay(for: now)
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
            sourceDay = yesterday
            targetDay = today
            print("當天結算 + 凌晨時段(\(currentHour):xx)：將昨天的未完成任務移至今天")
        } else {
            // 當天結算 + 其他時間：今天的任務移到明天
            let today = calendar.startOfDay(for: now)
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
            sourceDay = today
            targetDay = tomorrow
            print("當天結算 + 一般時段(\(currentHour):xx)：將今天的未完成任務移至明天")
        }

        // 篩選要移動的任務：根據結算類型決定過濾邏輯
        let tasksToMove: [TodoItem]

        if !isSameDaySettlement {
            // 延遲結算：移動所有未完成任務（因為它們已經通過 SettlementViewModel 篩選過了）
            tasksToMove = uncompletedTasks.filter { task in
                // 只排除備忘錄（沒有日期的任務）
                return task.taskDate != nil
            }
            print("延遲結算過濾：所有有日期的未完成任務都移動，共 \(tasksToMove.count) 個")
        } else {
            // 當天結算：根據源日期篩選
            tasksToMove = uncompletedTasks.filter { task in
                guard let taskDate = task.taskDate else {
                    // 沒有日期的任務（備忘錄）不應該被移動
                    return false
                }
                let taskDay = calendar.startOfDay(for: taskDate)
                return taskDay == sourceDay
            }
            print("當天結算過濾：篩選源日期為 \(sourceDay) 的任務，共 \(tasksToMove.count) 個")
        }

        print("實際將移動的未完成任務: \(tasksToMove.count) 個（從總計 \(uncompletedTasks.count) 個中篩選）")


        for task in tasksToMove {
            // 決定新的任務時間
            let newTaskDate: Date?

            if let originalTaskDate = task.taskDate {
                // 如果原本有時間，檢查是否為 00:00:00
                let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: originalTaskDate)
                let isTimeZero = (timeComponents.hour == 0 && timeComponents.minute == 0 && timeComponents.second == 0)

                if isTimeZero {
                    // 原本是 00:00:00 的事件（日期無時間），移至目標日期的 00:00:00
                    newTaskDate = calendar.startOfDay(for: targetDay)
                    print("任務 '\(task.title)' 原本是日期無時間，移至目標日期的 00:00:00")
                } else {
                    // 原本有具體時間的事件，保留時間但改日期為目標日期
                    var targetComponents = calendar.dateComponents([.year, .month, .day], from: targetDay)
                    targetComponents.hour = timeComponents.hour
                    targetComponents.minute = timeComponents.minute
                    targetComponents.second = timeComponents.second

                    newTaskDate = calendar.date(from: targetComponents)
                    print("任務 '\(task.title)' 保留原時間 \(timeComponents.hour ?? 0):\(timeComponents.minute ?? 0)，移至目標日期")
                }
            } else {
                // 原本就沒有時間（備忘錄），保持沒有時間
                newTaskDate = nil
                print("任務 '\(task.title)' 原本是備忘錄，移動後保持為備忘錄")
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
                taskType: newTaskDate != nil ? .scheduled : .memo,
                completionStatus: task.status == .completed ? .completed : .pending,
                status: task.status,
                createdAt: task.createdAt,
                updatedAt: Date(), // 更新修改時間
                correspondingImageID: task.correspondingImageID
            )

            // 使用API更新任務
            Task {
                do {
                    let _ = try await apiDataManager.updateTodoItem(updatedTask)
                    print("結算完成時成功將任務 '\(task.title)' 移至明日")
                } catch {
                    print("結算完成時移動任務 '\(task.title)' 失敗: \(error.localizedDescription)")
                }
            }
        }

        print("結算完成時完成未完成任務移至明日的處理")

        // 發送通知讓 Home.swift 重新載入數據
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(name: Notification.Name("TodoItemStatusChanged"), object: nil)
        }
    }

    // MARK: - 延期結算專用函數
    /// 執行延期結算流程（不包含鬧鐘設置）
    private func executeDelayedSettlement() {
        // 📝 修復：防止重複執行
        guard !isExecutingSettlement else {
            print("SettlementView02: 結算正在執行中，忽略重複調用")
            return
        }

        isExecutingSettlement = true
        print("SettlementView02: 開始執行延期結算流程")

        // 1. 執行所有暫存操作（使用回調確保完成）
        executeAllPendingOperationsWithCompletion {

            print("延期結算: 所有暫存操作執行完成")

            // 2. 如果需要移動任務，先執行移動（在標記結算完成之前）
            if moveTasksToTomorrow && !uncompletedTasks.isEmpty {
                moveUncompletedTasksToTomorrowData()
                print("延期結算: 已移動 \(uncompletedTasks.count) 個未完成任務到明天")
            }

            // 3. 標記今天為已完成
            let completeDayDataManager = CompleteDayDataManager.shared
            completeDayDataManager.markTodayAsCompleted()
            print("延期結算: 已標記今天為已完成的一天")

            // 4. 標記結算流程完成
            delaySettlementManager.markSettlementCompleted()
            print("延期結算: 已標記結算流程完成")

            // 5. 清除主動結算標記（因為這是延期結算）
            UserDefaults.standard.set(false, forKey: "isActiveEndDay")

            // 6. 更新 Widget 數據
            Task {
                await apiDataManager.forceUpdateWidgetData()
            }

            // 7. 發送結算完成通知給 ContentView
            print("延期結算: 發送結算完成通知")
            NotificationCenter.default.post(name: Notification.Name("SettlementCompleted"), object: nil)

            // 8. 📝 修復：立即導航回 Home，不需要延遲
            print("延期結算: 完成所有操作，立即導航回 Home")
            navigateToHome = true
        }
    }

    /// 執行所有暫存操作（從 SettlementView03 複製過來）
    private func executeAllPendingOperations() {
        print("SettlementView02: 開始執行 \(pendingOperations.count) 個暫存操作")

        Task {
            var hasErrors = false

            for operation in pendingOperations {
                switch operation {
                case .addItem(let item):
                    print("SettlementView02: 執行添加操作 - \(item.title)")
                    do {
                        let _ = try await apiDataManager.addTodoItem(item)
                        print("SettlementView02: 成功執行添加操作 - \(item.title)")
                    } catch {
                        print("SettlementView02: 添加操作失敗 - \(item.title): \(error.localizedDescription)")
                        hasErrors = true
                    }

                case .deleteItem(let itemId):
                    print("SettlementView02: 執行刪除操作 - ID: \(itemId)")
                    do {
                        try await apiDataManager.deleteTodoItem(withID: itemId)
                        print("SettlementView02: 成功執行刪除操作 - ID: \(itemId)")
                    } catch {
                        print("SettlementView02: 刪除操作失敗 - ID: \(itemId): \(error.localizedDescription)")
                        hasErrors = true
                    }

                case .updateItem(let item):
                    print("SettlementView02: 執行更新操作 - \(item.title)")
                    do {
                        let _ = try await apiDataManager.updateTodoItem(item)
                        print("SettlementView02: 成功執行更新操作 - \(item.title)")
                    } catch {
                        print("SettlementView02: 更新操作失敗 - \(item.title): \(error.localizedDescription)")
                        hasErrors = true
                    }
                }
            }

            await MainActor.run {
                if hasErrors {
                    print("SettlementView02: 暫存操作執行完成，但有錯誤發生")
                } else {
                    print("SettlementView02: 所有暫存操作執行成功完成")
                }

                // 結算完成後更新 Widget 數據
                Task {
                    await apiDataManager.forceUpdateWidgetData()
                }
            }
        }
    }

    /// 執行所有暫存操作並在完成時調用回調
    private func executeAllPendingOperationsWithCompletion(completion: @escaping () -> Void) {
        print("SettlementView02: 開始執行 \(pendingOperations.count) 個暫存操作（帶完成回調）")

        guard !pendingOperations.isEmpty else {
            print("SettlementView02: 沒有暫存操作需要執行，直接完成")
            DispatchQueue.main.async {
                completion()
            }
            return
        }

        Task {
            var hasErrors = false

            for operation in pendingOperations {
                switch operation {
                case .addItem(let item):
                    print("SettlementView02: 執行添加操作 - \(item.title)")
                    do {
                        let _ = try await apiDataManager.addTodoItem(item)
                        print("SettlementView02: 成功執行添加操作 - \(item.title)")
                    } catch {
                        print("SettlementView02: 添加操作失敗 - \(item.title): \(error.localizedDescription)")
                        hasErrors = true
                    }

                case .deleteItem(let itemId):
                    print("SettlementView02: 執行刪除操作 - ID: \(itemId)")
                    do {
                        try await apiDataManager.deleteTodoItem(withID: itemId)
                        print("SettlementView02: 成功執行刪除操作 - ID: \(itemId)")
                    } catch {
                        print("SettlementView02: 刪除操作失敗 - ID: \(itemId): \(error.localizedDescription)")
                        hasErrors = true
                    }

                case .updateItem(let item):
                    print("SettlementView02: 執行更新操作 - \(item.title)")
                    do {
                        let _ = try await apiDataManager.updateTodoItem(item)
                        print("SettlementView02: 成功執行更新操作 - \(item.title)")
                    } catch {
                        print("SettlementView02: 更新操作失敗 - \(item.title): \(error.localizedDescription)")
                        hasErrors = true
                    }
                }
            }

            await MainActor.run {
                if hasErrors {
                    print("SettlementView02: 暫存操作執行完成，但有錯誤發生")
                } else {
                    print("SettlementView02: 所有暫存操作執行成功完成")
                }
                completion()
            }
        }
    }
}
