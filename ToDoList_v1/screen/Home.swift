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
    
    
    
    // 添加水平滑動狀態
    @State private var currentDateOffset: Int = 0 // 日期偏移量
    @GestureState private var dragOffset: CGFloat = 0 // 拖動偏移量
    
    // 數據同步管理器 - 處理本地存儲和雲端同步
    private let dataSyncManager = DataSyncManager.shared
    
    // 已完成日期數據管理器 - 追蹤已完成的日期
    private let completeDayDataManager = CompleteDayDataManager.shared
    
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
    
    // 用於更新睡眠模式下的進度條
    private let sleepModeTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
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
        
        // 排序：首先按置頂狀態排序，其次按任務日期排序
        return filteredItems.sorted { item1, item2 in
            // 置頂項目優先
            if item1.isPinned && !item2.isPinned {
                return true
            }
            if !item1.isPinned && item2.isPinned {
                return false
            }
                    
            // 如果置頂狀態相同，按任務日期排序（由早到晚）
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

    // 只在當前為今天時顯示物理場景
    private var physicsScene: PhysicsScene {
        let items = isCurrentDay ? sortedToDoItems : []
        print("PhysicsScene 創建: 當前是今天=\(isCurrentDay), 項目數量=\(items.count)")
        return PhysicsScene(
            size: CGSize(width: 369, height: 100),
            todoItems: items // 只在今天顯示球體
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
                //將所有內容包覆，並依條件進行模糊
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
                            showCalendarView: $showCalendarView
                        )
                        .frame(maxWidth: .infinity, maxHeight: 0)
                        
                        // 顯示日期完成狀態指示器 (已註釋)
                        /* 
                        if isCurrentDisplayDayCompleted {
                            HStack {
                                Spacer()
                                HStack(spacing: 5) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Color(red: 0, green: 0.72, blue: 0.41))
                                    Text("已完成這一天")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color(red: 0, green: 0.72, blue: 0.41))
                                }
                                Spacer()
                            }
                            .padding(.top, 8)
                        }
                        */
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
                            
                            // 更多選項按鈕（新增同步功能）
                            Menu {
                                Button(action: {
                                    performManualSync()
                                }) {
                                    Label("同步數據", systemImage: "arrow.triangle.2.circlepath")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .foregroundColor(.white)
                            }
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
                        
                        // 使用GeometryReader實現左右滑動和上下滾動
                        GeometryReader { geometry in
                            ZStack {
                                // 水平偏移動畫區域（只包含事件列表）
                                HStack(spacing: 0) {
                                    taskList(geometry: geometry)
                                        .frame(width: geometry.size.width)
                                }
                                .offset(x: dragOffset)
                                .gesture(
                                    DragGesture()
                                        .updating($dragOffset) { value, state, _ in
                                            // 水平拖動時更新狀態
                                            state = value.translation.width
                                        }
                                        .onEnded { value in
                                                // 計算拖動結束後應該移動的方向
                                            let threshold = geometry.size.width * 0.2
                                            let predictedEndTranslation = value.predictedEndTranslation.width
                                                
                                                // 根據拖動距離和方向更新日期偏移量
                                            withAnimation(.easeOut) {
                                                if predictedEndTranslation < -threshold {
                                                        // 向左滑動 -> 增加日期
                                                    currentDateOffset += 1
                                                } else if predictedEndTranslation > threshold {
                                                    // 向右滑動 -> 減少日期
                                                    currentDateOffset -= 1
                                                }
                                            }
                                        }
                                )
                            }
                        }
                        .padding(.bottom, bottomPaddingForTaskList)  // 使用動態值
                        .animation(.easeInOut, value: isCurrentDay)  // 添加動畫效果
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 24)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 60)
                .zIndex(1) // 設置主界面内容的層級
                
                // 3. 底部灰色容器：根據睡眠模式和當天狀態顯示不同的UI
                // 只有當沒有顯示待辦事項佇列時才顯示
                if !showToDoSheet {
                    VStack {
                        Spacer()
                        
                        // 先判斷睡眠模式
                        if isSleepMode {
                            // 睡眠模式UI - 類似Sleep01.swift的底部區域但保持相同的間距
                            VStack(spacing: 20) {
                                HStack(spacing: 15) {
                                    Image(systemName: "moon.fill").font(.system(size: 20)).foregroundColor(.white.opacity(0.9))
                                        .shadow(color: .white.opacity(0.4), radius: 25, x: 0, y: 0)
                                        .shadow(color: .white.opacity(0.7), radius: 15, x: 0, y: 0)
                                        .shadow(color: .white, radius: 7, x: 0, y: 0)
                                    GeometryReader { geometry in
                                        ZStack(alignment: .leading) {
                                            Rectangle().foregroundColor(Color.gray.opacity(0.35))
                                            Rectangle().frame(width: max(0, geometry.size.width * CGFloat(dayProgress))).foregroundColor(.white)
                                        }.frame(height: 4).cornerRadius(2).clipped()
                                    }.frame(height: 4)
                                    Image(systemName: "bell.and.waves.left.and.right").font(.system(size: 16)).foregroundColor(.gray)
                                    Text(alarmTimeString)
                                        .font(Font.custom("Inria Sans", size: 18.62571).weight(.light))
                                        .multilineTextAlignment(.center).foregroundColor(.gray)
                                }.padding(.top, 20)
                                
                                HStack(spacing: 10) {
                                    // back to sleep mode 按鈕
                                    Button(action: {
                                        // 導航到Sleep01頁面
                                        navigateToSleep01View = true
                                    }) {
                                        Text("back to sleep mode")
                                            .font(.custom("Inria Sans", size: 20).weight(.bold))
                                            .foregroundColor(.black)
                                            .frame(maxWidth: .infinity) // 使整個按鈕區域可點擊
                                    }
                                    .frame(width: 272, height: 60)
                                    .background(Color.white)
                                    .cornerRadius(40.5)
                                    
                                    // plus 按鈕 - 新增任務
                                    Button {
                                        // 設置為今天模式
                                        addTaskMode = .today
                                        print("睡眠模式頁面的Plus按鈕被點擊，設置模式為: today")
                                        
                                        withAnimation(.easeInOut) {
                                            showAddTaskSheet = true
                                        }
                                    } label: {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 77)
                                                .fill(Color(red: 0, green: 0.72, blue: 0.41))
                                                .frame(width: 71, height: 60)
                                            Image(systemName: "plus")
                                                .font(.system(size: 24))
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                                .padding(.bottom, 20)
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 32).fill(Color.white.opacity(0.15)))
                            .transition(.opacity.combined(with: .scale))
                        } else {
                            // 非睡眠模式 - 原來的UI
                            // 根據當天/非當天使用不同的佈局
                            if isCurrentDay {
                                // 當天顯示完整灰色容器（包含碰撞球和按鈕）
                                VStack(spacing: 10) {
                                    // 1. 物理場景 (BumpyCircle 掉落動畫)
                                    SpriteView(scene: physicsScene, options: [.allowsTransparency])
                                        .frame(width: 369, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 32))
                                        .background(Color.clear)
                                        .id(sortedToDoItems.count) // 強制重新創建場景當項目數量改變時
                                    
                                    // 2. 底下兩個按鈕
                                    HStack(spacing: 10) {
                                        // end today 按鈕
                                        Button(action: {
                                            // 根據同步狀態執行不同操作
                                            if isSyncing {
                                                // 如果正在同步，則只顯示進度（不執行操作）
                                            } else {
                                                // 導航到結算頁面（SettlementView）
                                                navigateToSettlementView = true
                                            }
                                        }) {
                                            // 根據同步狀態顯示不同文字
                                            if isSyncing {
                                                HStack {
                                                    Text("同步中...")
                                                    ProgressView()
                                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                                }
                                                .frame(maxWidth: .infinity) // 使整個按鈕區域可點擊
                                            } else {
                                                Text("end today")
                                                    .frame(maxWidth: .infinity) // 使整個按鈕區域可點擊
                                            }
                                        }
                                        .font(.custom("Inria Sans", size: 20).weight(.bold))
                                        .foregroundColor(.black)
                                        .frame(width: 272, height: 60)
                                        .background(Color.white)
                                        .cornerRadius(40.5)
                                        
                                        // plus 按鈕 - 新增任務
                                        Button {
                                            // 設置為今天模式
                                            addTaskMode = .today
                                            print("今天頁面的Plus按鈕被點擊，設置模式為: today")
                                            
                                            withAnimation(.easeInOut) {
                                                showAddTaskSheet = true
                                            }
                                        } label: {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 77)
                                                    .fill(Color(red: 0, green: 0.72, blue: 0.41))
                                                    .frame(width: 71, height: 60)
                                                Image(systemName: "plus")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 32)
                                        .fill(Color.gray.opacity(0.2))
                                )
                                .transition(.opacity.combined(with: .scale))
                            } else {
                                // 非當天只顯示按鈕
                                HStack(spacing: 10) {
                                    // return to today 按鈕
                                    Button(action: {
                                        withAnimation(.easeInOut) {
                                            currentDateOffset = 0 // 返回到當天
                                            
                                            // 根據同步狀態執行不同操作
                                            if !isSyncing {
                                                // 如果不在同步中，才刷新數據
                                                loadTodoItems()
                                            }
                                        }
                                    }) {
                                        // 根據同步狀態顯示不同文字
                                        if isSyncing {
                                            HStack {
                                                Text("同步中...")
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                            }
                                            .frame(maxWidth: .infinity) // 使整個按鈕區域可點擊
                                        } else {
                                            Text("return to today")
                                                .frame(maxWidth: .infinity) // 使整個按鈕區域可點擊
                                        }
                                    }
                                    .font(.custom("Inria Sans", size: 20).weight(.bold))
                                    .foregroundColor(.black)
                                    .frame(width: 272, height: 60)
                                    .background(Color.white)
                                    .cornerRadius(40.5)
                                    
                                    // plus 按鈕 - 新增任務
                                    Button {
                                        // 設置為未來日期模式
                                        addTaskMode = .future
                                        print("未來日期頁面的Plus按鈕被點擊，設置模式為: future")
                                        
                                        withAnimation(.easeInOut) {
                                            showAddTaskSheet = true
                                        }
                                    } label: {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 77)
                                                .fill(Color(red: 0, green: 0.72, blue: 0.41))
                                                .frame(width: 71, height: 60)
                                            Image(systemName: "plus")
                                                .font(.system(size: 24))
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 32)
                                        .fill(Color.gray.opacity(0.2))
                                )
                                .transition(.opacity.combined(with: .scale))
                            }
                        }
                        
                        // 底部間距
                        Spacer().frame(height: 20)
                    }
                    .animation(.spring(response: 0.3), value: isCurrentDay)
                    .animation(.spring(response: 0.3), value: isSleepMode)
                    .zIndex(2) // 設置底部容器的層級
                }
                
            }
            .blur(radius: showAddTaskSheet || showAddTaskSheet ? 13.5 : 0)

            // 4. ToDoSheetView 彈窗 - 僅覆蓋部分屏幕而非整個屏幕
            if showToDoSheet {
                GeometryReader { geometry in
                    ZStack(alignment: .top) {
                        // 半透明背景 - 只覆蓋上方部分，保留底部按鈕區域可點擊
                        Color.black.opacity(0.5)
                            .frame(height: geometry.size.height - 180) // 保留底部空間給按鈕
                            .onTapGesture {
                                withAnimation(.easeInOut) { showToDoSheet = false }
                            }
                            .zIndex(9)
                        
                        // 弹出视图位置调整 - 确保不会遮挡底部按钮
                        VStack {
                            // 调整上方空间
                            Spacer().frame(height: geometry.size.height * 0.15)
                            
                            // 中央弹出视图 - 设置最大高度以避免遮挡底部按钮
                            ToDoSheetView(
                                toDoItems: $toDoItems,
                                onDismiss: {
                                    withAnimation(.easeInOut) {
                                        showToDoSheet = false
                                        // 關閉時刷新數據
                                        loadTodoItems()
                                    }
                                },
                                onAddButtonPressed: {
                                    // 設置為備忘錄模式
                                    print("🚨 Home - onAddButtonPressed 被觸發，設置模式為 memo")
                                    addTaskMode = .memo
                                    isFromTodoSheet = true
                                    
                                    // 顯示 Add 視圖
                                    withAnimation(.easeInOut) {
                                        showAddTaskSheet = true
                                    }
                                }
                            )
                            .frame(maxHeight: geometry.size.height - 180) // 限制最大高度
                            
                            Spacer()
                        }
                        .frame(width: geometry.size.width)
                        .zIndex(10)
                    }
                    // 添加模糊效果 - 當 Add 視窗打開時
                    .blur(radius: showAddTaskSheet ? 13.5 : 0)
                }
                .ignoresSafeArea()
            }
            
            // 5. 添加 Add.swift 彈出視圖
            if showAddTaskSheet {
                // 首先添加模糊層，覆蓋整個屏幕
                ZStack {
                    // 暗色背景 + 模糊效果疊加，降低亮度
                    ZStack {
                        // 半透明黑色底層
//                        Color.black.opacity(0.7)
//                            .ignoresSafeArea()
                        
                        // 深色模糊材質
//                        Rectangle()
//                            .fill(.ultraThinMaterial.opacity(0.5))  // 降低模糊材質的透明度
//                            .ignoresSafeArea()
                    }
                    .onTapGesture {
                        withAnimation(.easeInOut) {
                            showAddTaskSheet = false
                        }
                    }
                    
                    // Add視圖，在模糊背景之上
                    Add(toDoItems: $toDoItems, 
                        // 首先判斷是否來自待辦事項佇列，如果是則強制為備忘錄模式
                        // 否則再根據當前日期偏移決定模式
                        initialMode: isFromTodoSheet ? .memo : (currentDateOffset == 0 ? .today : .future),
                        currentDateOffset: currentDateOffset,
                        fromTodoSheet: isFromTodoSheet, // 傳遞這個標記
                        onClose: {
                        // 打印調試信息
                        print("⚠️ 關閉Add視圖，最終模式 = \(addTaskMode)，isFromTodoSheet = \(isFromTodoSheet)")
                        
                        // 先将showAddTaskSheet设为false
                        showAddTaskSheet = false
                        // 重置為默認模式
                        addTaskMode = .today
                        // 重置標記
                        isFromTodoSheet = false
                        
                        // 然后延迟一点时间再刷新数据
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            loadTodoItems()
                        }
                    })
                    .transition(.move(edge: .bottom))
                }
                .animation(.easeInOut(duration: 0.3), value: showAddTaskSheet)
                .zIndex(100) // 確保在所有其他內容之上
            }
            
            // 6. 新增: CalendarView 全屏覆蓋
            if showCalendarView {
                ZStack {
                    // 暗色背景 + 模糊效果疊加，降低亮度
                    ZStack {
                        // 半透明黑色底層
                        Color.black.opacity(0.7)
                            .ignoresSafeArea()
                        
                        // 深色模糊材質
                        Rectangle()
                            .fill(.ultraThinMaterial.opacity(0.5))  // 降低模糊材質的透明度
                            .ignoresSafeArea()
                    }
                    .onTapGesture {
                        withAnimation(.easeInOut) {
                            showCalendarView = false
                        }
                    }
                        
                    // 顯示 CalendarView，傳入 toDoItems 的綁定以及日期選擇和導航回調
                    CalendarView(
                        toDoItems: $toDoItems,
                        onDateSelected: { dayOffset in
                            // 接收來自CalendarView的日期偏移量並設置
                            withAnimation(.easeInOut) {
                                currentDateOffset = dayOffset
                                print("設置日期偏移量為: \(dayOffset)")
                                
                                // 關閉日曆
                                showCalendarView = false
                                
                                // 更新視圖
                                loadTodoItems()
                            }
                        },
                        onNavigateToHome: {
                            // 關閉日曆並返回 Home
                            withAnimation(.easeInOut) {
                                showCalendarView = false
                            }
                            
                            // 刷新數據
                            loadTodoItems()
                        }
                    )
                    .onDisappear {
                        // 視圖關閉時刷新數據
                        loadTodoItems()
                    }
                    .transition(.move(edge: .bottom))
                }
                .animation(.easeInOut(duration: 0.3), value: showCalendarView)
                .zIndex(200) // 確保顯示在最上層
            }
            
        }
        
        .animation(.easeOut, value: showToDoSheet)
        .animation(.easeOut, value: showAddTaskSheet)
        .animation(.easeOut, value: showCalendarView)
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            // 設置定時器每分鐘更新時間
            timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                currentDate = Date()
            }
            
            // 從 CloudKit 載入待辦事項
            loadTodoItems()
            
            // 在主線程延遲0.5秒後再次載入，確保視圖更新
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                loadTodoItems()  // 再次載入以確保物理場景正確顯示
            }
            
            // 從 UserDefaults 讀取保存的狀態
            // 檢查睡眠模式是否開啟
            let sleepModeEnabled = UserDefaults.standard.bool(forKey: "isSleepMode")
            
            // 如果睡眠模式被啟用，載入設置
            if sleepModeEnabled {
                isSleepMode = true
                
                // 讀取保存的鬧鐘時間
                if let savedAlarmTime = UserDefaults.standard.string(forKey: "alarmTimeString") {
                    alarmTimeString = savedAlarmTime
                }
                
                // 立即計算進度條
                updateDayProgress(currentTime: Date())
                
                print("載入睡眠模式: 開啟, 鬧鐘時間: \(alarmTimeString)")
            } else {
                isSleepMode = false
                print("載入睡眠模式: 關閉")
            }
            
            // 設置監聽資料變化的通知
            setupDataChangeObservers()
            
            if let appleUserID = UserDefaults.standard.string(forKey: "appleAuthorizedUserId") {
                SaveLast.updateLastLoginDate(forUserId: appleUserID) { result in
                    switch result {
                    case .success:
                        updateStatus = "更新成功"
                    case .failure(let error):
                        updateStatus = "更新失敗: \(error.localizedDescription)"
                    }
                }
            } else {
                updateStatus = "找不到 Apple 使用者 ID"
            }
        }
        .onReceive(sleepModeTimer) { receivedTime in
            // 如果處於睡眠模式，更新進度條
            if isSleepMode {
                updateDayProgress(currentTime: receivedTime)
            }
        }
        .onDisappear {
            // 清除定時器
            timer?.invalidate()
            
            // 移除通知觀察者
            NotificationCenter.default.removeObserver(self, name: Notification.Name("iCloudUserChanged"), object: nil)
            NotificationCenter.default.removeObserver(self, name: Notification.Name("TodoItemsDataRefreshed"), object: nil)
            NotificationCenter.default.removeObserver(self, name: Notification.Name("CompletedDaysDataChanged"), object: nil)
        }
        .background(
            Group {
                NavigationLink(destination: SettlementView(), isActive: $navigateToSettlementView) {
                    EmptyView()
                }
                
                NavigationLink(destination: Sleep01View(), isActive: $navigateToSleep01View) {
                    EmptyView()
                }
            }
        )
    }
    
    // 提取列表視圖為獨立函數，以便在水平滑動容器中使用
    private func taskList(geometry: GeometryProxy) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if sortedToDoItems.isEmpty {
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
                    ForEach(0..<sortedToDoItems.count, id: \.self) { idx in
                        VStack(spacing: 0) {
                            ItemRow(item: getBindingToSortedItem(at: idx))
                                .padding(.vertical, 8)
                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 2)
                        }
                    }
                }
            }
            .background(Color.black)
            .contentShape(Rectangle()) // 使整個區域可接收手勢，即使項目很少
        }
        .scrollIndicators(.hidden)
    }
    
    // 更新睡眠模式下的進度條
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

        let isAlarmTimePassedToday = currentTime >= alarmTimeOnCurrentDay
        
        let cycleStart: Date
        let cycleEnd: Date

        if currentTime < alarmTimeOnCurrentDay {
            cycleEnd = alarmTimeOnCurrentDay
            guard let yesterdayAlarmTime = calendar.date(byAdding: .day, value: -1, to: cycleEnd) else {
                self.dayProgress = 0.0; return
            }
            cycleStart = yesterdayAlarmTime
        } else {
            cycleStart = alarmTimeOnCurrentDay
            guard let tomorrowAlarmTime = calendar.date(byAdding: .day, value: 1, to: cycleStart) else {
                self.dayProgress = 0.0; return
            }
            cycleEnd = tomorrowAlarmTime
        }

        let totalCycleDuration = cycleEnd.timeIntervalSince(cycleStart)
        let elapsedInCycle = currentTime.timeIntervalSince(cycleStart)

        if totalCycleDuration > 0 {
            newProgress = elapsedInCycle / totalCycleDuration
        }
        
        self.dayProgress = min(max(newProgress, 0.0), 1.0)
    }
    
    // 設置監聽數據變化的觀察者
    private func setupDataChangeObservers() {
        // 監聽 iCloud 用戶變更通知 (直接從 CloudKitService 發出)
        NotificationCenter.default.addObserver(
            forName: Notification.Name("iCloudUserChanged"),
            object: nil,
            queue: .main
        ) { _ in
            print("NOTICE: Home 收到用戶變更通知")
            
            // 強制刷新數據
            dataRefreshToken = UUID()
            
            // 清除當前視圖的狀態
            isSleepMode = false
            
            // 延遲一點時間再重新載入數據
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                loadTodoItems()
            }
        }
        
        // 監聽數據刷新通知 (從 DataSyncManager 發出)
        NotificationCenter.default.addObserver(
            forName: Notification.Name("TodoItemsDataRefreshed"),
            object: nil,
            queue: .main
        ) { _ in
            print("NOTICE: Home 收到數據刷新通知")
            
            // 重新載入數據
            loadTodoItems()
        }
        
        // 監聽已完成日期數據變更通知
        NotificationCenter.default.addObserver(
            forName: Notification.Name("CompletedDaysDataChanged"),
            object: nil,
            queue: .main
        ) { _ in
            print("NOTICE: Home 收到已完成日期數據變更通知")
            
            // 強制更新視圖以顯示最新的完成狀態
            dataRefreshToken = UUID()
        }
    }
    
    // 執行手動同步
    private func performManualSync() {
        // 如果正在同步，直接返回
        guard !isSyncing else {
            return
        }
        
        // 設置同步中狀態
        isSyncing = true
        
        // 使用 DataSyncManager 執行同步
        dataSyncManager.performSync { result in
            // 回到主線程更新UI
            DispatchQueue.main.async {
                // 完成同步
                isSyncing = false
                
                switch result {
                case .success(let syncCount):
                    print("手動同步完成! 同步了 \(syncCount) 個項目")
                    
                    // 重新加載 todoItems 以顯示最新數據
                    loadTodoItems()
                    
                case .failure(let error):
                    print("手動同步失敗: \(error.localizedDescription)")
                    
                    // 顯示錯誤提示（這裡可以使用更好的UI來顯示錯誤）
                    loadingError = "同步失敗: \(error.localizedDescription)"
                    
                    // 依然重新加載本地數據
                    loadTodoItems()
                }
            }
        }
    }
    
    // 載入所有待辦事項 - 優先從本地載入，然後在後台同步雲端數據
    private func loadTodoItems() {
        print("開始載入待辦事項: 當前是今天=\(isCurrentDay), 當前toDoItems數量=\(toDoItems.count)")
        isLoading = true
        loadingError = nil
        
        // 使用 DataSyncManager 獲取數據 - 它會優先返回本地數據，然後在後台同步雲端數據
        dataSyncManager.fetchTodoItems { result in
            // 在主線程更新 UI
            DispatchQueue.main.async {
                switch result {
                case .success(let items):
                    self.isLoading = false
                    
                    // 檢查是否接收到數據
                    if items.isEmpty {
                        // 直接保持空列表
                        self.toDoItems = []
                        print("本地和雲端都沒有待辦事項，保持空列表")
                    } else {
                        // 更新模型
                        self.toDoItems = items
                        print("成功載入 \(items.count) 個待辦事項")
                    }
                    
                    // 打印當前狀態以便調試
                    print("待辦事項載入完成: 今天=\(self.isCurrentDay), 篩選後的項目數量=\(self.sortedToDoItems.count)")
                    
                case .failure(let error):
                    self.isLoading = false
                    self.loadingError = "載入待辦事項時發生錯誤: \(error.localizedDescription)"
                    print("載入待辦事項時發生錯誤: \(error.localizedDescription)")
                    
                    // 如果發生錯誤，仍然嘗試從本地獲取數據
                    let localItems = LocalDataManager.shared.getAllTodoItems()
                    if !localItems.isEmpty {
                        self.toDoItems = localItems
                        print("從本地緩存加載了 \(localItems.count) 個項目")
                    } else {
                        // 保持空列表
                        self.toDoItems = []
                        print("無法載入數據且本地無緩存，保持空列表")
                    }
                }
            }
        }
    }
}

// 用於設置圓角的擴展
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

#Preview {
    Home()
}
