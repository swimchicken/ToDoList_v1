import SwiftUI
import UserNotifications
import CloudKit

struct Sleep01View: View {
    // MARK: - 屬性包裝器 & 狀態管理
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var alarmStateManager: AlarmStateManager
    
    // MARK: - 主要狀態變數
    @State private var currentDate = Date()
    @State private var alarmTimeString: String = "9:00 AM"
    @State private var userName: String = "USER" // 儲存用戶名稱
    @State private var todayTodoItems: [TodoItem] = [] // 今天的待辦事項
    // 移除本地進度條變數，改用AlarmStateManager的共享狀態

    // MARK: - 動畫核心狀態
    // 控制頂部 UI (時間、日期) 的可見度
    @State private var showTopUI: Bool = true
    // 控制底部鬧鐘 UI (Good Morning, Stop) 的可見度
    @State private var showBottomAlarmUI: Bool = false
    // 標記滑動動畫是否完成
    @State private var isSwipeUpAnimationCompleted: Bool = false

    // MARK: - 底部拖動相關狀態
    @State private var dragOffset: CGFloat = 0
    @State private var eventListHeight: CGFloat = 0
    @State private var backgroundDimming: Double = 0.0
    
    @State private var isEventListPresented: Bool = false

    // MARK: - 開發者模式
    #if DEBUG
    @State private var timeOffset: TimeInterval = 0
    @State private var showDeveloperMode: Bool = false
    #endif

    // MARK: - 常數與計時器
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let dragThreshold: CGFloat = 175
    private let maxDragHeight: CGFloat = 350

    // MARK: - Formatters & Computed Properties
    private var taipeiCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Asia/Taipei")!; return calendar
    }
    private var alarmStringParser: DateFormatter {
        let formatter = DateFormatter(); formatter.dateFormat = "h:mm a"; formatter.amSymbol = "AM"; formatter.pmSymbol = "PM"; formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(identifier: "Asia/Taipei")!; return formatter
    }
    private var topDateMonthDayFormatter: DateFormatter {
        let formatter = DateFormatter(); formatter.dateFormat = "MMM d"; formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(identifier: "Asia/Taipei")!; return formatter
    }
    private var topDateDayOfWeekFormatter: DateFormatter {
        let formatter = DateFormatter(); formatter.dateFormat = "EEEE"; formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(identifier: "Asia/Taipei")!; return formatter
    }
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter(); formatter.dateFormat = "h:mm a"; formatter.amSymbol = "AM"; formatter.pmSymbol = "PM"; formatter.timeZone = TimeZone(identifier: "Asia/Taipei")!; return formatter
    }
    
    private var simulatedCurrentTime: Date {
        #if DEBUG
        return currentDate.addingTimeInterval(timeOffset)
        #else
        return currentDate
        #endif
    }

    // MARK: - Body
    var body: some View {
        // --- 步驟 1: 先把所有計算都放在 body 的最前面 ---
        let goodMorningStartOffset: CGFloat = 500
        let fadeProgress = isEventListPresented ? 1.0 : min(1.0, dragOffset / dragThreshold)
        
        let sunAnimationStartPoint: CGFloat = 1.0 / 3.0
        let sunIconProgress: CGFloat
        if fadeProgress < sunAnimationStartPoint {
            sunIconProgress = 0
        } else {
            // 將 fadeProgress 的 [1/3, 1] 區間，重新映射到 [0, 1] 區間
            sunIconProgress = (fadeProgress - sunAnimationStartPoint) / (1.0 - sunAnimationStartPoint)
        }

        // --- 步驟 2: 然後 return 一個最外層的 ZStack 作為整個畫面 ---
        return ZStack {
            backgroundView
            
            // --- 主要內容 ---
            VStack(alignment: .leading, spacing: 0) {
                topDateView
                    .opacity(showTopUI ? 1 : 0)

                ZStack(alignment: .leading) {
                    // --- 左側內容 (時間/Good Morning) ---
                    Text(simulatedCurrentTime, formatter: timeFormatter)
                        .font(Font.custom("Inria Sans", size: 47.93416).weight(.bold))
                        .foregroundColor(showBottomAlarmUI && !isSwipeUpAnimationCompleted ? Color(red: 0, green: 0.72, blue: 0.41) : .white)
                        .opacity(showTopUI ? (1.0 - fadeProgress) : 0)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Good morning")
                            .font(Font.custom("Inria Sans", size: isSwipeUpAnimationCompleted ? 47.93416 : 32).weight(.bold))
                        Text(userName)
                            .font(Font.custom("Inria Sans", size: isSwipeUpAnimationCompleted ? 24 : 18))
                    }
                    .foregroundColor(isSwipeUpAnimationCompleted ? Color(red: 0, green: 0.72, blue: 0.41) : .white)
                    .opacity(showTopUI && showBottomAlarmUI ? 1.0 : 0)
                    .offset(y: goodMorningStartOffset * (1.0 - fadeProgress))

                    // --- 右側內容 ---
                    // 容器 HStack + Spacer 確保右對齊
                    HStack {
                        Spacer()

                        // 這是圖示切換的 ZStack
                        ZStack {
                            // 1. 三個點的菜單
                            settingsMenuView()
                                .opacity(1.0 - sunIconProgress)

                            // 2. 太陽圖示本體 (沒有光暈)
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: .orange.opacity(0.8), radius: 8, x: 0, y: 0)
                            
                                // 釜底抽薪之計：用 .background 將光暈畫在太陽後面
                                // .background 不會影響 Image 的佈局大小和位置
                                .padding(100)
                                .background(
                                    GlowView(color: .yellow, radius: 80)
                                )
                                .padding(-100)
                            
                                // 將動畫修飾符應用在太陽圖示上
                                .opacity(sunIconProgress)
                                .offset(y: 50 * (1.0 - sunIconProgress))
                        }
                    }
                    .opacity(showTopUI ? 1 : 0) // 控制整個右側區域的顯示與否
                }
                .frame(height: 90)

                alarmInfoView
                    .opacity(showTopUI ? (1.0 - fadeProgress) : 0)

                Spacer()
            }
            .padding(.horizontal, 37) // ✅ 確保水平 padding 只在這裡

            // --- 底部 UI (滑動區域或正常按鈕) ---
            ZStack {
                // 條件顯示：只有當鬧鐘觸發且動畫未完成時，才顯示滑動區域
                if showBottomAlarmUI && !isEventListPresented {
                    bottomSlidingView
                }
                    
                // 條件顯示：只有當使用者向上滑動成功後，才顯示任務列表
                if isEventListPresented {
                    eventListView
                    // 從底部滑入的動畫
                        .transition(.move(edge: .bottom))
                }

                // 條件顯示：非鬧鐘模式下顯示的正常UI
                if !showBottomAlarmUI {
                    VStack {
                        Spacer()
                        normalBottomUI
                    }
                }
            }
            .opacity(isSwipeUpAnimationCompleted ? 0 : 1)
        }
        // ✅ 頁面等級的修飾器，確認這裡沒有 .padding(.horizontal)
        .padding(.top, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationBarHidden(true)
        .onAppear(perform: onAppearActions)
        .onReceive(timer) { receivedTime in
            self.currentDate = receivedTime
        }
        .onChange(of: alarmStateManager.isAlarmTriggered) { isTriggered in
            withAnimation(.easeInOut) {
                showBottomAlarmUI = isTriggered
            }
        }
        .preferredColorScheme(.dark)
    }
    
    struct GlowView: View {
        // MARK: - 屬性
        var color: Color
        var radius: CGFloat

        // MARK: - Body
        var body: some View {
            ZStack {
                // 我們用多個不同大小和透明度的圓形疊加
                // 來創造有層次感的光源
                
                // 最外層，最大最透明
                Circle()
                    .fill(color)
                    .frame(width: radius * 2)
                    .opacity(0.4)
                
                // 中間層
                Circle()
                    .fill(color)
                    .frame(width: radius * 1.5)
                    .opacity(0.6)

                // 最內層，最小最亮
                Circle()
                    .fill(color)
                    .frame(width: radius)
                    .opacity(1.0)
            }
            // 這是關鍵：對整個 ZStack 進行一次高品質的高斯模糊
            // 效果會比 shadow 更柔和自然
            .blur(radius: radius / 3)
            // 使用 compositingGroup 可以優化模糊效果的渲染性能
            .compositingGroup()
        }
    }
    
    // MARK: - Subviews
    private var backgroundView: some View {
        Color.black.ignoresSafeArea()
    }
    
    

    private var topDateView: some View {
        VStack(spacing: 0) {
            HStack(alignment: .lastTextBaseline, spacing: 5) {
                Text(simulatedCurrentTime, formatter: topDateMonthDayFormatter)
                    .font(Font.custom("Instrument Sans", size: 17.31818).weight(.bold))
                Text(simulatedCurrentTime, formatter: topDateDayOfWeekFormatter)
                    .font(Font.custom("Instrument Sans", size: 17.31818).weight(.bold))
                    .foregroundColor(.gray)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "sun.max.fill").foregroundColor(.yellow)
                    Text("26℃").font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
            }
            
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(red: 0.34, green: 0.34, blue: 0.34))
                .padding(.vertical, 12)
        }
    }
    
    private var alarmInfoView: some View {
        HStack {
            Image(systemName: "bell")
                .font(.system(size: 16))
                .foregroundColor(.gray)
            Text(alarmTimeString)
                .font(Font.custom("Inria Sans", size: 16).weight(.light))
                .foregroundColor(.gray)
        }
        .padding(.top, 8)
    }
    
    private var bottomSlidingView: some View {
        ZStack(alignment: .bottom) {
//            Color.black.opacity(backgroundDimming)
//                .ignoresSafeArea()
            
            eventListView
                .offset(y: eventListHeight > 0 ? 0 : UIScreen.main.bounds.height)

            VStack(spacing: 10) {
                Image(systemName: "chevron.up").font(.system(size: 24, weight: .bold))
                Text("Stop").font(Font.custom("Inria Sans", size: 20).weight(.bold))
            }
            .foregroundColor(.gray)
            .padding(.bottom, 40)
            .offset(y: -dragOffset)
            .opacity(1.0 - (eventListHeight / maxDragHeight))
            .gesture(dragGesture)
        }
        .opacity(isSwipeUpAnimationCompleted ? 0 : 1)
        .ignoresSafeArea()
    }
    
    private var normalBottomUI: some View {
        VStack {
            VStack(spacing: 20) {
                HStack(spacing: 15) {
                    Image(systemName: "moon.fill").font(.system(size: 20)).foregroundColor(.white.opacity(0.9))
                        .shadow(color: .white.opacity(0.4), radius: 25, x: 0, y: 0)
                        .shadow(color: .white.opacity(0.7), radius: 15, x: 0, y: 0)
                        .shadow(color: .white, radius: 7, x: 0, y: 0)
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle().foregroundColor(Color.gray.opacity(0.35))
                            Rectangle()
                                .frame(width: max(0, geometry.size.width * CGFloat(alarmStateManager.sleepProgress)))
                                .foregroundColor(.white)
                        }
                        .cornerRadius(2).clipped()
                    }
                    .frame(height: 4)

                    Image(systemName: "bell.and.waves.left.and.right").font(.system(size: 16)).foregroundColor(.gray)
                    Text(alarmTimeString)
                        .font(Font.custom("Inria Sans", size: 18.62571).weight(.light))
                        .multilineTextAlignment(.center).foregroundColor(.gray)
                }
                .padding(.horizontal, 20).padding(.top, 20)
                
                Button(action: {
                    alarmStateManager.startSleepMode(alarmTime: alarmTimeString)
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("back to home page")
                        .font(Font.custom("Inria Sans", size: 20).weight(.bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                }
                .frame(height: 60)
                .background(Color(white: 0.35, opacity: 0.9))
                .cornerRadius(30)
                .padding(.horizontal, 20).padding(.bottom, 20)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 32).fill(Color.white.opacity(0.15)))
            .padding(.bottom, 30)
            .padding(.horizontal)
        }
    }
    
//    private var sunriseBackgroundView: some View {
//        GeometryReader { geometry in
//            let dragProgress = min(max(dragOffset, 0), maxDragHeight) / maxDragHeight
//            let startX = geometry.size.width * 0.9, startY = geometry.size.height * 0.9
//            let endX = geometry.size.width * 0.75, endY = geometry.size.height * 0.3
//            let currentX = startX + (endX - startX) * dragProgress
//            let currentY = startY + (endY - startY) * dragProgress
//            
//            ZStack {
//                Circle().fill(RadialGradient(gradient: Gradient(colors: [Color.orange.opacity(0.4 * dragProgress), Color.clear]), center: .center, startRadius: 20, endRadius: 120)).frame(width: 240, height: 240).blur(radius: 25)
//                Circle().fill(RadialGradient(gradient: Gradient(colors: [Color.orange.opacity(0.6 * dragProgress), Color.clear]), center: .center, startRadius: 10, endRadius: 60)).frame(width: 120, height: 120).blur(radius: 15)
//                Circle().fill(RadialGradient(gradient: Gradient(colors: [Color.orange.opacity(0.8 * dragProgress), Color.clear]), center: .center, startRadius: 5, endRadius: 30)).frame(width: 60, height: 60).blur(radius: 8)
//            }
//            .position(x: currentX, y: currentY)
//            .opacity(showBottomAlarmUI ? 1 : 0)
//        }
//        .allowsHitTesting(false)
//    }
    
    private var eventListView: some View {
        VStack(spacing: 0) {
            // --- 完整的毛玻璃區塊（從頂部延伸到底部） ---
            VStack(alignment: .leading, spacing: 0) {
                // 任務內容區域
                VStack(alignment: .leading, spacing: 25) {
                    // 頂部標題
                    HStack(alignment: .lastTextBaseline) {
                        Text("今天有")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                        Text("\(todayTodoItems.count) 個任務")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    
                    // 任務列表
                    VStack(spacing: 20) {
                        ForEach(todayTodoItems) { item in
                            EventItemView(
                                item: item,
                                title: item.title,
                                time: formatTaskTime(item.taskDate),
                                isImportant: item.priority >= 3 || item.isPinned,
                                onToggle: toggleTaskCompletion
                            )
                        }
                    }
                }
                
                Spacer() // 將按鈕推到毛玻璃區塊的底部
                
                // --- 開始今天按鈕（在毛玻璃區塊底部） ---
                Button(action: performSwipeUpAnimation) {
                    Text("開始今天")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.white)
                        .cornerRadius(32)
                }
            }
            .padding(30)
            .background(.ultraThinMaterial) // 單一毛玻璃背景包覆所有內容
            .cornerRadius(32)
            .padding(.horizontal, 20)
            .frame(maxHeight: .infinity) // 讓毛玻璃區塊延伸到可用空間
            .padding(.bottom, 50) // 底部安全距離
        }
        .padding(.top, 200)
    }
    
    // MARK: - Gestures
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let dragDistance = -value.translation.height
                dragOffset = max(0, dragDistance)
                backgroundDimming = min(max(0, dragDistance / maxDragHeight), 1) * 0.7
            }
            .onEnded { value in
                let dragDistance = -value.translation.height
                if dragDistance > dragThreshold {
                    // ✅ 當拖曳成功
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        eventListHeight = UIScreen.main.bounds.height
                        isEventListPresented = true // 👈 << 更新狀態，鎖定畫面
                        dragOffset = 0 // 現在可以安全地重設 dragOffset，因為透明度不再依賴它
//                        backgroundDimming = 0
                    }
                } else {
                    // 拖曳失敗，恢復原狀
                    withAnimation(.spring()) {
                        dragOffset = 0
//                        backgroundDimming = 0
                    }
                }
            }
    }
    
    // MARK: - Functions
    private func onAppearActions() {
        if let savedAlarmTime = UserDefaults.standard.string(forKey: "alarmTimeString") {
            alarmTimeString = savedAlarmTime
        }
        
        // 載入用戶名稱
        loadUserName()
        
        // 載入今天的待辦事項
        loadTodayTodoItems()
    }
    
    /// 格式化任務時間
    private func formatTaskTime(_ date: Date?) -> String {
        guard let date = date else { return "" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "Asia/Taipei")
        return formatter.string(from: date)
    }
    
    /// 載入今天的待辦事項
    private func loadTodayTodoItems() {
        let allItems = LocalDataManager.shared.getAllTodoItems()
        let today = Date()
        let calendar = Calendar.current
        
        // 篩選今天的任務，排除已完成的
        todayTodoItems = allItems.filter { item in
            // 檢查是否為今天的任務
            let isToday: Bool
            if let taskDate = item.taskDate {
                isToday = calendar.isDate(taskDate, inSameDayAs: today)
            } else {
                // 如果沒有設定日期，檢查創建日期是否為今天
                isToday = calendar.isDate(item.createdAt, inSameDayAs: today)
            }
            
            // 只顯示今天的且未完成的任務
            return isToday && item.status != .completed
        }
        .sorted { first, second in
            // 優先級高的在前
            if first.priority != second.priority {
                return first.priority > second.priority
            }
            // 置頂的在前
            if first.isPinned != second.isPinned {
                return first.isPinned
            }
            // 有時間的在前
            if (first.taskDate != nil) != (second.taskDate != nil) {
                return first.taskDate != nil
            }
            // 最後按時間排序
            if let firstTime = first.taskDate, let secondTime = second.taskDate {
                return firstTime < secondTime
            }
            return first.createdAt < second.createdAt
        }
    }
    
    /// 載入用戶名稱
    private func loadUserName() {
        // 先嘗試從 UserDefaults 獲取緩存的用戶名
        if let cachedName = UserDefaults.standard.string(forKey: "cachedUserName"), !cachedName.isEmpty {
            userName = cachedName.uppercased()
            return
        }
        
        // 如果沒有緩存，嘗試從 Apple ID 或 Google 登入信息獲取
        if let appleUserID = UserDefaults.standard.string(forKey: "appleAuthorizedUserId") {
            // Apple 登入用戶，嘗試從 CloudKit 獲取
            fetchUserNameFromCloudKit(userID: appleUserID, provider: "Apple")
        } else if let googleUserID = UserDefaults.standard.string(forKey: "googleAuthorizedUserId") {
            // Google 登入用戶，嘗試從 CloudKit 獲取
            fetchUserNameFromCloudKit(userID: googleUserID, provider: "Google")
        }
    }
    
    /// 從 CloudKit 獲取用戶名稱
    private func fetchUserNameFromCloudKit(userID: String, provider: String) {
        let privateDatabase = CKContainer(identifier: "iCloud.com.fcu.ToDolist1").privateCloudDatabase
        let predicate = NSPredicate(format: "providerUserID == %@ AND provider == %@", userID, provider)
        let query = CKQuery(recordType: "ApiUser", predicate: predicate)
        
        privateDatabase.perform(query, inZoneWith: nil) { records, error in
            DispatchQueue.main.async {
                if let records = records, let record = records.first {
                    if let name = record["name"] as? String, !name.isEmpty {
                        self.userName = name.uppercased()
                        // 緩存用戶名以供下次使用
                        UserDefaults.standard.set(name, forKey: "cachedUserName")
                    }
                } else {
                    print("無法獲取用戶名稱: \(error?.localizedDescription ?? "未知錯誤")")
                }
            }
        }
    }
    
    /// 切換任務完成狀態
    private func toggleTaskCompletion(_ item: TodoItem) {
        var updatedItem = item
        updatedItem.status = .completed
        updatedItem.updatedAt = Date()
        
        // 更新本地數據
        LocalDataManager.shared.updateTodoItem(updatedItem)
        
        // 重新加載今天的任務列表
        loadTodayTodoItems()
        
        // 觸發輕微震動反饋
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func performSwipeUpAnimation() {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) {
            showTopUI = false
            isSwipeUpAnimationCompleted = true
            eventListHeight = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            // 結束睡眠模式並回到一般模式的 home
            cancelSleepMode()
        }
    }
    
    /// 取消睡眠模式 - 完整重置所有狀態
    private func cancelSleepMode() {
        // 重置 AlarmStateManager 的狀態
        alarmStateManager.endSleepMode()
        alarmStateManager.resetAlarmState()
        
        // 重置本地 UI 狀態
        withAnimation(.easeInOut(duration: 0.3)) {
            showTopUI = true
            showBottomAlarmUI = false
            isSwipeUpAnimationCompleted = false
            isEventListPresented = false
            dragOffset = 0
            eventListHeight = 0
            backgroundDimming = 0.0
        }
        
        // 延遲一下確保動畫完成後再關閉畫面
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            presentationMode.wrappedValue.dismiss()
        }
        
        print("Sleep mode 已完全取消，所有狀態已重置")
    }

    // MARK: - Developer Mode & Other Functions
    #if DEBUG
    private func resetAnimationState() {
        withAnimation(.easeInOut(duration: 0.5)) {
            isSwipeUpAnimationCompleted = false
            showTopUI = true
            showBottomAlarmUI = false
            isEventListPresented = false
            dragOffset = 0
            eventListHeight = 0
            backgroundDimming = 0
        }
    }
    
    private func settingsMenuView() -> some View {
        Menu {
            Button(action: { showDeveloperMode.toggle() }) {
                Label(showDeveloperMode ? "隱藏開發者模式" : "顯示開發者模式", systemImage: "hammer")
            }
            if showDeveloperMode {
                Divider()
                Button(action: { timeOffset += 3600 }) { Label("時間+1小時", systemImage: "clock.arrow.circlepath") }
                Button(action: { timeOffset += 60 }) { Label("時間+1分鐘", systemImage: "clock") }
                Button(action: { 
                    resetAnimationState()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        alarmStateManager.triggerAlarm()
                    }
                }) { Label("模擬鬧鐘觸發", systemImage: "bell.circle.fill") }
                Button(action: { 
                    // 設定一個 5 秒後的真實鬧鐘測試
                    let content = UNMutableNotificationContent()
                    content.title = "🚨 真實鬧鐘測試"
                    content.body = "請先切到背景，5 秒後觸發"
                    content.sound = UNNotificationSound.default
                    
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
                    let request = UNNotificationRequest(identifier: "BackgroundTestAlarm", content: content, trigger: trigger)
                    
                    UNUserNotificationCenter.current().add(request) { error in
                        print(error != nil ? "❌ 背景測試失敗: \(error!)" : "✅ 5秒後背景鬧鐘已設定")
                    }
                }) { Label("5秒後背景鬧鐘", systemImage: "clock.badge.exclamationmark") }
                Button(action: { resetAnimationState() }) { Label("重置動畫狀態", systemImage: "arrow.clockwise") }
                Divider()
            }
            Button(role: .destructive, action: { 
                // 取消睡眠模式 - 完整重置所有狀態
                cancelSleepMode()
            }) {
                Label("取消 Sleep Mode", systemImage: "moon.slash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundColor(.white)
                .font(.system(size: 20))
        }
        .menuStyle(.automatic)
    }
    #else
    private func settingsMenuView() -> some View {
        Menu {
             Button(role: .destructive, action: { 
                // 取消睡眠模式 - 完整重置所有狀態
                cancelSleepMode()
            }) {
                Label("取消 Sleep Mode", systemImage: "moon.slash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundColor(.white)
                .font(.system(size: 20))
        }
        .menuStyle(.automatic)
    }
    #endif
    
    // MARK: - EventItemView
    private struct EventItemView: View {
        let item: TodoItem
        let title: String
        let time: String
        let isImportant: Bool
        let onToggle: (TodoItem) -> Void
        
        var body: some View {
            HStack(spacing: 15) {
                // 左側圓形勾選按鈕
                Button(action: {
                    onToggle(item)
                }) {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(Circle().stroke(Color.gray, lineWidth: 1.5))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(PlainButtonStyle())
                
                // 中間任務標題
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                // 右側重要性標記和時間
                HStack(spacing: 8) {
                    if isImportant {
                        Text("* *")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.yellow)
                    }
                    
                    if !time.isEmpty {
                        Text(time)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}


// MARK: - Preview
#Preview {
    struct PreviewWrapper: View {
        @StateObject private var alarmStateManager = AlarmStateManager()

        var body: some View {
            NavigationView {
                Sleep01View()
                    .environmentObject(alarmStateManager)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            self.alarmStateManager.triggerAlarm()
                        }
                    }
            }
        }
    }
    return PreviewWrapper()
}
