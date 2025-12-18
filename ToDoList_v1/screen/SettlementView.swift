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
    // private let apiDataManager = APIDataManager.shared
    private let apiManager = APIManager.shared
    
    // 判斷是否為當天結算
    @State private var isSameDaySettlement: Bool = false
    
    // 加載狀態
    @State private var isLoading: Bool = true

    // 跟蹤是否已經初始化過數據（避免重複API調用）
    @State private var hasInitializedData: Bool = false

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
                                if isLoading {
                                    // 加載中時顯示loading指示器，不顯示任務列表
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        Spacer()
                                    }
                                    .padding()
                                } else if !completedTasks.isEmpty {
                                    // 加載完成且有已完成任務時才顯示任務列表
                                    ForEach(completedTasks) { task in
                                        TaskRow(task: task)
                                    }
                                } else {
                                    // 加載完成但沒有已完成任務時不顯示任何內容
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

                        if isLoading {
                            // 加載中時顯示loading指示器，不顯示任務列表
                            HStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Spacer()
                            }
                            .padding()
                        } else if !uncompletedTasks.isEmpty {
                            // 加載完成且有未完成任務時才顯示任務列表
                            ForEach(uncompletedTasks) { task in
                                TaskRow(task: task)
                            }
                        } else {
                            // 加載完成但沒有未完成任務時不顯示任何內容
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

            // 🎯 優化：只有第一次進入或需要刷新時才調用API
            if !hasInitializedData {
                print("SettlementView - 第一次進入，調用API加載數據")
                loadTasks()
                hasInitializedData = true
            } else {
                print("SettlementView - 頁面返回，保持現有數據，無需API調用")
                // 如果已經有數據，直接設置為非加載狀態
                isLoading = false
            }
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

    // 加載任務數據 (只在第一次進入時調用)
    func loadTasks() {
        isLoading = true

        // 清空數據，準備載入新數據
        completedTasks = []
        uncompletedTasks = []

        // 使用API獲取任務數據
        Task {
            do {
                // 1. 取得 API 資料 (型別是 [APITodoItem])
                let apiItems = try await APIManager.shared.fetchTodos()
                
                // 2. 轉換資料 (將 [APITodoItem] 轉成 [TodoItem])
                let convertedItems = apiItems.map { apiItem in
                    // 🔍 Debug: 改印出 completionStatus 字串來確認
                    // 👇👇👇 🔍 DEBUG: 列出所有欄位的數值與型別 👇👇👇
                    print("\n========== 🔍 詳細檢查任務資料 (ID: \(apiItem.id)) ==========")
                    print("1. [title]             值: \(apiItem.title), 型別: \(type(of: apiItem.title))")
                    print("2. [completionStatus]  值: \(String(describing: apiItem.completionStatus)), 型別: \(type(of: apiItem.completionStatus))")
                    print("3. [status]            值: \(String(describing: apiItem.status)), 型別: \(type(of: apiItem.status))")
                    print("4. [taskDate]          值: \(String(describing: apiItem.taskDate)), 型別: \(type(of: apiItem.taskDate))")
                    print("5. [taskType]          值: \(String(describing: apiItem.taskType)), 型別: \(type(of: apiItem.taskType))")
                    print("6. [isPinned]          值: \(apiItem.isPinned), 型別: \(type(of: apiItem.isPinned))")
                    print("============================================================\n")
                    // 👆👆👆 --------------------------------------- 👆👆👆
                    
                    // ✅ 關鍵修改：判斷字串是否為 "completed"
                    let isCompleted = (apiItem.completionStatus == "completed")
                    
                    return TodoItem(
                        id: apiItem.id,
                        userID: "",
                        title: apiItem.title,
                        priority: apiItem.priority,
                        isPinned: apiItem.isPinned,
                        taskDate: apiItem.taskDate,
                        note: apiItem.note,
                        taskType: .scheduled,
                        
                        // ✅ 修正：根據字串判斷結果設定狀態
                        completionStatus: isCompleted ? .completed : .pending,
                        status: isCompleted ? .completed : .undone, // 同步更新 status 以防萬一
                        
                        createdAt: Date(),
                        updatedAt: Date(),
                        correspondingImageID: ""
                    )
                }
                
                await MainActor.run {
                    // 3. 傳入轉換後的資料
                    self.processTasksData(convertedItems)
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

        // 監聽結算完成通知，重置初始化狀態
        NotificationCenter.default.addObserver(
            forName: Notification.Name("SettlementCompleted"),
            object: nil,
            queue: .main
        ) { _ in
            print("SettlementView - 接收到結算完成通知，重置初始化狀態")
            self.hasInitializedData = false  // 重置狀態，下次進入時會重新調用API
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
        // 使用API獲取任務數據
        Task {
            do {
                // 1. 取得 API 資料 (型別是 [APITodoItem])
                let apiItems = try await APIManager.shared.fetchTodos()
                
                // 2. 轉換資料 (將 [APITodoItem] 轉成 [TodoItem])
                let convertedItems = apiItems.map { apiItem in
                    return TodoItem(
                        id: apiItem.id,
                        userID: "",                      // 1. 補上 userID (API沒回傳，給空值)
                        title: apiItem.title,
                        priority: apiItem.priority,
                        isPinned: apiItem.isPinned,
                        taskDate: apiItem.taskDate,
                        note: apiItem.note,
                        taskType: .scheduled,
                        completionStatus: .completed,
                        status: apiItem.status ?? .undone,
                        createdAt: Date(),               // 補上: 建立時間 (API沒回傳，給當下)
                        updatedAt: Date(),               // 補上: 更新時間 (給當下)
                        
                        correspondingImageID: ""         // 補上: 圖片ID (API沒回傳，給空值)
                    )
                }
                
                await MainActor.run {
                    // 3. 傳入轉換後的資料 (現在型別是 [TodoItem] 了)
                    self.processTasksData(convertedItems)
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
                /*
                // 1. 如果使用者勾選了「移至明日」，則執行批次更新
                if moveUncompletedTasksToTomorrow {
                    moveUncompletedTasksToTomorrowData()
                }
                */
                
                // 2. 導航到下一個頁面
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
    
    // MARK: - 修改位置：BottomControlsView 內部
    
    func moveUncompletedTasksToTomorrowData() {
        // 1. 準備時間數據 (計算明天)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let calendar = Calendar.current
        let tomorrowStart = calendar.startOfDay(for: tomorrow)
        
        // 2. 構建 BatchUpdateItem 陣列
        // 我們使用 map 將 [TodoItem] 轉換為後端需要的 [BatchUpdateItem] 格式
        let batchItems: [BatchUpdateItem] = uncompletedTasks.map { task in
            
            // --- 日期計算邏輯 (保持原本邏輯不變) ---
            let newTaskDate: Date?
            if let originalTaskDate = task.taskDate {
                let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: originalTaskDate)
                let isTimeZero = (timeComponents.hour == 0 && timeComponents.minute == 0 && timeComponents.second == 0)
                
                if isTimeZero {
                    newTaskDate = tomorrowStart
                } else {
                    var tomorrowComponents = calendar.dateComponents([.year, .month, .day], from: tomorrow)
                    tomorrowComponents.hour = timeComponents.hour
                    tomorrowComponents.minute = timeComponents.minute
                    tomorrowComponents.second = timeComponents.second
                    newTaskDate = calendar.date(from: tomorrowComponents)
                }
            } else {
                newTaskDate = nil
            }
            // -------------------------------------
            
            // 3. 創建批次項目
            // 這裡只設定需要修改的 `task_date`，其他欄位設為 nil (部分更新)
            return BatchUpdateItem(
                id: task.id,
                title: nil,       // 不改標題
                status: nil,      // 不改狀態
                task_date: newTaskDate, // 🆕 修改為明天
                priority: nil,
                is_pinned: nil,
                note: nil,
                corresponding_image_id: nil
            )
        }
        
        // 如果沒有任務需要移動，直接返回
        guard !batchItems.isEmpty else { return }
        
        // 4. 呼叫 API (只需一次請求)
        Task {
            do {
                print("🚀 開始批量移動 \(batchItems.count) 個任務至明天...")
                
                // 呼叫我們剛在 APIManager 寫好的新函式
                let _ = try await APIManager.shared.batchUpdateTasks(items: batchItems)
                
                print("✅ 批量移動成功！")
                
                // 5. 發送通知讓 UI 更新
                // 這會通知首頁和其他頁面重新拉取最新資料
                await MainActor.run {
                    NotificationCenter.default.post(name: Notification.Name("TodoItemsDataRefreshed"), object: nil)
                }
                
            } catch {
                await MainActor.run {
                    print("❌ 批量移動任務失敗: \(error.localizedDescription)")
                }
            }
        }
    }
    
    
    
    /*
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
     taskType: task.taskType,
     completionStatus: task.completionStatus,
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
     */
    // MARK: - Preview
    struct SettlementView_Previews: PreviewProvider {
        static var previews: some View {
            SettlementView()
                .environmentObject(AlarmStateManager())
        }
    }
}
