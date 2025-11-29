import SwiftUI
import Observation

// 2025年iOS推薦架構：@Observable ViewModel
@Observable
class SettlementViewModel {
    // 任務數據 - 自動觀察，不需要@Published
    var completedTasks: [TodoItem] = []
    var uncompletedTasks: [TodoItem] = []
    var isLoading: Bool = true

    // 結算狀態
    var isSameDaySettlement: Bool = false
    var moveUncompletedTasksToTomorrow: Bool = true
    var navigateToSettlementView02: Bool = false

    // 依賴注入
    private let apiDataManager = APIDataManager.shared
    private let delaySettlementManager = DelaySettlementManager.shared

    // 防止重複更新
    private var ongoingUpdates: Set<UUID> = []

    // MARK: - 初始化
    func initialize() {
        setupSettlementState()
    }

    // MARK: - 設置結算狀態
    private func setupSettlementState() {
        let isActiveEndDay = UserDefaults.standard.bool(forKey: "isActiveEndDay")
        isSameDaySettlement = delaySettlementManager.isSameDaySettlement(isActiveEndDay: isActiveEndDay)
    }

    // MARK: - 載入任務數據
    @MainActor
    func loadTasks() async {
        isLoading = true

        do {
            let apiItems = try await apiDataManager.getAllTodoItems()
            processTasksData(apiItems)
            isLoading = false
        } catch {
            print("❌ SettlementViewModel載入任務失敗: \(error.localizedDescription)")
            isLoading = false
        }
    }

    // MARK: - 處理任務數據
    private func processTasksData(_ items: [TodoItem]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let settlementTasks: [TodoItem]

        if isSameDaySettlement {
            // 當天結算：只看今天的任務
            settlementTasks = items.filter { task in
                guard let taskDate = task.taskDate else {
                    return false // 排除備忘錄
                }
                let taskDay = calendar.startOfDay(for: taskDate)
                return taskDay == today
            }
        } else {
            // 延遲結算：從上次結算後到昨天的任務
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

            if let lastSettlementDate = delaySettlementManager.getLastSettlementDate() {
                let dayAfterLastSettlement = calendar.date(byAdding: .day, value: 1, to: lastSettlementDate) ?? lastSettlementDate
                settlementTasks = items.filter { task in
                    guard let taskDate = task.taskDate else {
                        return false // 排除備忘錄
                    }
                    let taskDay = calendar.startOfDay(for: taskDate)
                    return taskDay >= dayAfterLastSettlement && taskDay <= yesterday
                }
            } else {
                settlementTasks = items.filter { task in
                    guard let taskDate = task.taskDate else {
                        return false // 排除備忘錄
                    }
                    let taskDay = calendar.startOfDay(for: taskDate)
                    return taskDay == yesterday
                }
            }
        }

        // 分類任務 - @Observable會自動通知UI更新
        completedTasks = settlementTasks.filter { $0.status == .completed }
        uncompletedTasks = settlementTasks.filter { $0.status == .undone || $0.status == .toBeStarted }
    }

    // MARK: - 輔助方法
    private func getCurrentTask(id: UUID) -> TodoItem? {
        // 在已完成任務中查找
        if let task = completedTasks.first(where: { $0.id == id }) {
            return task
        }
        // 在未完成任務中查找
        if let task = uncompletedTasks.first(where: { $0.id == id }) {
            return task
        }
        return nil
    }

    // MARK: - 樂觀更新任務狀態
    @MainActor
    func toggleTaskStatus(_ task: TodoItem) async {
        // 防止重複點擊
        guard !ongoingUpdates.contains(task.id) else {
            print("🛑 重複點擊被阻止: \(task.title)")
            return
        }

        ongoingUpdates.insert(task.id)
        print("🎯 SettlementViewModel開始切換狀態: \(task.title)")

        // 獲取當前實際狀態 (來自ViewModel中的陣列，不是傳入的task參數)
        let currentTask = getCurrentTask(id: task.id)
        let currentStatus = currentTask?.status ?? task.status
        let newStatus: TodoStatus = currentStatus == .completed ? .undone : .completed

        print("📊 任務狀態檢查: \(task.title) - 原始狀態:\(task.status), 當前狀態:\(currentStatus), 新狀態:\(newStatus)")

        // 樂觀更新UI - @Observable自動觸發重新渲染
        updateTaskStatusOptimistically(taskId: task.id, newStatus: newStatus)

        // 背景API調用
        do {
            var updatedTask = currentTask ?? task
            updatedTask.status = newStatus
            let _ = try await apiDataManager.updateTodoItem(updatedTask)
            print("✅ API更新成功: \(task.title)")
        } catch {
            print("❌ API更新失敗: \(task.title) - \(error.localizedDescription)")
            // 檢查是否是重複請求錯誤
            let nsError = error as NSError
            if !(nsError.domain == "APIDataManager" && nsError.code == 409) {
                // 非重複請求錯誤才回滾樂觀更新
                updateTaskStatusOptimistically(taskId: task.id, newStatus: currentStatus)
            }
        }

        // 最後才移除防重複標記
        ongoingUpdates.remove(task.id)
    }

    // MARK: - 樂觀更新邏輯
    private func updateTaskStatusOptimistically(taskId: UUID, newStatus: TodoStatus) {
        print("🔄 執行樂觀更新: \(taskId) -> \(newStatus)")

        // 這裡的 withAnimation 負責的是「列表項目的移動/消失/出現」
        // 而不是「球球顏色的變化」(那是 View 層負責的)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            // 從completedTasks中查找並移除
            if let completedIndex = completedTasks.firstIndex(where: { $0.id == taskId }) {
                var task = completedTasks.remove(at: completedIndex)
                task.status = newStatus
                if newStatus != .completed {
                    uncompletedTasks.append(task)
                }
                print("➡️ 任務從已完成移到未完成")
                return
            }

            // 從uncompletedTasks中查找並移除
            if let uncompletedIndex = uncompletedTasks.firstIndex(where: { $0.id == taskId }) {
                var task = uncompletedTasks.remove(at: uncompletedIndex)
                task.status = newStatus
                if newStatus == .completed {
                    completedTasks.append(task)
                } else {
                    uncompletedTasks.append(task)
                }
                print("➡️ 任務從未完成移到已完成")
                return
            }

            print("⚠️ 找不到要更新的任務: \(taskId)")
        }

        // @Observable會自動觸發UI更新，不需要手動調用
    }
}