import SwiftUI
import CoreGraphics // Import CoreGraphics for explicit math functions if needed

// MARK: - TodoItem.swift
// 主資料結構：待辦事項 (TodoItem) - 假設已在別處定義
// enum TodoStatus: String, Codable - 假設已在別處定義

// 更新 CircleShapeView 以使用 Image Asset，並移除內部固定 frame
struct CircleShapeView: View {
    let imageName: String // 圖片名稱，例如 "Circle01", "Circle02", "Circle03"
    
    var body: some View {
        Image(imageName)
            .resizable() // 使圖片可縮放以填充框架
            .aspectRatio(contentMode: .fit) // 保持圖片的原始長寬比，完整顯示
            // 如果SVG本身不是圓形透明背景，可能需要 .clipShape(Circle()) 來確保圓形外觀
    }
}

// 更新綠色球球的視圖：移除描邊，加深顏色，確保圓形裁剪
struct GreenCircleImageView: View {
    let imageName: String
    var body: some View {
        Image(imageName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            // 移除了之前的矩形描邊 .overlay(...)
            .clipShape(Circle()) // 確保圖片本身被裁剪成圓形
            .overlay( // 添加半透明黑色疊加層以加深顏色
                Circle() // 疊加一個圓形的顏色
                    .fill(Color.black.opacity(0.2)) // 調整 opacity 來控制加深程度
            )
    }
}


struct SettlementView: View {

    // 任務數據
    @State private var completedTasks: [TodoItem] = []
    @State private var uncompletedTasks: [TodoItem] = []
    @State private var moveUncompletedTasksToTomorrow: Bool = true
    @State private var navigateToSettlementView02: Bool = false // 導航到下一頁
    
    // 延遲結算管理器
    private let delaySettlementManager = DelaySettlementManager.shared

    // API 數據管理器
    private let apiDataManager = APIDataManager.shared
    
    // 判斷是否為當天結算
    @State private var isSameDaySettlement: Bool = false
    
    // 加載狀態
    @State private var isLoading: Bool = true
    
    // 數據刷新令牌 - 用於強制視圖刷新
    @State private var dataRefreshToken: UUID = UUID()

    // 防止重複樂觀更新
    @State private var recentlyUpdatedTasks: Set<UUID> = []
    
    // 日期相關
    private var currentDate: Date {
        return Date()
    }
    
    // 右側日期 - 根據結算類型顯示適當的日期
    private var rightDisplayDate: Date {
        if isSameDaySettlement {
            // 當天結算：顯示今天
            return currentDate
        } else {
            // 延遲結算：顯示昨天（結算範圍的結束日期）
            let calendar = Calendar.current
            return calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        }
    }
    
    // 左側日期 - 顯示上次結算日期（或適當的默認值）
    private var leftDisplayDate: Date {
        if isSameDaySettlement {
            // 當天結算：只顯示一個日期，返回今天即可
            return currentDate
        } else {
            // 延遲結算：顯示未結算期間的開始日期
            if let lastSettlementDate = delaySettlementManager.getLastSettlementDate() {
                // 顯示上次結算日期的下一天（未結算期間的開始）
                let calendar = Calendar.current
                return calendar.date(byAdding: .day, value: 1, to: lastSettlementDate) ?? lastSettlementDate
            } else {
                // 首次使用時沒有上次結算日期，顯示昨天作為默認開始日期
                let calendar = Calendar.current
                let yesterday = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
                print("首次使用應用或無結算記錄，顯示默認時間範圍（昨天）")
                return yesterday
            }
        }
    }

    // 更新 formatDate 以返回月日和星期兩個部分
    private func formatDateForDisplay(_ date: Date) -> (monthDay: String, weekday: String) {
        let dateFormatterMonthDay = DateFormatter()
        dateFormatterMonthDay.locale = Locale(identifier: "en_US_POSIX") // 確保英文月份
        dateFormatterMonthDay.dateFormat = "MMM dd" // 例如：Jan 01
        
        let dateFormatterWeekday = DateFormatter()
        dateFormatterWeekday.locale = Locale(identifier: "en_US_POSIX") // 確保英文星期
        dateFormatterWeekday.dateFormat = "EEEE" // 例如：Tuesday
        
        return (dateFormatterMonthDay.string(from: date), dateFormatterWeekday.string(from: date))
    }

    var body: some View {
        ZStack {
            // 背景顏色修改為全黑
            Color.black
                .edgesIgnoringSafeArea(.all)

            VStack(alignment: .leading, spacing: 0) {
                // 1. 頂部日期選擇器
                TopDateView(
                    leftDateParts: formatDateForDisplay(leftDisplayDate),
                    rightDateParts: formatDateForDisplay(rightDisplayDate),
                    isSameDaySettlement: isSameDaySettlement
                )
                .padding(.bottom, 20) // 日期選擇器下方的間距

                // 日期下方的分隔線 - 修改為響應式寬度
                Rectangle()
                    .frame(height: 1) // 線條高度
                    .foregroundColor(Color(red: 0.34, green: 0.34, blue: 0.34)) // 線條顏色
                                
                // 2. 標題 - 根據結算狀態顯示不同文字
                VStack(alignment: .leading, spacing: 4) {
                    if isSameDaySettlement {
                        // 狀態2（當天結算）顯示「你今天完成了」和「n個任務」
                        Text("你今天完成了")
                            .font(Font.custom("Instrument Sans", size: 13).weight(.bold))
                            .foregroundColor(.white)
                        Text("\(completedTasks.count)個任務")
                            .font(Font.custom("Instrument Sans", size: 31.79449).weight(.bold))
                            .foregroundColor(.white)
                    } else {
                        // 狀態1（延遲結算）顯示原來的文字
                        Text("未結算提醒")
                            .font(Font.custom("Instrument Sans", size: 13).weight(.bold))
                            .foregroundColor(.white)
                        Text("你尚未結算之前的任務")
                            .font(Font.custom("Instrument Sans", size: 31.79449).weight(.bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.top, 20) // 分隔線與標題之間的間距

                ScrollView {
                    // 調整 VStack 的 spacing 以減少項目間的垂直距離
                    VStack(alignment: .leading, spacing: 10) {
                        
                        // 3. 已完成任務列表區域 (使用 ZStack 包裹以添加背景球球)
                        ZStack(alignment: .topLeading) {
                            GeometryReader { geo in
                                // 放置五個綠色球球，更新 frame 和 position
                                GreenCircleImageView(imageName: "GreenCircle01")
                                    .frame(width: 33, height: 32)
                                    .position(x: geo.size.width * 0.7, y: geo.size.height * 0.1)

                                GreenCircleImageView(imageName: "GreenCircle02")
                                    .frame(width: 79, height: 79)
                                    .position(x: geo.size.width * 0.9, y: geo.size.height * 0.55)

                                GreenCircleImageView(imageName: "GreenCircle03")
                                    .frame(width: 59, height: 58)
                                    .position(x: geo.size.width * 0.55, y: geo.size.height * 0.85)

                                GreenCircleImageView(imageName: "GreenCircle04")
                                     .frame(width: 58, height: 58)
                                     .position(x: geo.size.width * 0.2, y: geo.size.height * 0.65)

                                GreenCircleImageView(imageName: "GreenCircle05")
                                     .frame(width: 67, height: 67)
                                     .position(x: geo.size.width * 0.35, y: geo.size.height * 0.25)
                            }
                            .opacity(0.5) // 保持背景球球的整體半透明效果

                            // 實際的已完成任務列表
                            VStack(alignment: .leading, spacing: 10) {
                                if !completedTasks.isEmpty || !isLoading {
                                    // 顯示從資料庫加載的已完成任務
                                    // 即使在加載中也顯示已有的任務，避免閃爍
                                    ForEach(completedTasks) { task in
                                        TaskRow(task: task)
                                    }
                                } else if isLoading && completedTasks.isEmpty {
                                    // 只有當真的沒有任務且正在加載時才顯示加載指示器
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        Spacer()
                                    }
                                    .padding()
                                } else {
                                    // 沒有已完成任務時不顯示任何內容
                                    EmptyView()
                                }
                            }
                        }
                        .frame(minHeight: 200) // 確保 ZStack 有足夠高度讓 GeometryReader 工作

                        Spacer(minLength: 20)

                        // 4. 未完成任務列表
                        Text("\(uncompletedTasks.count)個任務尚未達成")
                            .font(Font.custom("Instrument Sans", size: 13).weight(.semibold))
                            .foregroundColor(.white)

                        if !uncompletedTasks.isEmpty || !isLoading {
                            // 顯示從資料庫加載的未完成任務
                            // 即使在加載中也顯示已有的任務，避免閃爍
                            ForEach(uncompletedTasks) { task in
                                TaskRow(task: task)
                            }
                        } else if isLoading && uncompletedTasks.isEmpty {
                            // 只有當真的沒有任務且正在加載時才顯示加載指示器
                            HStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Spacer()
                            }
                            .padding()
                        } else {
                            // 沒有未完成任務時不顯示任何內容
                            EmptyView()
                        }
                    }
                    .padding(.top, 20)
                }
                
                ZStack {
                    Color.clear.frame(height: 80)

                    HStack(spacing: 30) {
                        CircleShapeView(imageName: "Circle01")
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                            .offset(y: 15)
                        
                        CircleShapeView(imageName: "Circle02")
                            .frame(width: 59, height: 59)
                            .clipShape(Circle())
                            .offset(x: 0, y: 0)
                        
                        CircleShapeView(imageName: "Circle03")
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                            .offset(y: 15)
                    }
                    .offset(x: 40)
                }

                BottomControlsView(
                    moveUncompletedTasksToTomorrow: $moveUncompletedTasksToTomorrow,
                    navigateToSettlementView02: $navigateToSettlementView02,
                    uncompletedTasks: uncompletedTasks,
                    isSameDaySettlement: isSameDaySettlement
                )
            }
            .padding(.horizontal, 12)
        }
        .onAppear {
            // 檢查是否有主動結算標記
            let isActiveEndDay = UserDefaults.standard.bool(forKey: "isActiveEndDay")
            
            // 初始化當天結算狀態 - 如果是主動結算則一律視為當天結算
            isSameDaySettlement = delaySettlementManager.isSameDaySettlement(isActiveEndDay: isActiveEndDay)
            
            // 清除主動結算標記（一次性使用）
            UserDefaults.standard.removeObject(forKey: "isActiveEndDay")
            
            // 打印結算信息以便調試
            if let lastDate = delaySettlementManager.getLastSettlementDate() {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                print("SettlementView - 初始化結算狀態: 是否為當天結算 = \(isSameDaySettlement), 上次結算日期 = \(dateFormatter.string(from: lastDate))")
            } else {
                print("SettlementView - 初始化結算狀態: 是否為當天結算 = \(isSameDaySettlement), 沒有上次結算日期（首次使用）")
            }
            
            // 設置數據變更監聽
            setupDataChangeObservers()
            
            // 加載任務數據
            loadTasks()
        }
        .onDisappear {
            // 移除通知觀察者
            NotificationCenter.default.removeObserver(self)
        }
        .navigationBarHidden(true)
        .id(dataRefreshToken) // 使用數據刷新令牌強制視圖重新渲染
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .background(
            NavigationLink(
                destination: SettlementView02(
                    uncompletedTasks: uncompletedTasks,
                    moveTasksToTomorrow: moveUncompletedTasksToTomorrow
                ),
                isActive: $navigateToSettlementView02,
                label: { EmptyView() }
            )
            .hidden()
        )
    }

    // 加載任務數據
    func loadTasks() {
        isLoading = true
        
        // 從UserDefaults獲取最近刪除的項目ID
        var recentlyDeletedItemIDs: Set<UUID> = []
        if let savedData = UserDefaults.standard.data(forKey: "recentlyDeletedItemIDs"),
           let decodedIDs = try? JSONDecoder().decode([UUID].self, from: savedData) {
            recentlyDeletedItemIDs = Set(decodedIDs)
            print("SettlementView - 獲取到 \(recentlyDeletedItemIDs.count) 個最近刪除項目ID")
        }
        
        // 使用API獲取任務數據
        Task {
            do {
                let apiItems = try await apiDataManager.getAllTodoItems()
                await MainActor.run {
                    self.processTasksData(apiItems)
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    print("SettlementView - 從API加載任務失敗: \(error.localizedDescription)")
                    self.isLoading = false
                }
            }
        }
        
    }

    // 處理任務數據的共用方法
    private func processTasksData(_ items: [TodoItem]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // 根據結算類型決定任務篩選範圍
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
            // 延遲結算：篩選從上次結算日期到昨天的所有任務
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
            let lastSettlementDate = delaySettlementManager.getLastSettlementDate()

            if let lastSettlement = lastSettlementDate {
                let lastSettlementDay = calendar.startOfDay(for: lastSettlement)
                let dayAfterLastSettlement = calendar.date(byAdding: .day, value: 1, to: lastSettlementDay) ?? lastSettlementDay

                settlementTasks = items.filter { task in
                    guard let taskDate = task.taskDate else {
                        return false // 排除備忘錄
                    }
                    let taskDay = calendar.startOfDay(for: taskDate)
                    // 包含上次結算日期之後到昨天的所有任務
                    return taskDay >= dayAfterLastSettlement && taskDay <= yesterday
                }
            } else {
                // 沒有上次結算記錄，只看昨天
                settlementTasks = items.filter { task in
                    guard let taskDate = task.taskDate else {
                        return false // 排除備忘錄
                    }
                    let taskDay = calendar.startOfDay(for: taskDate)
                    return taskDay == yesterday
                }
            }
        }

        // 從篩選的任務中分類已完成和未完成的項目
        self.completedTasks = settlementTasks.filter { $0.status == .completed }
        self.uncompletedTasks = settlementTasks.filter { $0.status == .undone || $0.status == .toBeStarted }
    }

    // Mock data loading function has been removed
    
    // 設置監聽數據變化的觀察者
    private func setupDataChangeObservers() {
        // 先移除可能已存在的監聽器，避免重複
        NotificationCenter.default.removeObserver(self)

        // 監聽數據刷新通知 (從 DataSyncManager 發出)
        NotificationCenter.default.addObserver(
            forName: Notification.Name("TodoItemsDataRefreshed"),
            object: nil,
            queue: .main
        ) { _ in
            self.handleDataRefreshed()
        }
        
        // SettlementView 中使用樂觀更新，不需要監聽 API 完成後的通知
        // 避免重複觸發狀態變更
        // NotificationCenter.default.addObserver(
        //     forName: Notification.Name("TodoItemStatusChanged"),
        //     object: nil,
        //     queue: .main
        // ) { _ in
        //     self.handleDataRefreshed()
        // }

        // 監聽樂觀更新通知
        NotificationCenter.default.addObserver(
            forName: Notification.Name("OptimisticTaskStatusChanged"),
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.object as? [String: Any],
               let taskId = userInfo["taskId"] as? UUID,
               let newStatus = userInfo["newStatus"] as? TodoStatus {
                self.handleOptimisticUpdate(taskId: taskId, newStatus: newStatus)
            }
        }

        // 監聽樂觀更新失敗通知
        NotificationCenter.default.addObserver(
            forName: Notification.Name("OptimisticTaskStatusFailed"),
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.object as? [String: Any],
               let taskId = userInfo["taskId"] as? UUID,
               let originalStatus = userInfo["originalStatus"] as? TodoStatus {
                self.handleOptimisticUpdateFailed(taskId: taskId, originalStatus: originalStatus)
            }
        }

        
    }
    
    // 處理數據刷新通知
    private func handleDataRefreshed() {
        dataRefreshToken = UUID() // 更新令牌以強制視圖刷新

        // 使用API重新獲取數據（靜默模式）
        Task {
            do {
                let apiItems = try await apiDataManager.getAllTodoItems()
                await MainActor.run {
                    self.processTasksData(apiItems)
                }
            } catch {
                await MainActor.run {
                    print("❌ SettlementView刷新失敗: \(error.localizedDescription)")
                }
            }
        }
    }

    // 處理樂觀更新
    private func handleOptimisticUpdate(taskId: UUID, newStatus: TodoStatus) {
        // 檢查是否在短時間內重複更新同一個任務
        if recentlyUpdatedTasks.contains(taskId) {
            return
        }

        // 記錄已更新的任務，0.5秒後清除
        recentlyUpdatedTasks.insert(taskId)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.recentlyUpdatedTasks.remove(taskId)
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            // 在已完成任務列表中查找
            if let completedIndex = completedTasks.firstIndex(where: { $0.id == taskId }) {
                var task = completedTasks.remove(at: completedIndex)
                task.status = newStatus
                if newStatus != .completed {
                    uncompletedTasks.append(task)
                }
            }
            // 在未完成任務列表中查找
            else if let uncompletedIndex = uncompletedTasks.firstIndex(where: { $0.id == taskId }) {
                var task = uncompletedTasks.remove(at: uncompletedIndex)
                task.status = newStatus
                if newStatus == .completed {
                    completedTasks.append(task)
                } else {
                    // 如果新狀態也是未完成，重新添加到未完成列表
                    uncompletedTasks.append(task)
                }
            }
        }
    }

    // 處理樂觀更新失敗
    private func handleOptimisticUpdateFailed(taskId: UUID, originalStatus: TodoStatus) {
        withAnimation(.easeInOut(duration: 0.2)) {
            // 回滾到原來的狀態
            // 在已完成任務列表中查找
            if let completedIndex = completedTasks.firstIndex(where: { $0.id == taskId }) {
                var task = completedTasks.remove(at: completedIndex)
                task.status = originalStatus
                if originalStatus != .completed {
                    uncompletedTasks.append(task)
                }
            }
            // 在未完成任務列表中查找
            else if let uncompletedIndex = uncompletedTasks.firstIndex(where: { $0.id == taskId }) {
                var task = uncompletedTasks.remove(at: uncompletedIndex)
                task.status = originalStatus
                if originalStatus == .completed {
                    completedTasks.append(task)
                }
            }
        }
    }

}

// MARK: - 子視圖 (Components)

struct TopDateView: View {
    let leftDateParts: (monthDay: String, weekday: String)
    let rightDateParts: (monthDay: String, weekday: String)
    let isSameDaySettlement: Bool

    var body: some View {
        // 根據是否為當天結算顯示不同的日期佈局
        if isSameDaySettlement {
            // 狀態2（當天結算）- 只顯示左側（今天）日期
            HStack {
                DateDisplay(monthDayString: rightDateParts.monthDay, weekdayString: rightDateParts.weekday)
                Spacer()
            }
            .padding(.vertical, 10)
        } else {
            // 狀態1（延遲結算）- 顯示從上次結算到今天的日期範圍
            HStack {
                DateDisplay(monthDayString: leftDateParts.monthDay, weekdayString: leftDateParts.weekday)
                Spacer()
                Image("line01")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 2)
                Spacer()
                DateDisplay(monthDayString: rightDateParts.monthDay, weekdayString: rightDateParts.weekday)
            }
            .padding(.vertical, 10)
        }
    }
}

struct DateDisplay: View {
    let monthDayString: String
    let weekdayString: String

    var body: some View {
        HStack(spacing: 5) {
            Text(monthDayString)
                .font(Font.custom("Instrument Sans", size: 16).weight(.bold))
                .foregroundColor(.white)
            Text(weekdayString)
                .font(Font.custom("Instrument Sans", size: 16).weight(.bold))
                .foregroundColor(.white)
                .opacity(0.5)
        }
    }
}

struct TaskRow: View {
    let task: TodoItem

    // 引用API數據管理器以更新任務狀態
    private let apiDataManager = APIDataManager.shared

    // 防止重複點擊
    @State private var isUpdating: Bool = false

    // 綠色和灰色
    private let greenColor = Color(red: 0, green: 0.72, blue: 0.41)
    private let grayColor = Color(red: 0.52, green: 0.52, blue: 0.52)

    // 計算屬性：直接根據任務狀態判斷是否完成
    private var isCompleted: Bool {
        task.status == .completed
    }

    var body: some View {
        HStack(spacing: 12) {
            // 狀態指示圈 - 現在可點擊
            Circle()
                .fill(isCompleted ? greenColor : Color.white.opacity(0.15))
                .frame(width: 17, height: 17)
                .opacity(isUpdating ? 0.5 : 1.0) // 更新中時減少透明度
                .scaleEffect(isUpdating ? 0.9 : 1.0) // 更新中時稍微縮小
                .animation(.easeInOut(duration: 0.2), value: isUpdating)
                .onTapGesture {
                    toggleTaskStatus()
                }
                .contentShape(Rectangle()) // 增加點擊區域

            // 任務標題 - 在結算頁面中移除刪除線
            Text(task.title)
                .font(Font.custom("Inria Sans", size: 14).weight(.bold))
                .foregroundColor(isCompleted ? greenColor : grayColor)
                .frame(height: 15, alignment: .topLeading)
                .lineLimit(1)
                // 根據需求在結算頁面不顯示刪除線
                // .overlay(
                //     isCompleted ?
                //         Rectangle()
                //         .fill(greenColor)
                //         .frame(height: 1.5)
                //         .offset(y: 0) : nil
                // )
                
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    // 切換任務狀態
    private func toggleTaskStatus() {
        // 防止重複點擊
        guard !isUpdating else {
            return
        }

        isUpdating = true

        // 創建更新後的任務
        var updatedTask = task
        updatedTask.status = isCompleted ? .undone : .completed

        // 樂觀更新：立即發送通知更新父視圖的任務列表
        NotificationCenter.default.post(
            name: Notification.Name("OptimisticTaskStatusChanged"),
            object: ["taskId": task.id, "newStatus": updatedTask.status]
        )

        // 單個任務狀態切換：直接使用單一 API 更新
        Task {
            do {
                let _ = try await apiDataManager.updateTodoItem(updatedTask)
                // 靜默成功，只在錯誤時輸出日誌
            } catch {
                await MainActor.run {
                    let nsError = error as NSError
                    // 如果是重複請求錯誤（409），不需要回滾，因為樂觀更新是正確的
                    if nsError.domain == "APIDataManager" && nsError.code == 409 {
                        // 重複請求是正常的，不需要日誌
                    } else {
                        print("❌ TaskRow 更新失敗: \(error.localizedDescription)")
                        // 發送樂觀更新失敗通知，回滾狀態
                        NotificationCenter.default.post(
                            name: Notification.Name("OptimisticTaskStatusFailed"),
                            object: ["taskId": task.id, "originalStatus": task.status]
                        )
                    }
                }
            }

            // 無論成功或失敗，都重置更新狀態（添加延遲防止過快點擊）
            await MainActor.run {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isUpdating = false
                }
            }
        }
    }
}

// MockTaskRow has been removed

struct BottomControlsView: View {
    @Binding var moveUncompletedTasksToTomorrow: Bool
    @Binding var navigateToSettlementView02: Bool  // 添加導航綁定
    let uncompletedTasks: [TodoItem]  // 添加未完成任務參數
    let isSameDaySettlement: Bool  // 從父視圖傳入的結算狀態
    @Environment(\.presentationMode) var presentationMode

    // 引用延遲結算管理器
    private let delaySettlementManager = DelaySettlementManager.shared

    // API數據管理器
    private let apiDataManager = APIDataManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("將未完成的任務直接移至明日待辦")
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                Spacer()
                Toggle("", isOn: $moveUncompletedTasksToTomorrow)
                    .labelsHidden()
                    .tint(.green)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)

            Button(action: {
                // 不在這裡執行移動邏輯，只傳遞設定到下一個視圖
                // 移動邏輯將在結算流程完成時執行
                navigateToSettlementView02 = true
                }) {
                // 根據模式選擇不同文字
                Text(isSameDaySettlement ? "開始設定明日計畫" : "開始設定今天的計畫")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(25)
            }
            
            // 返回按鈕 - 只在當天結算(主動結算)時顯示
            if isSameDaySettlement {
                Button(action: {
                    // 發送結算完成通知
                    NotificationCenter.default.post(name: Notification.Name("SettlementCompleted"), object: nil)
                    // 返回上一頁
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("返回首頁")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
        }
    }
    
    // 將未完成任務移至明日的數據處理
    func moveUncompletedTasksToTomorrowData() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let calendar = Calendar.current
        let tomorrowStart = calendar.startOfDay(for: tomorrow)

        for task in uncompletedTasks {
            // 決定新的任務時間
            let newTaskDate: Date?

            if let originalTaskDate = task.taskDate {
                // 如果原本有時間，檢查是否為 00:00:00
                let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: originalTaskDate)
                let isTimeZero = (timeComponents.hour == 0 && timeComponents.minute == 0 && timeComponents.second == 0)

                if isTimeZero {
                    // 原本是 00:00:00 的事件（日期無時間），移至明天的 00:00:00
                    newTaskDate = tomorrowStart
                } else {
                    // 原本有具體時間的事件，保留時間但改日期為明天
                    var tomorrowComponents = calendar.dateComponents([.year, .month, .day], from: tomorrow)
                    tomorrowComponents.hour = timeComponents.hour
                    tomorrowComponents.minute = timeComponents.minute
                    tomorrowComponents.second = timeComponents.second

                    newTaskDate = calendar.date(from: tomorrowComponents)
                }
            } else {
                // 原本就沒有時間（備忘錄），保持沒有時間
                newTaskDate = nil
            }

            // 創建更新後的任務
            let updatedTask = TodoItem(
                id: task.id,
                userID: task.userID,
                title: task.title,
                priority: task.priority,
                isPinned: task.isPinned,
                taskDate: newTaskDate,
                note: task.note,
                status: task.status,
                createdAt: task.createdAt,
                updatedAt: Date(),
                correspondingImageID: task.correspondingImageID
            )

            // 使用API更新任務
            Task {
                do {
                    let _ = try await apiDataManager.updateTodoItem(updatedTask)
                } catch {
                    print("❌ 移動任務失敗: \(task.title) - \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Preview
struct SettlementView_Previews: PreviewProvider {
    static var previews: some View {
        SettlementView()
            .environmentObject(AlarmStateManager())
    }
}
