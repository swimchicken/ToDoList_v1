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
//    @State private var isShowingModel=false
    
    // 添加水平滑動狀態
    @State private var currentDateOffset: Int = 0 // 日期偏移量
    @GestureState private var dragOffset: CGFloat = 0 // 拖動偏移量
    
    // CloudKit 服務
    private let cloudKitService = CloudKitService.shared
    
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
                    
                    // 同步到 CloudKit
                    self.cloudKitService.updateTodoItem(newValue) { result in
                        switch result {
                        case .success(_):
                            print("成功更新 CloudKit 中的待辦事項")
                        case .failure(let error):
                            print("更新 CloudKit 中的待辦事項失敗: \(error.localizedDescription)")
                        }
                    }
                }
            }
        )
    }

    // 只在當前為今天時顯示物理場景
    private var physicsScene: PhysicsScene {
        PhysicsScene(
            size: CGSize(width: 369, height: 100),
            todoItems: isCurrentDay ? sortedToDoItems : [] // 只在今天顯示球體
        )
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
                            
                            Image(systemName: "ellipsis")
                                .foregroundColor(.white)
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
                        .padding(.bottom, 170)
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
                            
                            // 2. 底下兩個按鈕
                            HStack(spacing: 10) {
                                // end today 按鈕
                                Button("end today") {
                                    // 重新從 CloudKit 載入資料
                                    loadTodoItems()
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
                            Button("return to today") {
                                withAnimation(.easeInOut) {
                                    currentDateOffset = 0 // 返回到當天
                                    // 刷新資料
                                    loadTodoItems()
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
                                    //                                isShowingModal = false
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
                        withAnimation(.easeInOut) {
                            showAddTaskSheet = false
                            // 刷新從 CloudKit 加載的事項
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
                        
                    // 顯示 CalendarView，傳入 toDoItems 的綁定
                    CalendarView(toDoItems: $toDoItems)
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
    
    // 從 CloudKit 載入所有待辦事項
    private func loadTodoItems() {
        isLoading = true
        loadingError = nil
        
        // 创建一些本地测试数据，防止CloudKit连接问题时UI为空
        let fallbackData = [
            TodoItem(
                id: UUID(), userID: "user123", title: "本地测试项目", priority: 1, isPinned: true,
                taskDate: Date(), note: "当CloudKit连接失败时显示的本地项目", status: .toDoList,
                createdAt: Date(), updatedAt: Date(), correspondingImageID: "local"
            )
        ]
        
        // 首先尝试从CloudKit加载
        cloudKitService.fetchAllTodoItems { result in
            // 在主執行緒上更新 UI
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let items):
                    // 成功獲取項目，更新模型
                    if items.isEmpty {
                        // 如果返回空数组但没有错误，使用本地数据
                        self.toDoItems = fallbackData
                        print("CloudKit没有待办事项，使用本地测试数据")
                    } else {
                        self.toDoItems = items
                        print("成功從 CloudKit 載入 \(items.count) 個待辦事項")
                    }
                    
                case .failure(let error):
                    // 处理特定的CloudKit错误
                    let nsError = error as NSError
                    
                    // 检查是否是常见的网络或CloudKit服务错误
                    if nsError.domain == CKErrorDomain {
                        switch nsError.code {
                        case CKError.networkFailure.rawValue, 
                             CKError.networkUnavailable.rawValue,
                             CKError.serviceUnavailable.rawValue:
                            // 网络或服务暂时不可用，使用本地数据
                            self.toDoItems = fallbackData
                            self.loadingError = "CloudKit暂不可用，显示本地数据: \(error.localizedDescription)"
                            
                        case CKError.serverRejectedRequest.rawValue:
                            if nsError.localizedDescription.contains("not marked queryable") {
                                // 特殊处理"recordName not marked queryable"错误
                                self.toDoItems = fallbackData
                                self.loadingError = "CloudKit查询配置问题，显示本地数据"
                            } else {
                                // 其他服务器拒绝问题
                                self.loadingError = "服务器拒绝请求: \(error.localizedDescription)"
                            }
                            
                        default:
                            self.loadingError = "CloudKit错误: \(error.localizedDescription)"
                        }
                    } else {
                        // 其他一般错误
                        self.loadingError = "載入待辦事項時發生錯誤: \(error.localizedDescription)"
                    }
                    
                    print("載入待辦事項時發生錯誤: \(error.localizedDescription)")
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
