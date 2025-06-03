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
                                if isLoading {
                                    // 載入中顯示進度圈
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        Spacer()
                                    }
                                    .padding()
                                } else if !completedTasks.isEmpty {
                                    // 顯示從資料庫加載的已完成任務
                                    ForEach(completedTasks) { task in
                                        TaskRow(task: task)
                                    }
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

                        if isLoading {
                            // 載入中顯示進度圈
                            HStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Spacer()
                            }
                            .padding()
                        } else if !uncompletedTasks.isEmpty {
                            // 顯示從資料庫加載的未完成任務
                            ForEach(uncompletedTasks) { task in
                                TaskRow(task: task)
                            }
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
                    navigateToSettlementView02: $navigateToSettlementView02
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 60)
        }
        .onAppear {
            // 初始化當天結算狀態
            isSameDaySettlement = delaySettlementManager.isSameDaySettlement()
            
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
            NavigationLink(destination: SettlementView02(), isActive: $navigateToSettlementView02) {
                EmptyView()
            }
        )
    }

    // 加載任務數據
    func loadTasks() {
        isLoading = true
        
        // 先使用LocalDataManager直接從本地獲取最新數據
        let localItems = LocalDataManager.shared.getAllTodoItems()
        
        // 打印所有本地項目的狀態進行調試
        print("SettlementView - 本地數據庫中的項目: \(localItems.count) 個")
        for (index, item) in localItems.enumerated() {
            print("  項目\(index): ID=\(item.id), 標題=\(item.title), 狀態=\(item.status.rawValue), 有日期=\(item.taskDate != nil)")
        }
        
        // 從本地項目中過濾已完成和未完成的項目
        self.completedTasks = localItems.filter { $0.status == .completed }
        self.uncompletedTasks = localItems.filter { $0.status == .undone || $0.status == .toBeStarted }
        
        print("SettlementView - 從本地加載任務: 已完成 \(self.completedTasks.count) 個, 未完成 \(self.uncompletedTasks.count) 個")
        
        // 然後使用DataSyncManager獲取並同步雲端數據
        dataSyncManager.fetchTodoItems { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let items):
                    // 根據任務狀態進行分類
                    self.completedTasks = items.filter { $0.status == .completed }
                    self.uncompletedTasks = items.filter { $0.status == .undone || $0.status == .toBeStarted }
                    
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
    
    // 加載假數據（當實際數據加載失敗時使用）
    func loadMockTasks() {
        print("SettlementView - 加載假數據")
        
        // 假数据
        completedTasks = [
            TodoItem(id: UUID(), userID: "user1", title: "完成設計提案初稿", priority: 2, isPinned: false, note: "", status: .completed, createdAt: Date(), updatedAt: Date(), correspondingImageID: ""),
            TodoItem(id: UUID(), userID: "user1", title: "Prepare tomorrow's meeting report", priority: 1, isPinned: false, note: "", status: .completed, createdAt: Date(), updatedAt: Date(), correspondingImageID: ""),
            TodoItem(id: UUID(), userID: "user1", title: "整理桌面和文件夾", priority: 0, isPinned: false, note: "", status: .completed, createdAt: Date(), updatedAt: Date(), correspondingImageID: ""),
            TodoItem(id: UUID(), userID: "user1", title: "寫一篇學習筆記", priority: 0, isPinned: false, note: "", status: .completed, createdAt: Date(), updatedAt: Date(), correspondingImageID: "")
        ]
        
        uncompletedTasks = [
            TodoItem(id: UUID(), userID: "user1", title: "回覆所有未讀郵件", priority: 1, isPinned: false, note: "", status: .undone, createdAt: Date(), updatedAt: Date(), correspondingImageID: ""),
            TodoItem(id: UUID(), userID: "user1", title: "練習日語聽力", priority: 2, isPinned: false, note: "", status: .undone, createdAt: Date(), updatedAt: Date(), correspondingImageID: ""),
            TodoItem(id: UUID(), userID: "user1", title: "市場研究", priority: 0, isPinned: false, note: "", status: .undone, createdAt: Date(), updatedAt: Date(), correspondingImageID: "")
        ]
    }
    
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
        loadTasks() // 重新加載任務數據
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
    
    // 根據任務狀態確定是否已完成
    private var isCompleted: Bool {
        return task.status == .completed
    }
    
    // 綠色和灰色
    private let greenColor = Color(red: 0, green: 0.72, blue: 0.41)
    private let grayColor = Color(red: 0.52, green: 0.52, blue: 0.52)

    var body: some View {
        HStack(spacing: 12) {
            // 狀態指示圈
            Circle()
                .fill(isCompleted ? greenColor : Color.white.opacity(0.15))
                .frame(width: 17, height: 17)

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
}

struct MockTaskRow: View {
    let title: String
    let isCompleted: Bool
    
    // 綠色和灰色
    private let greenColor = Color(red: 0, green: 0.72, blue: 0.41)
    private let grayColor = Color(red: 0.52, green: 0.52, blue: 0.52)

    var body: some View {
        HStack(spacing: 12) {
            // 狀態指示圈
            Circle()
                .fill(isCompleted ? greenColor : Color.white.opacity(0.15))
                .frame(width: 17, height: 17)

            // 任務標題 - 在結算頁面中移除刪除線
            Text(title)
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
}

struct BottomControlsView: View {
    @Binding var moveUncompletedTasksToTomorrow: Bool
    @Binding var navigateToSettlementView02: Bool  // 添加導航綁定
    @Environment(\.presentationMode) var presentationMode
    
    // 引用延遲結算管理器
    private let delaySettlementManager = DelaySettlementManager.shared
    
    // 是否為當天結算
    private var isSameDaySettlement: Bool {
        return delaySettlementManager.isSameDaySettlement()
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
                // 根據是否為當天結算執行不同操作
                if isSameDaySettlement {
                    // 當天結算才進入 SettlementView02 繼續流程
                    navigateToSettlementView02 = true
                    print("是當天結算，繼續到 SettlementView02")
                } else {
                    // 非當天結算（延遲結算）直接標記結算完成並返回首頁
                    delaySettlementManager.markSettlementCompleted()
                    print("是延遲結算，標記完成並返回首頁")
                    presentationMode.wrappedValue.dismiss()
                }
            }) {
                // 按鈕文字根據是否為當天結算而變化
                Text(isSameDaySettlement ? "開始設定今天的計畫" : "完成結算並返回")
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
}

// MARK: - Preview
struct SettlementView_Previews: PreviewProvider {
    static var previews: some View {
        SettlementView()
    }
}
