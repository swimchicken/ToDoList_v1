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
    
    // 數據同步管理器
    private let dataSyncManager = DataSyncManager.shared
    
    // 判斷是否為當天結算
    @State private var isSameDaySettlement: Bool = false
    
    // 加載狀態
    @State private var isLoading: Bool = true
    
    // 數據刷新令牌 - 用於強制視圖刷新
    @State private var dataRefreshToken: UUID = UUID()
    
    // 日期相關
    private var currentDate: Date {
        return Date()
    }
    
    // 右側日期 - 顯示當前日期
    private var rightDisplayDate: Date {
        return currentDate
    }
    
    // 左側日期 - 顯示上次結算日期（或適當的默認值）
    private var leftDisplayDate: Date {
        // 嘗試獲取上次結算日期
        if let lastSettlementDate = delaySettlementManager.getLastSettlementDate() {
            // 使用實際的上次結算日期
            return lastSettlementDate
        } else {
            // 首次使用時沒有上次結算日期
            // 首次使用或未有結算記錄時使用昨天作為默認顯示值
            // 注意：這裡只是用於顯示，不代表實際的結算狀態
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            print("首次使用應用或無結算記錄，顯示默認時間範圍（昨天到今天）")
            return yesterday
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
                    uncompletedTasks: uncompletedTasks
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
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .background(
            NavigationLink(
                destination: SettlementView02(
                    uncompletedTasks: uncompletedTasks,
                    moveTasksToTomorrow: moveUncompletedTasksToTomorrow
                ), 
                isActive: $navigateToSettlementView02
            ) {
                EmptyView()
            }
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
        
        // 先使用LocalDataManager直接從本地獲取最新數據
        var localItems = LocalDataManager.shared.getAllTodoItems()
        
        // 過濾掉已刪除的項目
        if !recentlyDeletedItemIDs.isEmpty {
            let originalCount = localItems.count
            localItems = localItems.filter { !recentlyDeletedItemIDs.contains($0.id) }
            let filteredCount = originalCount - localItems.count
            print("SettlementView - 過濾掉 \(filteredCount) 個已刪除項目")
            
            // 如果發現有項目應該被刪除但仍存在，強制刪除它們
            if filteredCount > 0 {
                for id in recentlyDeletedItemIDs {
                    LocalDataManager.shared.deleteTodoItem(withID: id)
                    print("SettlementView - 強制刪除項目 ID: \(id)")
                }
            }
        }
        
        // 簡化日誌輸出
        print("SettlementView - 本地數據庫中的項目: \(localItems.count) 個")
        // 詳細項目列表已註釋以減少日誌雜訊
        // for (index, item) in localItems.enumerated() {
        //     print("  項目\(index): ID=\(item.id), 標題=\(item.title), 狀態=\(item.status.rawValue), 有日期=\(item.taskDate != nil)")
        // }

        // 從本地項目中過濾已完成和未完成的項目
        // 首先按日期篩選當天的任務，再按狀態篩選
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // 篩選當天的任務（排除沒有日期的備忘錄任務）
        let todayTasks = localItems.filter { task in
            guard let taskDate = task.taskDate else {
                // 沒有日期的任務（備忘錄）不納入結算範圍
                return false
            }
            let taskDay = calendar.startOfDay(for: taskDate)
            return taskDay == today
        }

        // 從當天任務中分類已完成和未完成的項目
        self.completedTasks = todayTasks.filter { $0.status == .completed }
        self.uncompletedTasks = todayTasks.filter { $0.status == .undone || $0.status == .toBeStarted }

        print("SettlementView - 當天任務篩選結果: 總共 \(todayTasks.count) 個當天任務（排除備忘錄）")
        
        print("SettlementView - 從本地加載任務: 已完成 \(self.completedTasks.count) 個, 未完成 \(self.uncompletedTasks.count) 個")
        
        // 如果本地已有數據，可以先將 isLoading 設為 false 以提高用戶體驗
        if !localItems.isEmpty {
            isLoading = false
        }
        
        // 然後使用DataSyncManager獲取並同步雲端數據
        dataSyncManager.fetchTodoItems { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let items):
                    // 首先過濾掉已刪除的項目
                    var filteredItems = items
                    if !recentlyDeletedItemIDs.isEmpty {
                        let originalCount = filteredItems.count
                        filteredItems = filteredItems.filter { !recentlyDeletedItemIDs.contains($0.id) }
                        let filteredCount = originalCount - filteredItems.count
                        print("SettlementView - 從雲端數據中過濾掉 \(filteredCount) 個已刪除項目")
                    }
                    
                    // 根據任務狀態進行分類
                    // 首先按日期篩選當天的任務，再按狀態篩選
                    let calendar = Calendar.current
                    let today = calendar.startOfDay(for: Date())

                    // 篩選當天的任務（排除沒有日期的備忘錄任務）
                    let todayTasks = filteredItems.filter { task in
                        guard let taskDate = task.taskDate else {
                            // 沒有日期的任務（備忘錄）不納入結算範圍
                            return false
                        }
                        let taskDay = calendar.startOfDay(for: taskDate)
                        return taskDay == today
                    }

                    // 從當天任務中分類已完成和未完成的項目
                    self.completedTasks = todayTasks.filter { $0.status == .completed }
                    self.uncompletedTasks = todayTasks.filter { $0.status == .undone || $0.status == .toBeStarted }
                    
                    print("SettlementView - 成功從雲端加載任務: 已完成 \(self.completedTasks.count) 個, 未完成 \(self.uncompletedTasks.count) 個")
                    for (index, item) in self.completedTasks.enumerated() {
                        print("  已完成項目\(index): ID=\(item.id), 標題=\(item.title)")
                    }
                    
                case .failure(let error):
                    print("SettlementView - 從雲端加載任務失敗: \(error.localizedDescription)")
                    // 加載失敗時保留本地數據，已經在之前設置過了
                }
                
                self.isLoading = false
            }
        }
    }
    
    // Mock data loading function has been removed
    
    // 設置監聽數據變化的觀察者
    private func setupDataChangeObservers() {
        // 監聽數據刷新通知 (從 DataSyncManager 發出)
        NotificationCenter.default.addObserver(
            forName: Notification.Name("TodoItemsDataRefreshed"),
            object: nil,
            queue: .main
        ) { _ in
            self.handleDataRefreshed()
        }
        
        // 監聽任務狀態變更通知
        NotificationCenter.default.addObserver(
            forName: Notification.Name("TodoItemStatusChanged"),
            object: nil,
            queue: .main
        ) { _ in
            self.handleDataRefreshed()
        }
        
        print("SettlementView - 已設置數據變更監聽")
    }
    
    // 處理數據刷新通知
    private func handleDataRefreshed() {
        print("SettlementView - 收到數據刷新通知，重新加載任務")
        dataRefreshToken = UUID() // 更新令牌以強制視圖刷新
        
        // 從UserDefaults獲取最近刪除的項目ID
        var recentlyDeletedItemIDs: Set<UUID> = []
        if let savedData = UserDefaults.standard.data(forKey: "recentlyDeletedItemIDs"),
           let decodedIDs = try? JSONDecoder().decode([UUID].self, from: savedData) {
            recentlyDeletedItemIDs = Set(decodedIDs)
            print("SettlementView - 刷新時獲取到 \(recentlyDeletedItemIDs.count) 個最近刪除項目ID")
        }
        
        // 優化任務刷新過程，避免顯示加載指示器
        // 直接從本地數據庫獲取最新數據
        var localItems = LocalDataManager.shared.getAllTodoItems()
        
        // 過濾掉已刪除的項目
        if !recentlyDeletedItemIDs.isEmpty {
            let originalCount = localItems.count
            localItems = localItems.filter { !recentlyDeletedItemIDs.contains($0.id) }
            let filteredCount = originalCount - localItems.count
            print("SettlementView - 刷新時過濾掉 \(filteredCount) 個已刪除項目")
            
            // 如果發現有項目應該被刪除但仍存在，強制刪除它們
            if filteredCount > 0 {
                for id in recentlyDeletedItemIDs {
                    LocalDataManager.shared.deleteTodoItem(withID: id)
                    print("SettlementView - 刷新時強制刪除項目 ID: \(id)")
                }
            }
        }
        
        // 從本地項目中過濾已完成和未完成的項目
        // 首先按日期篩選當天的任務，再按狀態篩選
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // 篩選當天的任務（排除沒有日期的備忘錄任務）
        let todayTasks = localItems.filter { task in
            guard let taskDate = task.taskDate else {
                // 沒有日期的任務（備忘錄）不納入結算範圍
                return false
            }
            let taskDay = calendar.startOfDay(for: taskDate)
            return taskDay == today
        }

        // 從當天任務中分類已完成和未完成的項目
        self.completedTasks = todayTasks.filter { $0.status == .completed }
        self.uncompletedTasks = todayTasks.filter { $0.status == .undone || $0.status == .toBeStarted }

        print("SettlementView - 數據刷新通知後直接更新: 當天任務 \(todayTasks.count) 個, 已完成 \(self.completedTasks.count) 個, 未完成 \(self.uncompletedTasks.count) 個（排除備忘錄）")
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
    
    // 使用 @State 來追蹤是否已完成，初始值從 task.status 獲取
    @State private var isCompleted: Bool
    
    // 引用數據同步管理器以更新任務狀態
    private let dataSyncManager = DataSyncManager.shared
    
    // 綠色和灰色
    private let greenColor = Color(red: 0, green: 0.72, blue: 0.41)
    private let grayColor = Color(red: 0.52, green: 0.52, blue: 0.52)
    
    // 初始化時設置 isCompleted 的值
    init(task: TodoItem) {
        self.task = task
        self._isCompleted = State(initialValue: task.status == .completed)
    }

    var body: some View {
        HStack(spacing: 12) {
            // 狀態指示圈 - 現在可點擊
            Circle()
                .fill(isCompleted ? greenColor : Color.white.opacity(0.15))
                .frame(width: 17, height: 17)
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
        // 切換本地狀態
        isCompleted.toggle()
        
        // 創建更新後的任務
        var updatedTask = task
        updatedTask.status = isCompleted ? .completed : .undone
        
        // 更新數據庫中的任務
        dataSyncManager.updateTodoItem(updatedTask) { result in
            switch result {
            case .success:
                // 發送通知以刷新 UI
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: Notification.Name("TodoItemStatusChanged"),
                        object: nil
                    )
                }
                print("成功更新任務狀態: \(updatedTask.id) 為 \(updatedTask.status.rawValue)")
            case .failure(let error):
                print("更新任務狀態失敗: \(error.localizedDescription)")
                // 如果更新失敗，恢復本地狀態
                DispatchQueue.main.async {
                    self.isCompleted = !self.isCompleted
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
    @Environment(\.presentationMode) var presentationMode
    
    // 引用延遲結算管理器
    private let delaySettlementManager = DelaySettlementManager.shared
    
    // 數據同步管理器
    private let dataSyncManager = DataSyncManager.shared
    
    // 是否為當天結算 - 使用正確的參數
    private var isSameDaySettlement: Bool {
        // 從 Home 點擊 end today 進入的結算應該始終視為當天結算
        return delaySettlementManager.isSameDaySettlement(isActiveEndDay: true)
    }
    
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
                print("繼續到 SettlementView02 設置計畫，移動設定: \(moveUncompletedTasksToTomorrow)")
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
            
            // 返回按鈕
            Button(action: {
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
    
    // 將未完成任務移至明日的數據處理
    func moveUncompletedTasksToTomorrowData() {
        print("開始將 \(uncompletedTasks.count) 個未完成任務移至明日")
        
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
                    print("任務 '\(task.title)' 原本是日期無時間，移至明天的 00:00:00")
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
                    print("成功將任務 '\(task.title)' 移至明日")
                case .failure(let error):
                    print("移動任務 '\(task.title)' 失敗: \(error.localizedDescription)")
                }
            }
        }
        
        print("完成未完成任務移至明日的處理")
    }
}

// MARK: - Preview
struct SettlementView_Previews: PreviewProvider {
    static var previews: some View {
        SettlementView()
            .environmentObject(AlarmStateManager())
    }
}
