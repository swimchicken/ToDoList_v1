import Foundation
import SwiftUI
import Combine
import SpriteKit
import CloudKit

class HomeViewModel: ObservableObject {
    // MARK: - Published Properties (State)
    @Published var showCalendarView: Bool = false
    @Published var updateStatus: String = ""
    @Published var showToDoSheet: Bool = false
    @Published var showAddTaskSheet: Bool = false
    @Published var currentDate: Date = Date()
    @Published var navigateToSettlementView: Bool = false
    @Published var navigateToSleep01View: Bool = false
    @Published var navigateToTestPage: Bool = false
    @Published var navigationViewID = UUID()
    @Published var isSleepMode: Bool = false
    @Published var alarmTimeString: String = "9:00 AM"
    @Published var dayProgress: Double = 0.0
    @Published var taskToEdit: TodoItem?
    @Published var showToast: Bool = false
    @Published var toastMessage: String = ""
    
    @Published var dataRefreshToken: UUID = UUID()

    enum AddTaskMode {
        case memo
        case today
        case future
    }
    
    @Published var addTaskMode: AddTaskMode = .today
    @Published var isFromTodoSheet: Bool = false
    
    @Published var toDoItems: [TodoItem] = []
    @Published var isLoading: Bool = true
    @Published var loadingError: String? = nil
    @Published var isSyncing: Bool = false
    
    @Published var showingDeleteView: Bool = false
    @Published var selectedItem: TodoItem? = nil
    @Published var showingEditSheet: Bool = false
    @Published var editingItem: TodoItem? = nil
    
    @Published var showNoEventsAlert: Bool = false
    @Published var showProfileSidebar: Bool = false
    
    @Published var showTaskSelectionOverlay: Bool = false
    @Published var pendingTasks: [TodoItem] = []
    
    @Published var currentDateOffset: Int = 0
    
    // For ScrollView
    @Published var scrollDateOffsets: [Int] = [-2, -1, 0, 1, 2]
    @Published var scrollPosition: Int? = 0
    @Published var isScrolling: Bool = false
    
    // Caching for sorted items
    private var cachedSortedItems: [Int: [TodoItem]] = [:]
    
    // Timer
    var timer: Timer?
    let sleepModeTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()


    // Environment Objects - will be injected
    var alarmStateManager: AlarmStateManager
    
    // Data Managers
    let apiDataManager = APIDataManager.shared
    let completeDayDataManager = CompleteDayDataManager.shared
    let delaySettlementManager = DelaySettlementManager.shared

    // Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var isBlurred: Bool {
        showAddTaskSheet || showingDeleteView || showTaskSelectionOverlay || taskToEdit != nil || showNoEventsAlert || showProfileSidebar
    }

    var taiwanTime: (monthDay: String, weekday: String, timeStatus: String) {
        let currentDateWithOffset = Calendar.current.date(byAdding: .day, value: currentDateOffset, to: currentDate) ?? currentDate
        
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Taipei")
        formatter.locale = Locale(identifier: "en_US")
        
        formatter.dateFormat = "MMM dd"
        let monthDay = formatter.string(from: currentDateWithOffset)
        
        formatter.dateFormat = "EEEE"
        let weekday = formatter.string(from: currentDateWithOffset)
        
        formatter.dateFormat = "HH:mm"
        let time = formatter.string(from: currentDate)
        let timeStatus = "\(time) awake"
        
        return (monthDay: monthDay, weekday: weekday, timeStatus: timeStatus)
    }
    
    var selectedDate: Date {
        Calendar.current.date(byAdding: .day, value: currentDateOffset, to: currentDate) ?? currentDate
    }
    
    var isCurrentDay: Bool {
        return currentDateOffset == 0
    }
    
    var bottomPaddingForTaskList: CGFloat {
        return isCurrentDay ? 190 : 90
    }

    var sortedToDoItems: [TodoItem] {
        return getFilteredToDoItems(for: currentDateOffset)
    }

    // MARK: - Initialization
    init(alarmStateManager: AlarmStateManager) {
        self.alarmStateManager = alarmStateManager
        
        $scrollPosition
            .debounce(for: .seconds(0.1), scheduler: RunLoop.main)
            .sink { [weak self] position in
                guard let self = self, let position = position else { return }
                if self.currentDateOffset != position {
                    self.currentDateOffset = position
                    self.expandScrollRangeIfNeeded(for: position)
                }
            }
            .store(in: &cancellables)
            
        $toDoItems
            .sink { [weak self] _ in
                self?.cachedSortedItems.removeAll()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - View Lifecycle Methods
    
    @MainActor
    func onAppear() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.currentDate = Date()
            }
        }
        loadTodoItems()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.loadTodoItems()
        }
        
        checkAutoSettlement()
        checkSleepMode()
        setupDataChangeObservers()
    }

    func onDisappear() {
        timer?.invalidate()
        timer = nil
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        NotificationCenter.default.removeObserver(self)
    }
    
    func onReceiveSleepModeTimer(_ receivedTime: Date) {
        if isSleepMode {
            updateDayProgress(currentTime: receivedTime)
        }
    }

    // MARK: - Data Loading
    
    @MainActor
    func loadTodoItems() {
        isLoading = true
        loadingError = nil

        Task {
            do {
                let items = try await apiDataManager.getAllTodoItems()
                self.isLoading = false
                self.toDoItems = items
            } catch {
                self.isLoading = false
                self.loadingError = "載入失敗: \(error.localizedDescription)"
                self.toDoItems = []
            }
        }
    }
    
    // MARK: - Event Handlers
    
    func handleEndTodayTapped() {
        print("🔥 用戶點擊 end today 按鈕")
        guard !isSyncing else {
            print("🔥 正在同步中，無法執行結算")
            return
        }
        
        let isSameDay = delaySettlementManager.isSameDaySettlement(isActiveEndDay: true)
        print("用戶點擊結算按鈕，進入結算流程，是否為當天結算 = \(isSameDay) (主動結算)")
        UserDefaults.standard.set(true, forKey: "isActiveEndDay")
        
        NotificationCenter.default.post(name: Notification.Name("TodoItemsDataRefreshed"), object: nil)
        
        Task {
            do {
                let allItems = try await apiDataManager.getAllTodoItems()
                await MainActor.run {
                    let today = Date()
                    let calendar = Calendar.current
                    let startOfToday = calendar.startOfDay(for: today)
                    let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!

                    let todayItems = allItems.filter { item in
                        guard let taskDate = item.taskDate else { return false }
                        return taskDate >= startOfToday && taskDate < endOfToday
                    }

                    if todayItems.isEmpty {
                        showNoEventsAlert = true
                    } else {
                        navigateToSettlementView = true
                    }
                }
            } catch {
                await MainActor.run {
                    print("🔥 載入項目失敗: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @MainActor
    func returnToToday() {
        withAnimation(.easeInOut) {
            currentDateOffset = 0
            if !isSyncing { loadTodoItems() }
        }
    }
    
    func handleAddButtonTapped() {
        if isCurrentDay {
            addTaskMode = .today
        } else {
            addTaskMode = .future
        }
        withAnimation(.easeInOut) {
            showAddTaskSheet = true
        }
    }

    func showErrorToast(message: String) {
        self.toastMessage = message
        withAnimation {
            self.showToast = true
        }
    }

    func handleTasksReceived(_ receivedTasks: [TodoItem]) {
        let tasksWithCorrectDate = receivedTasks.map { task -> TodoItem in
            var modifiedTask = task
            if modifiedTask.taskDate == nil {
                modifiedTask.taskDate = self.selectedDate
            }
            return modifiedTask
        }
        
        self.pendingTasks = tasksWithCorrectDate
        
        if !self.pendingTasks.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.showTaskSelectionOverlay = true
            }
        }
    }

    func handleSleepButtonTapped() {
        print("Sleep button tapped, current navigateToSleep01View: \(navigateToSleep01View)")
        if navigateToSleep01View {
            navigateToSleep01View = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.navigateToSleep01View = true
            }
        } else {
            navigateToSleep01View = true
        }
    }
    
    func handleSettlementViewDismissal() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.loadTodoItems()
        }
    }
    
    func handleSleepViewDismissal() {
        navigateToSleep01View = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.loadTodoItems()
        }
    }

    // MARK: - Sheet and Overlay Management
    
    @MainActor
    func dismissToDoSheet() {
        withAnimation(.easeInOut) {
            showToDoSheet = false
            loadTodoItems()
        }
    }
    
    func prepareToAddFromTodoSheet() {
        addTaskMode = .memo
        isFromTodoSheet = true
        withAnimation(.easeInOut) {
            showAddTaskSheet = true
        }
    }
    
    func closeAddTaskSheet() {
        showAddTaskSheet = false
        addTaskMode = .today
        isFromTodoSheet = false
        editingItem = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.loadTodoItems()
        }
    }
    
    func addOptimistic(newItem: TodoItem) {
        showAddTaskSheet = false
        addTaskMode = .today
        isFromTodoSheet = false
        editingItem = nil
        toDoItems.append(newItem)
    }

    @MainActor
    func selectDate(dayOffset: Int) {
        withAnimation(.easeInOut) {
            currentDateOffset = dayOffset
            showCalendarView = false
            loadTodoItems()
        }
    }
    
    func closeTaskEditView() {
        self.taskToEdit = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.showTaskSelectionOverlay = true
        }
    }

    func addTasksFromSelection(_ itemsToAdd: [TodoItem]) {
        Task {
            for item in itemsToAdd {
                do {
                    _ = try await self.apiDataManager.addTodoItem(item)
                } catch {
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

    func editTaskFromSelection(_ task: TodoItem) {
        self.showTaskSelectionOverlay = false
        self.taskToEdit = task
    }

    // MARK: - DeleteItemView Logic
    
    func cancelDeleteItem() {
        withAnimation(.easeInOut) {
            showingDeleteView = false
            selectedItem = nil
        }
    }
    
    func editSelectedItem() {
        withAnimation(.easeInOut) {
            showingDeleteView = false
            editingItem = selectedItem
            selectedItem = nil
            showAddTaskSheet = true
        }
    }
    
    func deleteSelectedItem() {
        guard let itemToDelete = selectedItem else { return }
        withAnimation(.easeInOut) {
            showingDeleteView = false
            selectedItem = nil
        }
        let deletedItemID = itemToDelete.id

        Task {
            do {
                try await apiDataManager.deleteTodoItem(withID: deletedItemID)
                await MainActor.run { self.loadTodoItems() }
            } catch {
                await MainActor.run { print("刪除失敗: \(error.localizedDescription)") }
            }
        }
    }
    
    func moveSelectedItemToQueue() {
        guard let itemToMove = selectedItem else { return }
        withAnimation(.easeInOut) {
            showingDeleteView = false
            selectedItem = nil
        }
        
        let queueItem = TodoItem(
            id: UUID(),
            userID: itemToMove.userID,
            title: itemToMove.title,
            priority: itemToMove.priority,
            isPinned: itemToMove.isPinned,
            taskDate: nil,
            note: itemToMove.note,
            status: .toBeStarted,
            createdAt: Date(),
            updatedAt: Date(),
            correspondingImageID: itemToMove.correspondingImageID
        )
        
        let deletedItemID = itemToMove.id
        Task {
            do {
                _ = try await apiDataManager.addTodoItem(queueItem)
                try await apiDataManager.deleteTodoItem(withID: deletedItemID)
                await MainActor.run { self.loadTodoItems() }
            } catch {
                await MainActor.run { print("移動到佇列失敗: \(error.localizedDescription)") }
            }
        }
    }


    // MARK: - Private Helpers
    
    private func checkAutoSettlement() {
        if delaySettlementManager.shouldShowSettlement() {
            Task {
                do {
                    let allItems = try await apiDataManager.getAllTodoItems()
                    await MainActor.run {
                        self.toDoItems = allItems
                        if !allItems.isEmpty {
                            navigateToSettlementView = true
                        } else {
                            print("自動結算檢測但沒有任何事件，跳過結算流程")
                        }
                    }
                } catch {
                    await MainActor.run {
                        print("自動結算載入項目失敗: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func checkSleepMode() {
        if UserDefaults.standard.bool(forKey: "isSleepMode") {
            isSleepMode = true
            if let savedAlarmTime = UserDefaults.standard.string(forKey: "alarmTimeString") {
                alarmTimeString = savedAlarmTime
            }
            updateDayProgress(currentTime: Date())
        } else {
            isSleepMode = false
        }
    }
    
    private func updateDayProgress(currentTime: Date) {
        self.dayProgress = alarmStateManager.sleepProgress
    }
    
    private func setupDataChangeObservers() {
        let nc = NotificationCenter.default
        
        nc.addObserver(self, selector: #selector(handleDataRefresh), name: Notification.Name("iCloudUserChanged"), object: nil)
        nc.addObserver(self, selector: #selector(handleDataRefresh), name: Notification.Name("TodoItemStatusChanged"), object: nil)
        nc.addObserver(self, selector: #selector(handleDataRefresh), name: Notification.Name("TodoItemsDataRefreshed"), object: nil)
        nc.addObserver(self, selector: #selector(handleDataRefresh), name: Notification.Name("CompletedDaysDataChanged"), object: nil)
        
        nc.addObserver(self, selector: #selector(handleApiSyncCompleted), name: Notification.Name("TodoItemApiSyncCompleted"), object: nil)
        nc.addObserver(self, selector: #selector(handleOptimisticUpdateFailed), name: Notification.Name("TodoItemOptimisticUpdateFailed"), object: nil)
        
        nc.addObserver(self, selector: #selector(handleAlarmTriggered), name: Notification.Name("AlarmTriggered"), object: nil)
        nc.addObserver(self, selector: #selector(handleSleepModeChanged), name: Notification.Name("SleepModeStateChanged"), object: nil)
    }

    @MainActor
    @objc private func handleDataRefresh() {
        dataRefreshToken = UUID()
        loadTodoItems()
    }
    
    @objc private func handleApiSyncCompleted(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let item = userInfo["item"] as? TodoItem,
              let operation = userInfo["operation"] as? String,
              operation == "add" else { return }
        
        if let index = toDoItems.firstIndex(where: { $0.id == item.id }) {
            toDoItems[index] = item
        }
    }
    
    @objc private func handleOptimisticUpdateFailed(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let tempId = userInfo["tempId"] as? UUID,
              let operation = userInfo["operation"] as? String,
              operation == "add",
              let error = userInfo["error"] as? String else { return }
        
        toDoItems.removeAll { $0.id == tempId }
        showErrorToast(message: "保存失敗: \(error)")
    }
    
    @objc private func handleAlarmTriggered() {
        print("收到鬧鐘觸發通知，準備導航到 Sleep01")
        alarmStateManager.triggerAlarm()
        navigateToSleep01View = true
    }
    
    @objc private func handleSleepModeChanged() {
        print("收到睡眠模式狀態變更通知")
        checkSleepMode()
    }

    // MARK: - ScrollView Helpers
    
    func expandScrollRangeIfNeeded(for offset: Int) {
        let buffer = 2
        let minOffset = offset - buffer
        let maxOffset = offset + buffer
        
        while scrollDateOffsets.min() ?? 0 > minOffset {
            let newMin = (scrollDateOffsets.min() ?? 0) - 1
            scrollDateOffsets.insert(newMin, at: 0)
        }
        
        while scrollDateOffsets.max() ?? 0 < maxOffset {
            let newMax = (scrollDateOffsets.max() ?? 0) + 1
            scrollDateOffsets.append(newMax)
        }
    }
    
    func getFilteredToDoItems(for dateOffset: Int) -> [TodoItem] {
        // Check cache first
        if let cachedItems = cachedSortedItems[dateOffset] {
            return cachedItems
        }

        let dateWithOffset = Calendar.current.date(byAdding: .day, value: dateOffset, to: currentDate) ?? currentDate
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: dateWithOffset)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let filteredItems = toDoItems.filter { item in
            guard let taskDate = item.taskDate else { return false }
            return taskDate >= startOfDay && taskDate < endOfDay
        }
        
        let sortedItems = filteredItems.sorted { (item1: TodoItem, item2: TodoItem) -> Bool in
            if item1.isPinned && !item2.isPinned { return true }
            if !item1.isPinned && item2.isPinned { return false }
            if item1.priority != item2.priority { return item1.priority > item2.priority }
            guard let date1 = item1.taskDate, let date2 = item2.taskDate else { return false }
            return date1 < date2
        }

        // Save to cache
        cachedSortedItems[dateOffset] = sortedItems
        return sortedItems
    }
    
    func getBindingToFilteredItem(_ item: TodoItem) -> Binding<TodoItem> {
        if let originalIndex = toDoItems.firstIndex(where: { $0.id == item.id }) {
            return Binding(
                get: { self.toDoItems[originalIndex] },
                set: { self.toDoItems[originalIndex] = $0 }
            )
        }
        return .constant(item)
    }

    func getHolidayInfo(for dateOffset: Int) -> (isHoliday: Bool, name: String, time: String)? {
        let dateWithOffset = Calendar.current.date(byAdding: .day, value: dateOffset, to: currentDate) ?? currentDate
        let calendar = Calendar.current
        
        let dateComponents = calendar.dateComponents([.month, .day], from: dateWithOffset)
        if dateComponents.month == 8 && dateComponents.day == 22 {
            return (isHoliday: true, name: "Shiro birthday", time: "10:00")
        }
        
        return nil
    }
}