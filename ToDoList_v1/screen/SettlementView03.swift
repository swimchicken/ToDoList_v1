import SwiftUI
import UserNotifications

// MARK: - Page03ProgressBarSegment (在 SettlementView03.swift 中定義，或從共用檔案引用)
// 如果您決定將 ProgressBarSegment 做成共用檔案，請確保 SettlementView03 能存取到它
// 並且其 isActive 的行為符合 SettlementView03 的需求：
// isActive = true: 綠色實心
// isActive = false: 深灰底綠框
struct Page03ProgressBarSegment: View { // 此處使用之前為 S03 設計的進度條
    let isActive: Bool
    private let segmentWidth: CGFloat = 165
    private let segmentHeight: CGFloat = 11
    private let segmentCornerRadius: CGFloat = 29
    
    var body: some View {
        if isActive {
            Rectangle()
                .fill(Color(red: 0, green: 0.72, blue: 0.41))
                .frame(width: segmentWidth, height: segmentHeight)
                .cornerRadius(segmentCornerRadius)
        } else {
            Rectangle()
                .fill(Color(red: 0.13, green: 0.13, blue: 0.13))
                .frame(width: segmentWidth, height: segmentHeight)
                .cornerRadius(segmentCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: segmentCornerRadius)
                        .inset(by: 0.5)
                        .stroke(Color(red: 0, green: 0.72, blue: 0.41), lineWidth: 1)
                )
        }
    }
}

// MARK: - SettlementView03.swift
struct SettlementView03: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var alarmStateManager: AlarmStateManager
    @State private var navigateToHome: Bool = false
    @State private var selectedHour: Int = 8
    @State private var selectedMinute: Int = 0
    @State private var selectedAmPm: Int = 1
    @State private var isAlarmDisabled: Bool = false
    // 由 Home 端負責關閉整個結算導覽鏈（透過通知），不在此再推一個 Home
    
    // ✅ 新增：Loading 狀態，防止重複點擊
    @State private var isProcessing: Bool = false
    
    // 接收從SettlementView02傳遞的任務信息
    let uncompletedTasks: [TodoItem]
    let moveTasksToTomorrow: Bool
  
    @ObservedObject private var stateManager = SettlementStateManager.shared
    
    // 默認初始化方法（用於preview或無任務情況）
    init(uncompletedTasks: [TodoItem] = [], moveTasksToTomorrow: Bool = false) {
        self.uncompletedTasks = uncompletedTasks
        self.moveTasksToTomorrow = moveTasksToTomorrow
    }
    
    // 引用已完成日期數據管理器
    private let completeDayDataManager = CompleteDayDataManager.shared
    
    // 引用延遲結算管理器
    private let delaySettlementManager = DelaySettlementManager.shared
    
    // 數據同步管理器
    // private let dataSyncManager = DataSyncManager.shared ❌ 移除舊的
    private let apiManager = APIManager.shared
    
    
    // 用於將設置傳遞給 Home 視圖
    class SleepSettings: ObservableObject {
        static let shared = SleepSettings()
        @Published var isSleepMode: Bool = false
        @Published var alarmTime: String = "9:00 AM"
    }
    
    private var tomorrow: Date {
        return Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }
    
    // MARK: - 鬧鐘相關功能
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("通知權限已獲得")
            } else {
                print("通知權限被拒絕")
            }
        }
    }
    
    private func cancelExistingAlarms() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("已取消所有現有鬧鐘")
    }
    
    private func setAlarm(hour: Int, minute: Int, ampm: String) {
        let content = UNMutableNotificationContent()
        content.title = "鬧鐘"
        content.body = "該起床了！"
        content.sound = nil // 使用媒體播放器處理聲音
        
        var dateComponents = DateComponents()
        let hour24 = ampm == "AM" ? (hour == 12 ? 0 : hour) : (hour == 12 ? 12 : hour + 12)
        dateComponents.hour = hour24
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "DailyAlarm", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("設定鬧鐘失敗: \(error)")
            } else {
                print("鬧鐘設定成功: \(hour24):\(String(format: "%02d", minute))")
            }
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
        VStack(alignment: .leading, spacing: 0) {
            topHeaderSection // 使用分解後的子視圖
            
            MultiComponentPicker(
                hour: $selectedHour,
                minute: $selectedMinute,
                ampm: $selectedAmPm
            )
            .frame(height: 216)
            .frame(maxWidth: .infinity, alignment: .center)
            .opacity(isAlarmDisabled ? 0.3 : 1.0)
            .disabled(isAlarmDisabled)
            .padding(.vertical, 20)
            
            alarmToggleSection
            
            Spacer()
            
            bottomNavigationButtons
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.black.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .background(
            // 使用 isDetailLink: false 可以讓導航回到根視圖
            NavigationLink(
                destination: Home()
                    .navigationBarHidden(true)
                    .navigationBarBackButtonHidden(true)
                    .toolbar(.hidden, for: .navigationBar),
                isActive: $navigateToHome,
                label: { EmptyView() }
            )
            .isDetailLink(false) // 這會重置導航堆疊
        )
    }
    
    // MARK: - Sub-views for SettlementView03
    private var topHeaderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            progressAndCheckmarkView
            grayDivider
            whatToDoText
            dateDisplayView
            sunAndTempView
            greenLineImageView
        }
    }
    
    private var progressAndCheckmarkView: some View {
        // *** 修改此處佈局以避免重疊 ***
        HStack {
            //            Spacer() // 左邊 Spacer，用於輔助居中進度條
            
            // 進度條組
            HStack(spacing: 8) {
                Page03ProgressBarSegment(isActive: true) // SettlementView03 使用自己的進度條定義
                Page03ProgressBarSegment(isActive: false)
            }
            
            Spacer() // 中間 Spacer，將打勾圖示推到最右邊
            
            Image(systemName: "checkmark")
                .foregroundColor(.gray)
                .padding(5)
                .background(Color.gray.opacity(0.3))
                .clipShape(Circle())
        }
        .padding(.top, 0)
    }
    
    private var grayDivider: some View {
        Rectangle()
            .frame(height: 1)
            .foregroundColor(Color(red: 0.34, green: 0.34, blue: 0.34))
            .padding(.vertical, 4)
    }
    
    private var whatToDoText: some View {
        HStack {
            Text("What do you want to at")
                .font(Font.custom("Instrument Sans", size: 13).weight(.semibold))
                .foregroundColor(.white)
            Spacer()
        }
    }
    
    private var dateDisplayView: some View {
        let tomorrowParts = formatDateForDisplay(tomorrow)
        return HStack(alignment: .bottom) {
            Text("Tomorrow")
                .font(Font.custom("Instrument Sans", size: 31.79449).weight(.bold))
                .foregroundColor(.white)
            Spacer()
            HStack(spacing: 0) {
                Text(tomorrowParts.monthDay)
                    .font(Font.custom("Instrument Sans", size: 20.65629).weight(.bold))
                    .foregroundColor(.white)
                Text("   ")
                Text(tomorrowParts.weekday)
                    .font(Font.custom("Instrument Sans", size: 20.65629).weight(.bold))
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var sunAndTempView: some View {
        HStack {
            Image(systemName: "sun.max.fill")
                .foregroundColor(.yellow)
            Text("26°C")
                .font(Font.custom("Inria Sans", size: 11.73462))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.top, 2)
    }
    
    private var greenLineImageView: some View {
        Image("Vector 81")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity)
            .padding(.top, 5)
    }
    
    private var alarmToggleSection: some View {
        HStack {
            Text("不使用鬧鐘")
                .font(Font.custom("Inter", size: 16))
                .foregroundColor(.white)
            Spacer()
            Toggle("", isOn: $isAlarmDisabled)
                .labelsHidden()
                .tint(.green)
        }
        .padding()
        .background(Color(white: 0.15))
        .cornerRadius(10)
    }
    
    private var bottomNavigationButtons: some View {
        HStack {
            Button(action: {
                // 返回上一頁
                self.presentationMode.wrappedValue.dismiss()
            }) {
                Text("返回")
                    .font(Font.custom("Inria Sans", size: 20))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
            }.padding()
            Spacer()
            
            Button(action: {
                // MARK: - 修改處 (Modification Here)
                // ✅ 呼叫統一的處理函式，執行所有 API 請求與結算邏輯
                handleFinalSettlement()
            }) {
                Text(isAlarmDisabled ? "完成結算" : "進入睡眠模式")
                    .font(Font.custom("Inria Sans", size: 20).weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(width: 279, height: 60).background(.white).cornerRadius(40.5)
        }
        .padding(.bottom, 20)
    }
    
    
    
    
    
    // MARK: - 核心執行邏輯 (Master Commit)
    private func handleFinalSettlement() {
        guard !isProcessing else { return }
        isProcessing = true
        
        print("🚀 [SettlementView03] 開始執行最終結算流程...")
        
        Task {
            do {
                // 1. 執行 Page 2 的暫存操作
                // ✅ 修正：加上 'try'，因為此函式會拋出錯誤
                try await executePendingOperations()
                
                // 2. 執行 Page 1 的移動任務邏輯
                if moveTasksToTomorrow && !uncompletedTasks.isEmpty {
                    await performMoveTasksToTomorrow()
                }
                
                // 3. 標記今天完成
                completeDayDataManager.markTodayAsCompleted()
                
                // 4. 標記結算流程完成
                delaySettlementManager.markSettlementCompleted()
                
                // 5. 全部成功！回到主線程更新 UI 並清空資料
                await MainActor.run {
                    if !isAlarmDisabled {
                        setupAlarmAndSleepMode()
                    } else {
                        clearAlarmAndSleepMode()
                    }
                    
                    print("🧹 結算成功，清空暫存資料")
                    // ✅ 只有在這裡才清空資料
                    stateManager.reset()
                    
                    // 發送通知刷新首頁
                    NotificationCenter.default.post(name: Notification.Name("SettlementCompleted"), object: nil)
                    NotificationCenter.default.post(name: Notification.Name("TodoItemsDataRefreshed"), object: nil)
                    
                    isProcessing = false
                    navigateToHome = true
                }
                
            } catch {
                // ✅ 錯誤處理：如果有任何一步失敗 (throw error)，就會跳到這裡
                await MainActor.run {
                    print("❌ 結算流程失敗: \(error.localizedDescription)")
                    print("⚠️ 暫存資料未清空，請檢查網路或 API 狀態")
                    
                    isProcessing = false
                    // 這裡不導航回首頁，讓用戶可以重試
                }
            }
        }
    }
    
    private func executePendingOperations() async throws {
            guard !stateManager.pendingOperations.isEmpty else { return }
            print("⚡️ [API] 開始執行 \(stateManager.pendingOperations.count) 個暫存操作")
            
            // 依序執行每個操作，如果有一個失敗就 throw error
            for operation in stateManager.pendingOperations {
                switch operation {
                case .addItem(let item):
                    // ✅ 修正：呼叫 createTodo，並進行資料轉換
                    print("➕ 執行新增 API (Create): \(item.title)")
                    
                    // 將 TodoItem 轉換為 CreateTodoRequest
                    let request = CreateTodoRequest(
                        title: item.title,
                        note: item.note,
                        priority: item.priority,
                        isPinned: item.isPinned,
                        taskDate: item.taskDate,
                        taskType: TaskType (rawValue: item.taskType.rawValue)!,
                        completionStatus: item.completionStatus,
                        status: item.status,
                        correspondingImageId: item.correspondingImageID
                    )
                    
                    // 呼叫正確的方法名稱：createTodo
                    let _ = try await apiManager.createTodo(request)
                    
                    print("✅ 新增成功: \(item.title)")
                    
                case .deleteItem(let id):
                    try await apiManager.deleteTodo(id: id)
                    print("✅ 刪除成功: \(id)")
                    
                case .updateItem(let item):
                    let request = UpdateTodoRequest(
                        title: item.title,
                        note: item.note,
                        priority: item.priority,
                        isPinned: item.isPinned,
                        taskDate: item.taskDate,
                        taskType: item.taskType,
                        completionStatus: item.completionStatus,
                        status: item.status,
                        correspondingImageId: item.correspondingImageID.isEmpty ? "" : item.correspondingImageID
                    )
                    let _ = try await apiManager.updateTodo(id: item.id, request)
                    print("✅ 更新成功: \(item.title)")
                }
            }
            print("🎉 所有暫存操作執行完畢！")
        
    }
    
    // 執行任務批量移動
    // MARK: - Task Movement Logic (修正版)
    
    /// 將未完成任務移至明日的數據處理
    private func performMoveTasksToTomorrow() async {
        print("🚀 [Logic] 開始執行任務日期移動邏輯 (使用 Batch API)...")
        
        let calendar = Calendar.current
        let now = Date()
        
        // 1. 設定目標日期 (明天)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else { return }
        let targetDayStart = calendar.startOfDay(for: tomorrow)
        
        // 2. 建立排除清單 (如果在 Page 2 刪除了，就不移動)
        let deletedIds = stateManager.pendingOperations.compactMap { operation -> UUID? in
            if case .deleteItem(let id) = operation { return id }
            return nil
        }
        let deletedSet = Set(deletedIds)
        
        // 3. 準備批量更新資料
        var batchItems: [BatchUpdateItem] = []
        
        for task in uncompletedTasks {
            if deletedSet.contains(task.id) { continue }
            
            var newTaskDate: Date?
            if let originalDate = task.taskDate {
                let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: originalDate)
                let isTimeZero = (timeComponents.hour == 0 && timeComponents.minute == 0 && timeComponents.second == 0)
                
                if isTimeZero {
                    newTaskDate = targetDayStart
                } else {
                    var targetComps = calendar.dateComponents([.year, .month, .day], from: targetDayStart)
                    targetComps.hour = timeComponents.hour
                    targetComps.minute = timeComponents.minute
                    targetComps.second = timeComponents.second
                    newTaskDate = calendar.date(from: targetComps)
                }
                
                // 加入列表
                // 注意：根據 Swagger，後端接受部分欄位。我們只傳送需要修改的 task_date
                let batchItem = BatchUpdateItem(
                    id: task.id,
                    title: nil,
                    status: nil,
                    task_date: newTaskDate, // ✅ 核心：只改這個
                    priority: nil,
                    is_pinned: nil,
                    note: nil,
                    corresponding_image_id: nil
                )
                batchItems.append(batchItem)
                
            } else {
                continue // 跳過備忘錄
            }
        }
        
        guard !batchItems.isEmpty else {
            print("⚠️ 沒有需要移動的任務")
            return
        }
        
        // 4. 發送 API
        print("⚡️ [API] 發送 Batch PUT 請求，包含 \(batchItems.count) 個任務")
        do {
            // 這裡會呼叫我們剛修正為 PUT 的方法
            let response = try await apiManager.batchUpdateTasks(items: batchItems)
            print("✅ 批量移動成功! API 回應: \(response)")
        } catch {
            print("❌ 批量移動失敗: \(error.localizedDescription)")
        }
    }
    
    // 設定鬧鐘與睡眠模式
    private func setupAlarmAndSleepMode() {
        let hourToSave = selectedHour
        let minuteToSave = selectedMinute
        let ampmToSave = selectedAmPm == 0 ? "AM" : "PM"
        
        let formattedMinute = String(format: "%02d", minuteToSave)
        let alarmTimeFormatted = "\(hourToSave):\(formattedMinute) \(ampmToSave)"
        
        requestNotificationPermission()
        cancelExistingAlarms()
        setAlarm(hour: hourToSave, minute: minuteToSave, ampm: ampmToSave)
        
        UserDefaults.standard.set(true, forKey: "isSleepMode")
        UserDefaults.standard.set(alarmTimeFormatted, forKey: "alarmTimeString")
        
        alarmStateManager.startSleepMode(alarmTime: alarmTimeFormatted)
        SleepSettings.shared.isSleepMode = true
        SleepSettings.shared.alarmTime = alarmTimeFormatted
    }
    
    // 清除鬧鐘與睡眠模式
    private func clearAlarmAndSleepMode() {
        cancelExistingAlarms()
        UserDefaults.standard.set(false, forKey: "isSleepMode")
        UserDefaults.standard.removeObject(forKey: "alarmTimeString")
        
        if alarmStateManager.isSleepModeActive {
            alarmStateManager.endSleepMode()
        }
        SleepSettings.shared.isSleepMode = false
        SleepSettings.shared.alarmTime = ""
    }
    
}

#Preview {
    SettlementView03()
        .environmentObject(AlarmStateManager())
}
