import SwiftUI
import SpriteKit
import CloudKit

struct Home: View {
    @State private var showCalendarView: Bool = false
    @State private var updateStatus: String = ""
    @State private var showToDoSheet: Bool = false
    @State private var showAddTaskSheet: Bool = false
    @State private var currentDate: Date = Date()  // 添加當前時間狀態
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
    
    // 檢查是否為當天
    private var isCurrentDay: Bool {
        return currentDateOffset == 0
    }
    
    // 計算屬性：篩選並排序當前日期的待辦事項
    private var sortedToDoItems: [TodoItem] {
        // 獲取帶偏移量的日期
        let dateWithOffset = Calendar.current.date(byAdding: .day, value: currentDateOffset, to: currentDate) ?? currentDate
        
        // 獲取篩選日期的開始和結束時間點
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: dateWithOffset)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // 篩選當天的項目
        let filteredItems = toDoItems.filter { item in
            return item.taskDate >= startOfDay && item.taskDate < endOfDay
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
            return item1.taskDate < item2.taskDate
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
        ZStack {
            // 1. 背景
            Color.black
                .ignoresSafeArea()
            //將所有內容包覆，並依條件進行模糊
            ZStack{
                // 2. 主介面內容
                VStack(spacing: 0) {
                    // Header - 使用台灣時間
                    UserInfoView(
                        avatarImageName: "who",
                        dateText: taiwanTime.monthDay,
                        dateText2: taiwanTime.weekday,
                        statusText: taiwanTime.timeStatus,
                        temperatureText: "26°C",
                        showCalendarView: $showCalendarView
                    )
                    .frame(maxWidth: .infinity, maxHeight: 0)
                    
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
                
                // 3. 底部灰色容器：當天包含 BumpyCircle & 按鈕，非當天只包含按鈕
                VStack {
                    Spacer()
                    
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
                                        // 默認行為 - 重新加載數據
                                        loadTodoItems()
                                    }
                                }) {
                                    // 根據同步狀態顯示不同文字
                                    if isSyncing {
                                        HStack {
                                            Text("同步中...")
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                        }
                                    } else {
                                        Text("end today")
                                    }
                                }
                                .font(.custom("Inria Sans", size: 20).weight(.bold))
                                .foregroundColor(.black)
                                .frame(width: 272, height: 60)
                                .background(Color.white)
                                .cornerRadius(40.5)
                                
                                // plus 按鈕 - 新增任務
                                Button {
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
                                } else {
                                    Text("return to today")
                                }
                            }
                            .font(.custom("Inria Sans", size: 20).weight(.bold))
                            .foregroundColor(.black)
                            .frame(width: 272, height: 60)
                            .background(Color.white)
                            .cornerRadius(40.5)
                            
                            // plus 按鈕 - 新增任務
                            Button {
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
                    
                    // 底部間距
                    Spacer().frame(height: 20)
                }
                .animation(.spring(response: 0.3), value: isCurrentDay)
                .zIndex(2) // 設置底部容器的層級
                
            }
            .blur(radius: showAddTaskSheet ? 13.5 : 0)

            // 4. ToDoSheetView 彈窗 - 使用半透明背景覆盖整个屏幕
            if showToDoSheet {
                // 半透明背景
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut) { showToDoSheet = false }
                    }
                    .zIndex(9)
                
                // 弹出视图位置调整 - 进一步降低位置
                GeometryReader { geometry in
                    VStack {
                        // 调整上方空间，显示在更下方
                        Spacer().frame(height: geometry.size.height * 0.15)
                        
                        // 中央弹出视图
                        ToDoSheetView(toDoItems: toDoItems) {
                            withAnimation(.easeInOut) {
                                showToDoSheet = false
                                // 關閉時刷新數據
                                loadTodoItems()
                            }
                        }
                        
                        // 预留更多空间给底部
                        Spacer()
                    }
                    .frame(width: geometry.size.width)
                }
                .zIndex(10) // 設置ToDoSheetView在最上層
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
                    Add(toDoItems: $toDoItems, onClose: {
                        // 先将showAddTaskSheet设为false
                        showAddTaskSheet = false
                        
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
        .onDisappear {
            // 清除定時器
            timer?.invalidate()
        }
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
                        // 如果本地和雲端都沒有數據，創建一個歡迎項目
                        let welcomeItem = TodoItem(
                            id: UUID(),
                            userID: "user123",
                            title: "歡迎使用待辦事項",
                            priority: 1,
                            isPinned: true,
                            taskDate: Date(),
                            note: "添加您的第一個待辦事項以開始使用",
                            status: .toDoList,
                            createdAt: Date(),
                            updatedAt: Date(),
                            correspondingImageID: "welcome"
                        )
                        self.toDoItems = [welcomeItem]
                        print("本地和雲端都沒有待辦事項，創建歡迎項目")
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
                        // 創建一個錯誤提示項目
                        let errorItem = TodoItem(
                            id: UUID(),
                            userID: "error_user",
                            title: "無法載入數據",
                            priority: 1,
                            isPinned: true,
                            taskDate: Date(),
                            note: "發生錯誤: \(error.localizedDescription)",
                            status: .toDoList,
                            createdAt: Date(),
                            updatedAt: Date(),
                            correspondingImageID: "error"
                        )
                        self.toDoItems = [errorItem]
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
