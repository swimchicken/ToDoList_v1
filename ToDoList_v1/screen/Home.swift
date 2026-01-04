import SwiftUI
import SpriteKit
import CloudKit

struct Home: View {
    @EnvironmentObject var alarmStateManager: AlarmStateManager
    @State private var showCalendarView: Bool = false
    @State private var updateStatus: String = ""
    @State private var showToDoSheet: Bool = false
    @State private var showAddTaskSheet: Bool = false
    @State private var currentDate: Date = Date()  // 添加當前時間狀態
    @State private var navigateToSettlementView: Bool = false // 導航到結算頁面
    @State private var navigateToSleep01View: Bool = false // 導航到Sleep01視圖
    @State private var navigateToTestPage: Bool = false
    @State private var navigationViewID = UUID()
    @State private var isSleepMode: Bool = false // 睡眠模式狀態
    @State private var alarmTimeString: String = "9:00 AM" // 鬧鐘時間，默認為9:00 AM
    @State private var dayProgress: Double = 0.0 // 與Sleep01相同，用來顯示進度條
    @State private var taskToEdit: TodoItem?
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    
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
    @State private var editingItem: TodoItem? = nil
    
    // 沒有事件提示彈窗狀態
    @State private var showNoEventsAlert: Bool = false
    @State private var showProfileSidebar: Bool = false
    
    // === 修改點：新增 State ===
    // 將 TaskSelectionOverlay 的狀態從 HomeBottomView 提升至此處
    @State private var showTaskSelectionOverlay: Bool = false
    @State private var pendingTasks: [TodoItem] = []
    
    
    // 添加水平滑動狀態
    @State private var currentDateOffset: Int = 0 // 日期偏移量
    @GestureState private var dragOffset: CGFloat = 0 // 拖動偏移量（保留用於過渡期間）
    
    // 新增：用於 ScrollView 的狀態變數
    @State private var scrollDateOffsets: [Int] = [-2, -1, 0, 1, 2] // 預載入的日期偏移範圍
    @State private var scrollPosition: Int? = 0 // 當前 ScrollView 位置，對應 currentDateOffset
    @State private var isScrolling: Bool = false // 追蹤是否正在滑動

    // 批次更新相關 - 移除，使用單一系統
    
    // 創建一個計算屬性來橋接 currentDateOffset 到 scrollPosition
    private var scrollablePosition: Binding<Int?> {
        Binding<Int?>(
            get: {
                return self.currentDateOffset
            },
            set: { newOffset in
                if let newOffset = newOffset, self.currentDateOffset != newOffset {
                    self.currentDateOffset = newOffset
                    // 動態擴展滾動範圍
                    self.expandScrollRangeIfNeeded(for: newOffset)
                }
            }
        )
    }
    
    // API 數據管理器 - 處理 API 伺服器調用
    private let apiDataManager = APIDataManager.shared
    
    // 已完成日期數據管理器 - 追蹤已完成的日期
    private let completeDayDataManager = CompleteDayDataManager.shared
    
    // 延遲結算管理器 - 處理結算顯示和時間追蹤
    private let delaySettlementManager = DelaySettlementManager.shared
    
    // 修改後的taiwanTime，基於currentDate和日期偏移量
    var taiwanTime: (monthDay: String, weekday: String, timeStatus: String) {
        let currentDateWithOffset = taipeiCalendar.date(byAdding: .day, value: currentDateOffset, to: currentDate) ?? currentDate

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
    
    // MARK: - ADDED: 新增一個計算屬性來獲取當前選擇的日期
    private var selectedDate: Date {
        taipeiCalendar.date(byAdding: .day, value: currentDateOffset, to: currentDate) ?? currentDate
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
        let dateWithOffset = taipeiCalendar.date(byAdding: .day, value: currentDateOffset, to: currentDate) ?? currentDate
        return completeDayDataManager.isDayCompleted(date: dateWithOffset)
    }
    
    // 計算屬性：篩選並排序當前日期的待辦事項
    private var sortedToDoItems: [TodoItem] {
        // 獲取帶偏移量的日期
        let dateWithOffset = taipeiCalendar.date(byAdding: .day, value: currentDateOffset, to: currentDate) ?? currentDate

        // 獲取篩選日期的開始和結束時間點
        let calendar = taipeiCalendar
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
                // ✅ 增強樂觀更新：如果數據模型被更新，立即更新本地狀態並同步到API
                if let index = self.toDoItems.firstIndex(where: { $0.id == newValue.id }) {
                    let originalValue = self.toDoItems[index]  // 保存原始值以便回滾

                    // 1. 立即樂觀更新本地狀態
                    self.toDoItems[index] = newValue

                    // 2. 在背景使用 API 伺服器更新項目
                    Task {
                        do {
                            let updatedItem = try await self.apiDataManager.updateTodoItem(newValue)
                            await MainActor.run {
                                // 3. 用API返回的實際數據替換樂觀更新的數據
                                if let currentIndex = self.toDoItems.firstIndex(where: { $0.id == newValue.id }) {
                                    self.toDoItems[currentIndex] = updatedItem
                                }
                            }
                        } catch {
                            await MainActor.run {
                                // 4. 回滾樂觀更新：恢復原始值
                                if let currentIndex = self.toDoItems.firstIndex(where: { $0.id == newValue.id }) {
                                    self.toDoItems[currentIndex] = originalValue
                                }

                                // 5. 顯示錯誤提示
                                self.toastMessage = "更新失敗: \(error.localizedDescription)"
                                withAnimation {
                                    self.showToast = true
                                }
                            }
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
        return isCurrentDay ? 190 : 90
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 1. 背景
                Color.black
                    .ignoresSafeArea()
                
                // 2. 主介面內容 (會被模糊)
                ZStack{
                // 2. 主介面內容
                VStack(spacing: 0) {
                    // Header - 使用台灣時間
                    VStack(spacing: 0) {
                        UserInfoView(
                            avatarImageName: "who",
                            dateText: taiwanTime.monthDay,
                            dateText2: taiwanTime.weekday,
                            statusText: taiwanTime.timeStatus,
                            temperatureText: "26°C",
                            showCalendarView: $showCalendarView,
                            onAvatarTapped: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showProfileSidebar = true
                                }
                            }
                        )
                        .frame(maxWidth: .infinity, maxHeight: 0)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        // 待辦事項佇列按鈕
                        HStack {
                            Button {

                                // 正確的方式：直接使用 Calendar.startOfDay 但確保使用正確的時區
                                // 先將 currentDate 轉換為台灣時間的組件，然後重新構建為該天的開始
                                let taipeiTimeZone = TimeZone(identifier: "Asia/Taipei")!
                                var calendar = Calendar.current
                                calendar.timeZone = taipeiTimeZone

                                // 獲取台灣時間的今天開始
                                let today = calendar.startOfDay(for: currentDate)

                                // 計算顯示日期：先加上偏移量，再獲取那一天的開始
                                let offsetDate = calendar.date(byAdding: .day, value: currentDateOffset, to: currentDate) ?? currentDate
                                let displayedDayStart = calendar.startOfDay(for: offsetDate)


                                let systemToday = Calendar.current.startOfDay(for: currentDate)

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
                        .padding(.top, 30)
                        .padding(.horizontal, 8)
                        
                        horizontalScrollView()
                        .padding(.bottom, bottomPaddingForTaskList)
                        .animation(.easeInOut, value: isCurrentDay)
                    }
                    .padding(.horizontal, 0)
                    .padding(.vertical, 24)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 30)
                .zIndex(1) // 設置主界面内容的層級
                
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
                                UserDefaults.standard.set(true, forKey: "isActiveEndDay")
                                // 🔧 移除不必要的數據重新拉取
                                // 結束一天的操作不需要重新拉取所有數據
                                // API 數據管理器不需要手動保存，所有操作都是即時的

                                // 🔧 也移除 TodoItemsDataRefreshed 通知，避免觸發其他重新載入
                                // NotificationCenter.default.post(
                                //     name: Notification.Name("TodoItemsDataRefreshed"),
                                //     object: nil
                                // )

                                // 直接使用當前的 toDoItems 數據進行檢查，不需要重新拉取
                                let today = currentDate
                                let calendar = taipeiCalendar
                                let startOfToday = calendar.startOfDay(for: today)
                                let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!

                                // 過濾今天的項目（有日期且在今天範圍內）
                                let todayItems = toDoItems.filter { item in
                                    // 只包含有日期且在今天的項目
                                    guard let taskDate = item.taskDate else {
                                        return false
                                    }

                                    let isToday = taskDate >= startOfToday && taskDate < endOfToday
                                    return isToday
                                }


                                // 檢查今天是否有事件
                                if todayItems.isEmpty {
                                    showNoEventsAlert = true
                                } else {
                                    // 【修改點】直接設置為 true 即可，不再需要延遲或重置
                                    self.navigateToSettlementView = true
                                }
                            }
                        },
                        onReturnToTodayTapped: {
                            withAnimation(.easeInOut) {
                                currentDateOffset = 0
                                if !isSyncing {loadTodoItems()}
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
                        onError: { errorMessage in
                            self.toastMessage = errorMessage
                            withAnimation {
                                self.showToast = true
                            }
                        },
                        // MARK: - MODIFIED: 修改 onTasksReceived 閉包以設定正確的日期
                        onTasksReceived: { receivedTasks in
                            // 遍歷收到的任務，並將它們的日期設定為當前選擇的日期
                            let tasksWithCorrectDate = receivedTasks.map { task -> TodoItem in
                                var modifiedTask = task
                                // 只有當 AI 沒有提供日期時，才設定為當前日期
                                if modifiedTask.taskDate == nil {
                                    modifiedTask.taskDate = self.selectedDate
                                }
                                return modifiedTask
                            }

                            // 📝 新增：立即實現樂觀更新
                            withAnimation(.easeInOut(duration: 0.3)) {
                                for task in tasksWithCorrectDate {
                                    self.toDoItems.append(task)
                                }
                            }

                            self.pendingTasks = tasksWithCorrectDate

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

                            // 先重置為 false，然後再設為 true 以確保觸發導航
                            if navigateToSleep01View {
                                navigateToSleep01View = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    navigateToSleep01View = true
                                }
                            } else {
                                navigateToSleep01View = true
                            }
                        }
                    )
                    .zIndex(2)
                }
                
            }
            .blur(radius: showAddTaskSheet || showingDeleteView || showTaskSelectionOverlay || taskToEdit != nil || showNoEventsAlert || showProfileSidebar ? 13.5 : 0)

            //錯誤訊息
            if showToast {
                VStack {
                    Spacer() // 將 Toast 推至底部
                    ErrorToastView(message: toastMessage)
                        .onAppear {
                            // 讓 Toast 在 3 秒後自動消失
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation {
                                    showToast = false
                                }
                            }
                        }
                    Spacer().frame(height: 100) // 距離底部的距離
                }
                .transition(.opacity)
                .zIndex(999) // 確保在最上層
            }
            
            // 4. ToDoSheetView 彈窗 - 僅覆蓋部分屏幕而非整個屏幕
            if showToDoSheet {
                GeometryReader { geometry in
                    ZStack(alignment: .top) {
                        Color.black.opacity(0.5)
                            .frame(height: geometry.size.height - 180)
                            .onTapGesture {
                                withAnimation(.easeInOut) { showToDoSheet = false }
                            }
                            .zIndex(9)
                        
                        VStack {
                            Spacer().frame(height: geometry.size.height * 0.15)
                            ToDoSheetView(
                                toDoItems: $toDoItems,
                                onDismiss: {
                                    withAnimation(.easeInOut) {
                                        showToDoSheet = false
                                        // 移除不必要的 API 調用：編輯操作已有樂觀更新
                                    }
                                },
                                onAddButtonPressed: {
                                    addTaskMode = .memo
                                    isFromTodoSheet = true
                                    withAnimation(.easeInOut) {
                                        showAddTaskSheet = true
                                    }
                                },
                                onOptimisticAdd: { newItem in
                                    // 立即在 toDoItems 中添加新任務，提供即時反饋
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        toDoItems.append(newItem)
                                    }
                                },
                                onReplaceOptimistic: { tempId, realItem in
                                    // 替換或移除樂觀添加的項目
                                    if let index = toDoItems.firstIndex(where: { $0.id == tempId }) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if realItem.correspondingImageID == "REMOVE" {
                                                // 移除失敗的樂觀更新項目
                                                toDoItems.remove(at: index)
                                            } else {
                                                // 替換為真實項目
                                                toDoItems[index] = realItem
                                            }
                                        }
                                    }
                                },
                                selectedDate: selectedDate
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
            
            // 5. 添加 Add.swift 彈出視圖
            if showAddTaskSheet {
                ZStack {
                    Color.clear.ignoresSafeArea()
                    .onTapGesture { withAnimation(.easeInOut) { showAddTaskSheet = false } }
                    
                    // MARK: - MODIFIED: 向 Add 視圖傳遞 initialDate
                    Add(toDoItems: $toDoItems,
                        initialMode: isFromTodoSheet ? .memo : (currentDateOffset == 0 ? .today : .future),
                        initialDate: selectedDate, // 傳遞計算好的日期
                        fromTodoSheet: isFromTodoSheet,
                        editingItem: editingItem,
                        onClose: {
                        showAddTaskSheet = false
                        addTaskMode = .today
                        isFromTodoSheet = false
                        editingItem = nil
                        // 移除不必要的 API 調用：新增操作已有樂觀更新
                    },
                        onOptimisticAdd: { newItem in
                        // 樂觀更新：立即顯示新任務
                        showAddTaskSheet = false
                        addTaskMode = .today
                        isFromTodoSheet = false
                        editingItem = nil

                        // 立即添加到本地列表
                        toDoItems.append(newItem)
                    })
                    .transition(.move(edge: .bottom))
                }
                .animation(.easeInOut(duration: 0.3), value: showAddTaskSheet)
                .zIndex(100)
            }
            
            // 6. 新增: CalendarView 全屏覆蓋
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
            
            // 7. 新增: DeleteItemView 彈出視圖
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
                                editingItem = selectedItem
                                selectedItem = nil
                                showAddTaskSheet = true
                            }
                        },
                        onDelete: {
                            if let itemToDelete = selectedItem {
                                withAnimation(.easeInOut) {
                                    showingDeleteView = false
                                    selectedItem = nil
                                }

                                // 🔧 修復：從當前toDoItems中查找最新的項目（可能已被樂觀更新）
                                // 先嘗試用title匹配，因為ID可能已經更新
                                let currentItem = toDoItems.first { item in
                                    item.title == itemToDelete.title &&
                                    item.taskDate == itemToDelete.taskDate
                                } ?? itemToDelete

                                let deletedItemID = currentItem.id
                                let deletedItem = currentItem // 使用最新的項目信息


                                withAnimation(.easeInOut(duration: 0.3)) {
                                    toDoItems.removeAll { $0.id == deletedItemID }
                                }

                                Task {
                                    do {
                                        try await apiDataManager.deleteTodoItem(withID: deletedItemID)
                                    } catch {
                                        await MainActor.run {
                                            // 回滾樂觀更新：重新添加項目
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                // 按照原來的位置重新插入（或添加到末尾）
                                                toDoItems.append(deletedItem)
                                                // 可以考慮按創建時間重新排序
                                                toDoItems.sort { $0.createdAt < $1.createdAt }
                                            }
                                        }
                                    }
                                }
                            } else {
                                withAnimation(.easeInOut) {
                                    showingDeleteView = false
                                    selectedItem = nil
                                }
                            }
                        },
                        onMoveToQueue: {
                            if let itemToMove = selectedItem {
                                withAnimation(.easeInOut) {
                                    showingDeleteView = false
                                    selectedItem = nil
                                }

                                // 🔧 修復：從當前toDoItems中查找最新的項目（可能已被樂觀更新）
                                let currentItem = toDoItems.first { item in
                                    item.title == itemToMove.title &&
                                    item.taskDate == itemToMove.taskDate
                                } ?? itemToMove


                                // 創建新的待辦項目（移除時間，變成未完成任務）
                                let queueItem = TodoItem(
                                    id: UUID(),
                                    userID: currentItem.userID,
                                    title: currentItem.title,
                                    priority: currentItem.priority,
                                    isPinned: currentItem.isPinned,
                                    taskDate: nil, // 移除日期時間
                                    note: currentItem.note,
                                    taskType: .uncompleted, // 🆕 設定為未完成類型
                                    completionStatus: .pending, // 🆕 設定為待完成狀態
                                    status: .undone, // 🔄 向後兼容：未完成任務
                                    createdAt: Date(),
                                    updatedAt: Date(),
                                    correspondingImageID: currentItem.correspondingImageID
                                )

                                // 樂觀更新：立即移除原項目，添加隊列項目
                                let movedItemID = currentItem.id
                                let originalItem = currentItem // 保存副本以便回滾

                                withAnimation(.easeInOut(duration: 0.3)) {
                                    // 移除原項目
                                    toDoItems.removeAll { $0.id == movedItemID }
                                    // 添加到佇列項目（如果當前視圖包含佇列項目）
                                    toDoItems.append(queueItem)
                                }

                                Task {
                                    do {
                                        // 1. 先新增佇列項目
                                        let newQueueItem = try await apiDataManager.addTodoItem(queueItem)

                                        // 2. 再刪除原項目
                                        try await apiDataManager.deleteTodoItem(withID: movedItemID)

                                        await MainActor.run {
                                            // 更新樂觀添加的項目為實際API返回的項目
                                            if let index = toDoItems.firstIndex(where: { $0.id == queueItem.id }) {
                                                toDoItems[index] = newQueueItem
                                            }
                                        }
                                    } catch {
                                        await MainActor.run {
                                            // 回滾樂觀更新
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                // 移除樂觀添加的佇列項目
                                                toDoItems.removeAll { $0.id == queueItem.id }
                                                // 恢復原項目
                                                toDoItems.append(originalItem)
                                                toDoItems.sort { $0.createdAt < $1.createdAt }
                                            }
                                        }
                                    }
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
            
            //第三步：新增 TaskEditView 的顯示邏輯
            if let taskToEdit = self.taskToEdit,
               let taskIndex = self.pendingTasks.firstIndex(where: { $0.id == taskToEdit.id }) {
                
                TaskEditView(task: $pendingTasks[taskIndex], onClose: {
                    // 交接結束：命令 TaskEditView 消失，並重新顯示 TaskSelectionOverlay
                    self.taskToEdit = nil
                    // 稍微延遲讓動畫更流暢
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.showTaskSelectionOverlay = true
                    }
                })
                .zIndex(600) // 給予比 TaskSelectionOverlay 更高的層級
                .transition(.opacity.animation(.easeInOut))
            }
            
            // === 修改點：在 Home 層級顯示 TaskSelectionOverlay ===
            if showTaskSelectionOverlay {
                TaskSelectionOverlay(
                    tasks: $pendingTasks,
                    onCancel: {
                        // 📝 修改：回滾樂觀更新，移除之前添加的任務
                        withAnimation(.easeInOut(duration: 0.3)) {
                            for task in pendingTasks {
                                self.toDoItems.removeAll { $0.id == task.id }
                            }
                            self.showTaskSelectionOverlay = false
                        }
                    },
                    onAdd: { itemsToAdd in
                        // 📝 修改：處理部分選擇的情況
                        // 1. 首先移除所有樂觀添加的任務
                        withAnimation(.easeInOut(duration: 0.3)) {
                            for task in pendingTasks {
                                self.toDoItems.removeAll { $0.id == task.id }
                            }
                        }

                        // 2. 只保留用戶選擇的任務（立即樂觀更新）
                        withAnimation(.easeInOut(duration: 0.3)) {
                            for item in itemsToAdd {
                                self.toDoItems.append(item)
                            }
                        }

                        // 3. 異步保存到 API
                        Task {
                            for item in itemsToAdd {
                                do {
                                    let savedItem = try await self.apiDataManager.addTodoItem(item)
                                    // 4. 用 API 返回的實際數據替換樂觀更新的數據
                                    DispatchQueue.main.async {
                                        if let index = self.toDoItems.firstIndex(where: { $0.id == item.id }) {
                                            self.toDoItems[index] = savedItem
                                        }
                                    }
                                } catch {
                                    // 5. API 失敗時回滾對應的樂觀更新
                                    DispatchQueue.main.async {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            self.toDoItems.removeAll { $0.id == item.id }
                                        }
                                    }
                                }
                            }
                        }
                        withAnimation {
                            self.showTaskSelectionOverlay = false
                        }
                    },
                    onEditTask: { task in
                        // 交接開始：命令 TaskSelectionOverlay 消失，並設定要編輯的任務
                        self.showTaskSelectionOverlay = false
                        self.taskToEdit = task
                    }
                )
                .zIndex(500) // 給予最高的層級
                .transition(.opacity)
            }
            
            // 8. 沒有事件提示彈窗
            if showNoEventsAlert {
                ZStack {
                    Color.black.opacity(0.5).ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut) {
                                showNoEventsAlert = false
                            }
                        }
                        .transition(.opacity)

                    VStack(spacing: 20) {
                        // 圖標
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        // 標題
                        Text("沒有事件清單")
                            .font(.custom("Instrument Sans", size: 24).weight(.bold))
                            .foregroundColor(.white)
                        
                        // 說明文字
                        Text("目前沒有任何待辦事項需要結算")
                            .font(.custom("Instrument Sans", size: 16))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                        
                        // 確認按鈕
                        Button(action: {
                            withAnimation(.easeInOut) {
                                showNoEventsAlert = false
                            }
                        }) {
                            Text("知道了")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(width: 120, height: 45)
                                .background(Color.white)
                                .cornerRadius(22.5)
                        }
                    }
                    .padding(30)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.gray.opacity(0.95))
                    )
                    .transition(.scale.combined(with: .opacity))
                }
                .animation(.easeInOut(duration: 0.3), value: showNoEventsAlert)
                .zIndex(600)
            }
            // 🆕 側邊欄 - 添加在這裡
            if showProfileSidebar {
                ProfileSidebarView(isPresented: $showProfileSidebar)
                    .zIndex(1000)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $navigateToSettlementView) {
            SettlementView(allItems: self.toDoItems)
                .onAppear {
                }
                .onDisappear {
                    // 內容已清空，由樂觀更新處理
                }
        }
        .navigationDestination(isPresented: $navigateToSleep01View) {
            Sleep01View()
                .onAppear {
                }
                .onDisappear {
                    // 當從 Sleep01 返回時，重置導航狀態並重新載入數據
                    navigateToSleep01View = false
                    // 重新載入事件數據，反映結算時的所有變更
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        loadTodoItems()
                    }
                }
        }
        .navigationDestination(isPresented: $navigateToTestPage) {
            TestPage()
        }

        .animation(.easeOut, value: showToDoSheet)
        .animation(.easeOut, value: showAddTaskSheet)
        .animation(.easeOut, value: showCalendarView)
        .animation(.easeOut, value: showingDeleteView)
        .animation(.easeOut, value: showTaskSelectionOverlay) // 為新的 Overlay 也加上動畫
        .animation(.easeOut, value: showNoEventsAlert) // 為沒有事件提示彈窗加上動畫
    }
    .onAppear {
        // 確保 currentDate 是最新的
        currentDate = Date()

        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            currentDate = Date()
        }
        loadTodoItems()
        // 移除重複的 API 調用：0.5 秒內載入兩次是不必要的
        // 移除重複的結算檢查邏輯，由 ContentView 統一處理
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
        // 移除批次更新處理
        NotificationCenter.default.removeObserver(self)
    }
    .background(
        Group {
            NavigationLink(destination:
                SettlementView()
                    .onAppear {
                    }
                    .onDisappear {
                        // 當 SettlementView 消失時，重置導航狀態並重新載入數據
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            navigateToSettlementView = false
                            loadTodoItems()
                        }
                    }
                , isActive: $navigateToSettlementView) {
                EmptyView()
            }
            .onChange(of: navigateToSettlementView) { newValue in
            }
            // 移除舊式 NavigationLink，只使用新的 navigationDestination
        }
    )
}
    
    // 動態擴展滾動範圍
    private func expandScrollRangeIfNeeded(for offset: Int) {
        let buffer = 2 // 保持前後各2天的緩衝
        let minOffset = offset - buffer
        let maxOffset = offset + buffer
        
        // 擴展到最小值
        while scrollDateOffsets.min() ?? 0 > minOffset {
            let newMin = (scrollDateOffsets.min() ?? 0) - 1
            scrollDateOffsets.insert(newMin, at: 0)
        }
        
        // 擴展到最大值
        while scrollDateOffsets.max() ?? 0 < maxOffset {
            let newMax = (scrollDateOffsets.max() ?? 0) + 1
            scrollDateOffsets.append(newMax)
        }
    }
    
    // 檢查當前顯示日期是否為節日（兼容性函數）
    private func getHolidayInfo() -> (isHoliday: Bool, name: String, time: String)? {
        return getHolidayInfo(for: currentDateOffset)
    }
    
    // 為特定日期偏移量生成 taskList
    private func taskList(for dateOffset: Int, geometry: GeometryProxy) -> some View {
        let filteredItems = getFilteredToDoItems(for: dateOffset)
        let holidayInfo = getHolidayInfo(for: dateOffset)
        
        return VStack(spacing: 0) {
            // 頂部 Divider 永遠存在
            Divider().background(Color.white)
            
            // 滾動內容
            ScrollView {
                LazyVStack(spacing: 0) {
                    // 節日區塊 - 如果當天是節日則顯示在列表最上方
                    if let holidayInfo = holidayInfo {
                        VStack(spacing: 0) {
                            HStack(spacing: 16) {
                                Image(systemName: "calendar")
                                Text(holidayInfo.name).font(.headline)
                                Spacer()
                                Text(holidayInfo.time).font(.subheadline)
                            }
                            .frame(width: 354, height: 59)
                            .cornerRadius(12)
                            Divider().background(Color.white)
                        }
                        .foregroundColor(.white)
                        .padding(.bottom, 10)
                    }
                    
                    if filteredItems.isEmpty {
                        // 無事項時顯示占位符或載入中訊息，但仍可以滑動
                        VStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                                    .padding(.bottom, 20)
                                
                                Text("載入待辦事項中...")
                                    .foregroundColor(.white.opacity(0.8))
                            } else if let error = loadingError {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                    .font(.largeTitle)
                                    .padding(.bottom, 10)
                                Text(error)
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                            } else {
                                Text("這一天沒有事項")
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .frame(height: 200)
                        .frame(width: geometry.size.width)
                        .contentShape(Rectangle()) // 使空白區域也可接收手勢
                    } else {
                        ForEach(0..<filteredItems.count, id: \.self) { idx in
                            VStack(spacing: 0) {
                                ItemRow(item: getBindingToFilteredItem(filteredItems[idx]))
                                    .padding(.vertical, 8)
                                    .contentShape(Rectangle()) // 确保整行可点击
                                    .onLongPressGesture {
                                        // 长按时显示编辑/删除选项
                                        selectedItem = filteredItems[idx]
                                        showingDeleteView = true
                                    }
                                Rectangle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 2)
                            }
                        }
                    }
                }
                .background(Color.clear)
                .contentShape(Rectangle()) // 使整個區域可接收手勢，即使項目很少
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 8) // 20 - 12 = 8pt
        .padding(.top, 8)
    }
    
    // 保留原有的 taskList 函數作為兼容性函數
    private func taskList(geometry: GeometryProxy) -> some View {
        return taskList(for: currentDateOffset, geometry: geometry)
    }
    
    // 獲取特定日期偏移量的過濾項目
    private func getFilteredToDoItems(for dateOffset: Int) -> [TodoItem] {
        let dateWithOffset = taipeiCalendar.date(byAdding: .day, value: dateOffset, to: currentDate) ?? currentDate

        // 獲取篩選日期的開始和結束時間點
        let calendar = taipeiCalendar
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
        return filteredItems.sorted { (item1: TodoItem, item2: TodoItem) -> Bool in
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
            
            // 最後按任務日期排序
            guard let date1 = item1.taskDate, let date2 = item2.taskDate else {
                return false
            }
            return date1 < date2
        }
    }
    
    // 為過濾項目創建綁定
    private func getBindingToFilteredItem(_ item: TodoItem) -> Binding<TodoItem> {
        if let originalIndex = toDoItems.firstIndex(where: { $0.id == item.id }) {
            return $toDoItems[originalIndex]
        }
        // 如果找不到原始項目，創建一個臨時綁定
        return .constant(item)
    }
    
    // 水平滑動 ScrollView 組件
    private func horizontalScrollView() -> some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(scrollDateOffsets, id: \.self) { dateOffset in
                            taskListWithBackground(for: dateOffset, geometry: geometry)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: scrollablePosition)
                .onChange(of: dragOffset) { _, newValue in
                    let isDragging = abs(newValue) > 5
                    if isScrolling != isDragging {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isScrolling = isDragging
                        }
                    }
                }
                .simultaneousGesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation.width
                        }
                )
                .onAppear {
                    DispatchQueue.main.async {
                        proxy.scrollTo(currentDateOffset, anchor: .center)
                    }
                }
                .onChange(of: showToDoSheet) { isShowing in
                    // 當ToDoSheet狀態改變時，確保ScrollView位置正確
                    if !isShowing { // 當ToDoSheet關閉時
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            proxy.scrollTo(currentDateOffset, anchor: .center)
                        }
                    }
                }
            }
        }
    }
    
    // 帶背景的 taskList 組件
    private func taskListWithBackground(for dateOffset: Int, geometry: GeometryProxy) -> some View {
        taskList(for: dateOffset, geometry: geometry)
            .frame(width: geometry.size.width)
            .background(
                RoundedRectangle(cornerRadius: 11)
                    .fill(isScrolling ? Color(hex: "141414") : Color.clear)
//                  .fill(isScrolling ? Color.gray.opacity(0.3) : Color.blue.opacity(0.2))
                    .animation(.easeInOut(duration: 0.3), value: isScrolling)
            )
            .id(dateOffset)
            .onAppear {
                expandScrollRangeIfNeeded(for: dateOffset)
            }
    }
    
    // 為特定日期偏移量檢查節日
    private func getHolidayInfo(for dateOffset: Int) -> (isHoliday: Bool, name: String, time: String)? {
        let dateWithOffset = taipeiCalendar.date(byAdding: .day, value: dateOffset, to: currentDate) ?? currentDate
        let calendar = taipeiCalendar
        
        // 檢查是否為生日（8/22）
        let dateComponents = calendar.dateComponents([.month, .day], from: dateWithOffset)
        if dateComponents.month == 8 && dateComponents.day == 22 {
            return (isHoliday: true, name: "Shiro birthday", time: "10:00")
        }
        
        // 這裡可以添加其他節日檢查
        // 例如：聖誕節、新年等
        
        return nil
    }
    
    
 // MARK: - Functions

    private func applySettlementUpdates() {
        let operations = SettlementStateManager.shared.completedOperations
        let movedItems = SettlementStateManager.shared.movedItems
        guard !operations.isEmpty || !movedItems.isEmpty else { return }

        print("🏠 Home: Applying optimistic updates. Operations: \(operations.count), Moved: \(movedItems.count).")

        var updatedItems = self.toDoItems

        // 處理增、刪、改操作
        for operation in operations {
            switch operation {
            case .addItem(let item):
                updatedItems.append(item)
                print("    ➕ Added: \(item.title)")
            case .deleteItem(let id):
                if let index = updatedItems.firstIndex(where: { $0.id == id }) {
                    let removed = updatedItems.remove(at: index)
                    print("    ➖ Deleted: \(removed.title)")
                }
            case .updateItem(let item):
                if let index = updatedItems.firstIndex(where: { $0.id == item.id }) {
                    updatedItems[index] = item
                    print("    🔄 Updated: \(item.title)")
                }
            }
        }
        
        // 處理被移動到明日的任務
        for item in movedItems {
            if let index = updatedItems.firstIndex(where: { $0.id == item.id }) {
                updatedItems[index] = item
                print("    ➡️ Moved to tomorrow: \(item.title)")
            }
        }

        self.toDoItems = updatedItems
        
        // 清空已應用的操作，以防下次誤用
        SettlementStateManager.shared.completedOperations = []
        SettlementStateManager.shared.movedItems = []
    }

    private func updateDayProgress(currentTime: Date) {
        // 統一進度條邏輯：使用與AlarmStateManager相同的邏輯
        // 直接同步AlarmStateManager的sleepProgress
        self.dayProgress = alarmStateManager.sleepProgress
    }
    
    private func setupDataChangeObservers() {
        NotificationCenter.default.addObserver(forName: Notification.Name("iCloudUserChanged"), object: nil, queue: .main) { _ in
            dataRefreshToken = UUID()
            isSleepMode = false
        }
        NotificationCenter.default.addObserver(forName: Notification.Name("TodoItemStatusChanged"), object: nil, queue: .main) { _ in
            // 🔧 移除自動的 dataRefreshToken 更新，減少球球 UI 閃爍
            // 球球場景現在基於真實數據變化而不是 refreshToken 來決定是否重建
            // self.dataRefreshToken = UUID() // 註釋掉避免不必要的重建

            // 只在必要時更新 refreshToken（例如項目數量變化）
            // 狀態變更會通過 SwiftUI 的數據綁定自動反映到球球中
        }
        // 🔧 暫時停用 TodoItemsDataRefreshed 監聽，避免干擾樂觀更新
        // 只有在非樂觀更新場景下才需要重新載入數據
        // NotificationCenter.default.addObserver(forName: Notification.Name("TodoItemsDataRefreshed"), object: nil, queue: .main) { _ in
        //     loadTodoItems()
        // }

        // 監聽 API 同步完成
        NotificationCenter.default.addObserver(forName: Notification.Name("TodoItemApiSyncCompleted"), object: nil, queue: .main) { notification in
            if let userInfo = notification.userInfo,
               let newItem = userInfo["item"] as? TodoItem,
               let operation = userInfo["operation"] as? String,
               let tempId = userInfo["tempId"] as? UUID {

                if operation == "add" {
                    // 使用臨時ID找到樂觀更新的項目，並更新為實際 API 返回的數據
                    if let index = toDoItems.firstIndex(where: { $0.id == tempId }) {
                        toDoItems[index] = newItem
                    }
                }
            }
        }

        // 監聽樂觀更新失敗
        NotificationCenter.default.addObserver(forName: Notification.Name("TodoItemOptimisticUpdateFailed"), object: nil, queue: .main) { notification in
            if let userInfo = notification.userInfo,
               let operation = userInfo["operation"] as? String,
               let error = userInfo["error"] as? String {

                if operation == "add" {
                    // 🔧 修復：支援 tempId (來自Add) 和 homeItemId (來自箭頭按鈕)
                    if let tempId = userInfo["tempId"] as? UUID {
                        // 移除失敗的樂觀更新項目 (來自Add)
                        toDoItems.removeAll { $0.id == tempId }
                    } else if let homeItemId = userInfo["homeItemId"] as? UUID {
                        // 移除失敗的樂觀更新項目 (來自箭頭按鈕)
                        toDoItems.removeAll { $0.id == homeItemId }
                    }

                    // 顯示錯誤提示
                    toastMessage = "保存失敗: \(error)"
                    withAnimation {
                        showToast = true
                    }
                }
            }
        }
        // 監聽項目更新失敗通知
        NotificationCenter.default.addObserver(forName: Notification.Name("TodoItemUpdateFailed"), object: nil, queue: .main) { notification in
            if let userInfo = notification.userInfo,
               let errorMessage = userInfo["error"] as? String {
                // 顯示錯誤提示
                toastMessage = "更新失敗: \(errorMessage)"
                withAnimation {
                    showToast = true
                }
            }
        }

        // 監聽項目添加失敗通知（樂觀更新回滾）
        NotificationCenter.default.addObserver(forName: Notification.Name("TodoItemAddFailed"), object: nil, queue: .main) { notification in
            if let userInfo = notification.userInfo,
               let tempIdString = userInfo["tempId"] as? String,
               let tempId = UUID(uuidString: tempIdString) {
                // 移除樂觀更新的臨時項目
                withAnimation(.easeOut(duration: 0.3)) {
                    toDoItems.removeAll { $0.id == tempId }
                }

                // 顯示錯誤提示
                toastMessage = "添加任務失敗，請重試"
                withAnimation {
                    showToast = true
                }
            }
        }

        // 🔧 移除通知監聽器，改用直接回調機制避免通知時序問題
        // 舊的通知機制已被 onReplaceOptimistic 回調取代

        NotificationCenter.default.addObserver(forName: Notification.Name("CompletedDaysDataChanged"), object: nil, queue: .main) { _ in
            dataRefreshToken = UUID()
        }
        
        // 監聽結算完成通知，重置導航狀態並應用樂觀更新
        NotificationCenter.default.addObserver(forName: Notification.Name("SettlementCompleted"), object: nil, queue: .main) { _ in
            self.applySettlementUpdates()
            self.navigateToSettlementView = false
        }
        
        // 監聽鬧鐘觸發通知
        NotificationCenter.default.addObserver(forName: Notification.Name("AlarmTriggered"), object: nil, queue: .main) { _ in
            alarmStateManager.triggerAlarm()
            navigateToSleep01View = true
        }

        // 移除批次更新相關的通知監聽，在Home中使用單個API調用

        // 監聽睡眠模式狀態變更通知
        NotificationCenter.default.addObserver(forName: Notification.Name("SleepModeStateChanged"), object: nil, queue: .main) { _ in
            // 重新檢查睡眠模式狀態
            if UserDefaults.standard.bool(forKey: "isSleepMode") {
                isSleepMode = true
                if let savedAlarmTime = UserDefaults.standard.string(forKey: "alarmTimeString") {
                    alarmTimeString = savedAlarmTime
                }
                updateDayProgress(currentTime: Date())
            } else {
                isSleepMode = false
                dayProgress = 0.0
            }
        }
    }
    
    private func performManualSync() {
        guard !isSyncing else { return }
        isSyncing = true

        Task {
            do {
                let items = try await apiDataManager.getAllTodoItems()
                await MainActor.run {
                    isSyncing = false
                    self.toDoItems = items
                }
            } catch {
                await MainActor.run {
                    isSyncing = false
                    loadingError = "同步失敗: \(error.localizedDescription)"
                    // 移除不必要的備用 API 調用：如果手動同步失敗，loadTodoItems 可能也會失敗
                }
            }
        }
    }
    
    private func loadTodoItems() {
        isLoading = true
        loadingError = nil

        Task {
            do {
                let items = try await apiDataManager.getAllTodoItems()
                await MainActor.run {
                    self.isLoading = false
                    self.toDoItems = items
                    // 只在Home頁面手動刷新時更新Widget，使用靜默模式
                    WidgetFileManager.shared.saveTodayTasksToFileQuietly(items)
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.loadingError = "載入失敗: \(error.localizedDescription)"
                    self.toDoItems = []
                }
            }
        }
    }

    // MARK: - 移除批次更新方法，Home中使用單個API調用
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
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
