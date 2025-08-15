import SwiftUI
import SpriteKit
import CloudKit

struct Home: View {
    @State private var showCalendarView: Bool = false
    @State private var updateStatus: String = ""
    @State private var showToDoSheet: Bool = false
    @State private var showAddTaskSheet: Bool = false
    @State private var currentDate: Date = Date()  // 添加當前時間狀態
    @State private var navigateToSettlementView: Bool = false // 導航到結算頁面
    @State private var navigateToSleep01View: Bool = false // 導航到Sleep01視圖
    @State private var isSleepMode: Bool = false // 睡眠模式狀態
    @State private var alarmTimeString: String = "9:00 AM" // 鬧鐘時間，默認為9:00 AM
    @State private var dayProgress: Double = 0.0 // 與Sleep01相同，用來顯示進度條
    
    // 用於監控數據變化的屬性
    @State private var dataRefreshToken: UUID = UUID() // 用於強制視圖刷新
    
    // 明確的 Add 視圖模式枚舉
    enum AddTaskMode {
        case memo      // 備忘錄模式（從待辦事項佇列添加）
        case today     // 今天模式（從今天添加）
        case future    // 未來日期模式（從未來日期添加）
    }
    
    // 直接使用枚舉來追踪 Add 視圖的模式
    @State private var addTaskMode: AddTaskMode = .today
    
    // 新增：一個全局標記，用於確保從待辦事項佇列添加時一定是備忘錄模式
    // 也需要標記為 @State，因為 struct 中的屬性默認是不可變的
    @State private var isFromTodoSheet: Bool = false
    @State private var timer: Timer?  // 添加定時器
    @State private var toDoItems: [TodoItem] = []
    @State private var isLoading: Bool = true
    @State private var loadingError: String? = nil
    @State private var isSyncing: Bool = false // 新增：同步狀態標記
    
    // 添加长按项目功能的状态
    @State private var showingDeleteView: Bool = false
    @State private var selectedItem: TodoItem? = nil
    @State private var showingEditSheet: Bool = false

    // === 修改點：新增 State ===
    // 將 TaskSelectionOverlay 的狀態從 HomeBottomView 提升至此處
    @State private var showTaskSelectionOverlay: Bool = false
    @State private var pendingTasks: [TodoItem] = []
    
    // 跟踪已删除项目ID的集合，防止它们重新出现
    // 使用UserDefaults持久化存储，确保应用重启后仍然有效
    @State private var recentlyDeletedItemIDs: Set<UUID> = {
        if let savedData = UserDefaults.standard.data(forKey: "recentlyDeletedItemIDs"),
           let decodedIDs = try? JSONDecoder().decode([UUID].self, from: savedData) {
            return Set(decodedIDs)
        }
        return []
    }()
    
    // 添加水平滑動狀態
    @State private var currentDateOffset: Int = 0 // 日期偏移量
    @GestureState private var dragOffset: CGFloat = 0 // 拖動偏移量
    
    // 數據同步管理器 - 處理本地存儲和雲端同步
    private let dataSyncManager = DataSyncManager.shared
    
    // 已完成日期數據管理器 - 追蹤已完成的日期
    private let completeDayDataManager = CompleteDayDataManager.shared
    
    // 延遲結算管理器 - 處理結算顯示和時間追蹤
    private let delaySettlementManager = DelaySettlementManager.shared
    
    // 修改後的taiwanTime，基於currentDate和日期偏移量
    var taiwanTime: (monthDay: String, weekday: String, timeStatus: String) {
        let currentDateWithOffset = Calendar.current.date(byAdding: .day, value: currentDateOffset, to: currentDate) ?? currentDate
        
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Taipei")
        formatter.locale = Locale(identifier: "en_US")  // 改為英文
        
        // 月份和日期
        formatter.dateFormat = "MMM dd"
        let monthDay = formatter.string(from: currentDateWithOffset)
        
        // 星期幾（英文）
        formatter.dateFormat = "EEEE"
        let weekday = formatter.string(from: currentDateWithOffset)
        
        // 時間和清醒狀態
        formatter.dateFormat = "HH:mm"
        let time = formatter.string(from: currentDateWithOffset)
        let timeStatus = "\(time) awake"
        
        return (monthDay: monthDay, weekday: weekday, timeStatus: timeStatus)
    }
    
    // 用於更新睡眠模式下的進度條 - 更改為每秒更新一次，使動畫更流暢
    private let sleepModeTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var taipeiCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return calendar
    }
    
    private var alarmStringParser: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return formatter
    }
    
    // 檢查是否為當天
    private var isCurrentDay: Bool {
        return currentDateOffset == 0
    }
    
    // 檢查當前顯示的日期是否已完成
    private var isCurrentDisplayDayCompleted: Bool {
        let dateWithOffset = Calendar.current.date(byAdding: .day, value: currentDateOffset, to: currentDate) ?? currentDate
        return completeDayDataManager.isDayCompleted(date: dateWithOffset)
    }
    
    // 計算屬性：篩選並排序當前日期的待辦事項
    private var sortedToDoItems: [TodoItem] {
        // 獲取帶偏移量的日期
        let dateWithOffset = Calendar.current.date(byAdding: .day, value: currentDateOffset, to: currentDate) ?? currentDate
        
        // 獲取篩選日期的開始和結束時間點
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: dateWithOffset)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // 篩選當天的項目（只包含有時間的項目）
        let filteredItems = toDoItems.filter { item in
            // 先過濾有任務日期的項目，再進行日期比較
            guard let taskDate = item.taskDate else {
                return false // 沒有日期的項目（備忘錄）不包含在指定日期內
            }
            return taskDate >= startOfDay && taskDate < endOfDay
        }
        
        // 排序：先按置頂狀態排序，再按優先級排序(高到低)，最後按任務日期排序
        return filteredItems.sorted { item1, item2 in
            // 置頂項目優先
            if item1.isPinned && !item2.isPinned {
                return true
            }
            if !item1.isPinned && item2.isPinned {
                return false
            }
            
            // 如果置頂狀態相同，按優先級排序（由高到低）
            if item1.priority != item2.priority {
                return item1.priority > item2.priority
            }
                        
            // 如果優先級相同，按任務日期排序（由早到晚）
            // 因為這個階段的項目都已經通過了前面的過濾，所以已經確保它們都有任務日期
            let date1 = item1.taskDate ?? Date.distantFuture
            let date2 = item2.taskDate ?? Date.distantFuture
            return date1 < date2
        }
    }

    // 提供索引訪問方法，用於在ForEach中使用
    private func getBindingToSortedItem(at index: Int) -> Binding<TodoItem> {
        let sortedItem = sortedToDoItems[index]
        // 找到原始數組中的索引
        if let originalIndex = toDoItems.firstIndex(where: { $0.id == sortedItem.id }) {
            return $toDoItems[originalIndex]
        }
        // 這種情況理論上不應該發生，但提供一個後備選項
        return Binding<TodoItem>(
            get: { sortedItem },
            set: { newValue in
                // 如果數據模型被更新，嘗試將更改同步到 CloudKit
                if let index = self.toDoItems.firstIndex(where: { $0.id == newValue.id }) {
                    self.toDoItems[index] = newValue
                    
                    // 使用 DataSyncManager 更新項目 - 它會先更新本地然後同步到雲端
                    self.dataSyncManager.updateTodoItem(newValue) { result in
                        switch result {
                        case .success(_):
                            print("成功更新待辦事項")
                        case .failure(let error):
                            print("更新待辦事項失敗: \(error.localizedDescription)")
                        }
                    }
                }
            }
        )
    }

    // 添加一個計算屬性來動態計算底部 padding
    private var bottomPaddingForTaskList: CGFloat {
        // 當天顯示物理場景時需要更多間距
        // 非當天只顯示按鈕時需要較少間距
        return isCurrentDay ? 170 : 90
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // 1. 背景
                Color.black
                    .ignoresSafeArea()
                
                // 2. 主介面內容 (會被模糊)
                ZStack{
                    VStack(spacing: 0) {
                        // Header
                        VStack(spacing: 0) {
                            UserInfoView(
                                avatarImageName: "who",
                                dateText: taiwanTime.monthDay,
                                dateText2: taiwanTime.weekday,
                                statusText: taiwanTime.timeStatus,
                                temperatureText: "26°C",
                                showCalendarView: $showCalendarView
                            )
                            .frame(maxWidth: .infinity, maxHeight: 0)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            // 待辦事項佇列按鈕
                            HStack {
                                Button {
                                    withAnimation { showToDoSheet.toggle() }
                                } label: {
                                    Text("待辦事項佇列")
                                        .font(.custom("Inter", size: 14).weight(.semibold))
                                        .foregroundColor(.white)
                                        .padding(10)
                                        .background(Color.white.opacity(0.15))
                                        .cornerRadius(8)
                                }
                                .contentShape(Rectangle())
                                
                                Spacer()
                                
                                Image(systemName: "ellipsis")
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 60)
                            
                            // 節日區塊
                            VStack(spacing: 0) {
                                Divider().background(Color.white)
                                HStack(spacing: 16) {
                                    Image(systemName: "calendar")
                                    Text("Shiro birthday").font(.headline)
                                    Spacer()
                                    Text("10:00").font(.subheadline)
                                }
                                .frame(width: 354, height: 59)
                                .cornerRadius(12)
                                Divider().background(Color.white)
                            }
                            .foregroundColor(.white)
                            
                            // 任務列表
                            GeometryReader { geometry in
                                ZStack {
                                    HStack(spacing: 0) {
                                        taskList(geometry: geometry)
                                            .frame(width: geometry.size.width)
                                    }
                                    .offset(x: dragOffset)
                                    .gesture(
                                        DragGesture()
                                            .updating($dragOffset) { value, state, _ in
                                                state = value.translation.width
                                            }
                                            .onEnded { value in
                                                let threshold = geometry.size.width * 0.2
                                                let predictedEndTranslation = value.predictedEndTranslation.width
                                                withAnimation(.easeOut) {
                                                    if predictedEndTranslation < -threshold {
                                                        currentDateOffset += 1
                                                    } else if predictedEndTranslation > threshold {
                                                        currentDateOffset -= 1
                                                    }
                                                }
                                            }
                                    )
                                }
                            }
                            .padding(.bottom, bottomPaddingForTaskList)
                            .animation(.easeInOut, value: isCurrentDay)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 24)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 60)
                    .zIndex(1)
                    
                    // 3. 底部灰色容器
                    if !showToDoSheet && !showingDeleteView {
                        HomeBottomView(
                            todoItems: sortedToDoItems,
                            refreshToken: dataRefreshToken,
                            isCurrentDay: isCurrentDay,
                            isSyncing: isSyncing,
                            onEndTodayTapped: {
                                if !isSyncing {
                                    let isSameDaySettlement = delaySettlementManager.isSameDaySettlement(isActiveEndDay: true)
                                    print("用戶點擊結算按鈕，進入結算流程，是否為當天結算 = \(isSameDaySettlement) (主動結算)")
                                    UserDefaults.standard.set(true, forKey: "isActiveEndDay")
                                    LocalDataManager.shared.saveAllChanges()
                                    NotificationCenter.default.post(name: Notification.Name("TodoItemsDataRefreshed"), object: nil)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        let allItems = LocalDataManager.shared.getAllTodoItems()
                                        let filteredItems = allItems.filter { !self.recentlyDeletedItemIDs.contains($0.id) }
                                        if allItems.count != filteredItems.count {
                                            print("結算前過濾了 \(allItems.count - filteredItems.count) 個已刪除項目")
                                            let deletedButStillExistIDs = allItems.filter { self.recentlyDeletedItemIDs.contains($0.id) }.map { $0.id }
                                            for id in deletedButStillExistIDs {
                                                LocalDataManager.shared.deleteTodoItem(withID: id)
                                                print("結算前強制刪除項目 ID: \(id)")
                                            }
                                            self.toDoItems = filteredItems
                                        }
                                        navigateToSettlementView = true
                                    }
                                }
                            },
                            onReturnToTodayTapped: {
                                withAnimation(.easeInOut) {
                                    currentDateOffset = 0
                                    if !isSyncing { loadTodoItems() }
                                }
                            },
                            onAddButtonTapped: {
                                if isCurrentDay {
                                    addTaskMode = .today
                                } else {
                                    addTaskMode = .future
                                }
                                withAnimation(.easeInOut) {
                                    showAddTaskSheet = true
                                }
                            },
                            // === 修改點：傳入新的閉包 ===
                            onTasksReceived: { receivedTasks in
                                self.pendingTasks = receivedTasks
                                if !self.pendingTasks.isEmpty {
                                    // 稍微延遲以獲得更好的動畫效果
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        self.showTaskSelectionOverlay = true
                                    }
                                }
                            },
                            isSleepMode: isSleepMode,
                            alarmTimeString: alarmTimeString,
                            dayProgress: dayProgress,
                            onSleepButtonTapped: {
                                navigateToSleep01View = true
                            }
                        )
                        .zIndex(2)
                    }
                }
                // === 修改點：更新 blur 條件 ===
                .blur(radius: showAddTaskSheet || showingDeleteView || showTaskSelectionOverlay ? 13.5 : 0)

                // 4. ToDoSheetView 彈窗
                if showToDoSheet {
                    GeometryReader { geometry in
                        ZStack(alignment: .top) {
                            Color.black.opacity(0.5)
                                .frame(height: geometry.size.height - 180)
                                .onTapGesture { withAnimation(.easeInOut) { showToDoSheet = false } }
                                .zIndex(9)
                            
                            VStack {
                                Spacer().frame(height: geometry.size.height * 0.15)
                                ToDoSheetView(
                                    toDoItems: $toDoItems,
                                    onDismiss: {
                                        withAnimation(.easeInOut) {
                                            showToDoSheet = false
                                            loadTodoItems()
                                        }
                                    },
                                    onAddButtonPressed: {
                                        addTaskMode = .memo
                                        isFromTodoSheet = true
                                        withAnimation(.easeInOut) {
                                            showAddTaskSheet = true
                                        }
                                    }
                                )
                                .frame(maxHeight: geometry.size.height - 180)
                                Spacer()
                            }
                            .frame(width: geometry.size.width)
                            .zIndex(10)
                        }
                        .blur(radius: showAddTaskSheet ? 13.5 : 0)
                    }
                    .ignoresSafeArea()
                }
                
                // 5. Add.swift 彈出視圖
                if showAddTaskSheet {
                    ZStack {
                        Color.clear.ignoresSafeArea()
                        .onTapGesture { withAnimation(.easeInOut) { showAddTaskSheet = false } }
                        
                        Add(toDoItems: $toDoItems,
                            initialMode: isFromTodoSheet ? .memo : (currentDateOffset == 0 ? .today : .future),
                            currentDateOffset: currentDateOffset,
                            fromTodoSheet: isFromTodoSheet,
                            onClose: {
                            showAddTaskSheet = false
                            addTaskMode = .today
                            isFromTodoSheet = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                loadTodoItems()
                            }
                        })
                        .transition(.move(edge: .bottom))
                    }
                    .animation(.easeInOut(duration: 0.3), value: showAddTaskSheet)
                    .zIndex(100)
                }
                
                // 6. CalendarView 全屏覆蓋
                if showCalendarView {
                    ZStack {
                        Color.black.opacity(0.7).ignoresSafeArea()
                        .onTapGesture { withAnimation(.easeInOut) { showCalendarView = false } }
                        
                        CalendarView(
                            toDoItems: $toDoItems,
                            onDateSelected: { dayOffset in
                                withAnimation(.easeInOut) {
                                    currentDateOffset = dayOffset
                                    showCalendarView = false
                                    loadTodoItems()
                                }
                            },
                            onNavigateToHome: {
                                withAnimation(.easeInOut) { showCalendarView = false }
                                loadTodoItems()
                            }
                        )
                        .transition(.move(edge: .bottom))
                    }
                    .animation(.easeInOut(duration: 0.3), value: showCalendarView)
                    .zIndex(200)
                }
                
                // 7. DeleteItemView 彈出視圖
                if showingDeleteView, let item = selectedItem {
                    ZStack {
                        Color.black.opacity(0.4).ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.easeInOut) {
                                    showingDeleteView = false
                                    selectedItem = nil
                                }
                            }
                            .transition(.opacity)

                        DeleteItemView(
                            itemName: item.title,
                            onCancel: {
                                withAnimation(.easeInOut) {
                                    showingDeleteView = false
                                    selectedItem = nil
                                }
                            },
                            onEdit: {
                                withAnimation(.easeInOut) {
                                    showingDeleteView = false
                                    selectedItem = nil
                                    showingEditSheet = true
                                }
                            },
                            onDelete: {
                                if let itemToDelete = selectedItem {
                                    withAnimation(.easeInOut) {
                                        showingDeleteView = false
                                        selectedItem = nil
                                    }
                                    if let index = toDoItems.firstIndex(where: { $0.id == itemToDelete.id }) {
                                        toDoItems.remove(at: index)
                                    }
                                    let deletedItemID = itemToDelete.id
                                    recentlyDeletedItemIDs.insert(deletedItemID)
                                    LocalDataManager.shared.deleteTodoItem(withID: deletedItemID)
                                    DataSyncManager.shared.deleteTodoItem(withID: deletedItemID) { _ in }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        self.dataRefreshToken = UUID()
                                    }
                                } else {
                                    withAnimation(.easeInOut) {
                                        showingDeleteView = false
                                        selectedItem = nil
                                    }
                                }
                            }
                        )
                        .transition(.move(edge: .bottom))
                    }
                    .animation(.easeInOut(duration: 0.3), value: showingDeleteView)
                    .zIndex(300)
                }
                
                // === 修改點：在 Home 層級顯示 TaskSelectionOverlay ===
                if showTaskSelectionOverlay {
                    TaskSelectionOverlay(
                        tasks: $pendingTasks,
                        onCancel: {
                            withAnimation {
                                self.showTaskSelectionOverlay = false
                            }
                        },
                        onAdd: { itemsToAdd in
                            for item in itemsToAdd {
                                self.dataSyncManager.addTodoItem(item) { result in
                                    switch result {
                                    case .success:
                                        print("成功保存任務: \(item.title)")
                                    case .failure(let error):
                                        print("保存任務失敗: \(error.localizedDescription)")
                                    }
                                }
                            }
                            withAnimation {
                                self.showTaskSelectionOverlay = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.loadTodoItems()
                            }
                        }
                    )
                    .zIndex(500) // 給予最高的層級
                    .transition(.opacity)
                }
            }
            .animation(.easeOut, value: showToDoSheet)
            .animation(.easeOut, value: showAddTaskSheet)
            .animation(.easeOut, value: showCalendarView)
            .animation(.easeOut, value: showingDeleteView)
            .animation(.easeOut, value: showTaskSelectionOverlay) // 為新的 Overlay 也加上動畫
            .navigationBarHidden(true)
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                currentDate = Date()
            }
            loadTodoItems()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                loadTodoItems()
            }
            if delaySettlementManager.shouldShowSettlement() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    let allItems = LocalDataManager.shared.getAllTodoItems()
                    let filteredItems = allItems.filter { !self.recentlyDeletedItemIDs.contains($0.id) }
                    if allItems.count != filteredItems.count {
                        let deletedButStillExistIDs = allItems.filter { self.recentlyDeletedItemIDs.contains($0.id) }.map { $0.id }
                        for id in deletedButStillExistIDs { LocalDataManager.shared.deleteTodoItem(withID: id) }
                        self.toDoItems = filteredItems
                    }
                    navigateToSettlementView = true
                }
            }
            if UserDefaults.standard.bool(forKey: "isSleepMode") {
                isSleepMode = true
                if let savedAlarmTime = UserDefaults.standard.string(forKey: "alarmTimeString") {
                    alarmTimeString = savedAlarmTime
                }
                updateDayProgress(currentTime: Date())
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    updateDayProgress(currentTime: Date())
                }
            } else {
                isSleepMode = false
            }
            setupDataChangeObservers()
        }
        .onReceive(sleepModeTimer) { receivedTime in
            if isSleepMode {
                updateDayProgress(currentTime: receivedTime)
            }
        }
        .onDisappear {
            timer?.invalidate()
            NotificationCenter.default.removeObserver(self)
        }
        .background(
            Group {
                NavigationLink(destination: SettlementView(), isActive: $navigateToSettlementView) { EmptyView() }
                NavigationLink(destination: Sleep01View(), isActive: $navigateToSleep01View) { EmptyView() }
            }
        )
    }
    
    // MARK: - Views
    private func taskList(geometry: GeometryProxy) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if sortedToDoItems.isEmpty {
                    VStack {
                        if isLoading {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.bottom, 20)
                            Text("載入待辦事項中...").foregroundColor(.white.opacity(0.8))
                        } else if let error = loadingError {
                            Image(systemName: "exclamationmark.triangle").foregroundColor(.orange).font(.largeTitle)
                                .padding(.bottom, 10)
                            Text(error).foregroundColor(.white.opacity(0.8)).multilineTextAlignment(.center)
                        } else {
                            Text("這一天沒有事項").foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .frame(height: 200)
                    .frame(width: geometry.size.width)
                    .contentShape(Rectangle())
                } else {
                    ForEach(0..<sortedToDoItems.count, id: \.self) { idx in
                        VStack(spacing: 0) {
                            ItemRow(item: getBindingToSortedItem(at: idx))
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                                .onLongPressGesture {
                                    selectedItem = sortedToDoItems[idx]
                                    showingDeleteView = true
                                }
                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 2)
                        }
                    }
                }
            }
            .background(Color.black)
            .contentShape(Rectangle())
        }
        .scrollIndicators(.hidden)
    }
    
    // MARK: - Functions
    private func updateDayProgress(currentTime: Date) {
        let calendar = self.taipeiCalendar
        let localAlarmStringParser = self.alarmStringParser
        var newProgress = 0.0
        
        guard let parsedAlarmTime = localAlarmStringParser.date(from: alarmTimeString) else {
            self.dayProgress = 0.0
            return
        }
        
        let alarmHourMinuteComponents = calendar.dateComponents([.hour, .minute], from: parsedAlarmTime)
        guard let alarmHour = alarmHourMinuteComponents.hour,
              let alarmMinute = alarmHourMinuteComponents.minute else {
            self.dayProgress = 0.0
            return
        }

        var todayAlarmDateComponents = calendar.dateComponents([.year, .month, .day], from: currentTime)
        todayAlarmDateComponents.hour = alarmHour
        todayAlarmDateComponents.minute = alarmMinute
        todayAlarmDateComponents.second = 0
        
        guard let alarmTimeOnCurrentDay = calendar.date(from: todayAlarmDateComponents) else {
            self.dayProgress = 0.0
            return
        }

        let cycleStart: Date
        let cycleEnd: Date

        guard let tomorrowAlarmTime = calendar.date(byAdding: .day, value: 1, to: alarmTimeOnCurrentDay) else {
            self.dayProgress = 0.0; return
        }
        
        if currentTime < alarmTimeOnCurrentDay {
            guard let yesterdayAlarmTime = calendar.date(byAdding: .day, value: -1, to: alarmTimeOnCurrentDay) else {
                self.dayProgress = 0.0; return
            }
            cycleStart = yesterdayAlarmTime
            cycleEnd = tomorrowAlarmTime
        } else {
            cycleStart = alarmTimeOnCurrentDay
            cycleEnd = tomorrowAlarmTime
        }

        let totalCycleDuration = cycleEnd.timeIntervalSince(cycleStart)
        let elapsedInCycle = currentTime.timeIntervalSince(cycleStart)

        if totalCycleDuration > 0 {
            newProgress = elapsedInCycle / totalCycleDuration
        }
        
        self.dayProgress = min(max(newProgress, 0.0), 1.0)
    }
    
    private func setupDataChangeObservers() {
        NotificationCenter.default.addObserver(forName: Notification.Name("iCloudUserChanged"), object: nil, queue: .main) { _ in
            dataRefreshToken = UUID()
            isSleepMode = false
        }
        NotificationCenter.default.addObserver(forName: Notification.Name("TodoItemStatusChanged"), object: nil, queue: .main) { _ in
            self.dataRefreshToken = UUID()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.loadTodoItems()
            }
        }
        NotificationCenter.default.addObserver(forName: Notification.Name("TodoItemsDataRefreshed"), object: nil, queue: .main) { _ in
            loadTodoItems()
        }
        NotificationCenter.default.addObserver(forName: Notification.Name("CompletedDaysDataChanged"), object: nil, queue: .main) { _ in
            dataRefreshToken = UUID()
        }
    }
    
    private func performManualSync() {
        guard !isSyncing else { return }
        isSyncing = true
        dataSyncManager.performSync { result in
            DispatchQueue.main.async {
                isSyncing = false
                switch result {
                case .success(let syncCount):
                    print("手動同步完成! 同步了 \(syncCount) 個項目")
                    loadTodoItems()
                case .failure(let error):
                    print("手動同步失敗: \(error.localizedDescription)")
                    loadingError = "同步失敗: \(error.localizedDescription)"
                    loadTodoItems()
                }
            }
        }
    }
    
    private func loadTodoItems() {
        isLoading = true
        loadingError = nil
        dataSyncManager.fetchTodoItems { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let items):
                    self.isLoading = false
                    let filteredItems = items.filter { !self.recentlyDeletedItemIDs.contains($0.id) }
                    self.toDoItems = filteredItems
                case .failure(let error):
                    self.isLoading = false
                    self.loadingError = "載入失敗: \(error.localizedDescription)"
                    let localItems = LocalDataManager.shared.getAllTodoItems()
                    self.toDoItems = localItems.filter { !self.recentlyDeletedItemIDs.contains($0.id) }
                }
            }
        }
    }
}

// MARK: - Extensions
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - Preview
#Preview {
    Home()
}
