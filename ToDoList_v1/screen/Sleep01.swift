import SwiftUI
import UserNotifications

struct Sleep01View: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var alarmStateManager: AlarmStateManager
    @State private var currentDate = Date()
    @State private var dayProgress: Double = 0.5 // 初始值設為0.5，確保有進度
    @State private var isAlarmTimePassedToday: Bool = false
    @State private var navigateToHome: Bool = false

    @State private var alarmTimeString: String = "9:00 AM" // 改為State變量以便更新
    
    // MARK: - 鬧鐘觸發動畫狀態
    @State private var isSwipeUpCompleted: Bool = false
    @State private var goodMorningOffset: CGFloat = 0
    @State private var showTimeAndAlarm: Bool = true
    
    // MARK: - 新增動畫狀態變數
    @State private var timeScale: CGFloat = 1.0
    @State private var timeOpacity: Double = 1.0
    @State private var alarmIconScale: CGFloat = 1.0
    @State private var stopButtonScale: CGFloat = 1.0
    @State private var sunriseOpacity: Double = 0.0
    @State private var pulseAnimation: Bool = false
    
    // MARK: - Stop按鈕動畫狀態
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var eventListHeight: CGFloat = 0
    @State private var blurIntensity: Double = 0.0
    @State private var stopButtonOpacity: Double = 1.0
    @State private var backgroundDimming: Double = 0.0
    
    // MARK: - 開發者模式相關變數
    #if DEBUG
    @State private var timeOffset: TimeInterval = 0 // 時間偏移（秒）
    @State private var showDeveloperMode: Bool = false
    #endif

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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
    
    private var topDateMonthDayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return formatter
    }

    private var topDateDayOfWeekFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return formatter
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"
        formatter.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return formatter
    }
    
    // MARK: - 開發者模式時間模擬
    private var simulatedCurrentTime: Date {
        #if DEBUG
        return currentDate.addingTimeInterval(timeOffset)
        #else
        return currentDate
        #endif
    }

    var body: some View {
        ZStack {
            backgroundView
            
            // 分隔線以上的內容 - 完全固定
            VStack(alignment: .leading, spacing: 0) {
                if showTimeAndAlarm {
                    topDateView
                }
                
                timeDisplayArea
                
                if showTimeAndAlarm {
                    alarmInfoView
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .zIndex(3)
            
            // 分隔線以下的動態內容
            dynamicContentView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .background(
            NavigationLink(
                destination: Home()
                    .navigationBarHidden(true)
                    .navigationBarBackButtonHidden(true)
                    .toolbar(.hidden, for: .navigationBar),
                isActive: $navigateToHome,
                label: { EmptyView() }
            )
            .isDetailLink(false)
        )
        .onAppear {
            onAppearActions()
        }
        .onReceive(timer) { receivedTime in
            self.currentDate = receivedTime
            calculateDayProgress(currentTime: simulatedCurrentTime)
        }
        .onChange(of: alarmStateManager.isAlarmTriggered) { isTriggered in
            if isTriggered {
                startAlarmAnimation()
            } else {
                resetAlarmAnimation()
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - 背景視圖
    private var backgroundView: some View {
        Color.black.ignoresSafeArea()
    }
    
    // MARK: - 頂部日期視圖
    private var topDateView: some View {
        VStack(spacing: 0) {
            HStack(alignment: .lastTextBaseline, spacing: 5) {
                Text(simulatedCurrentTime, formatter: topDateMonthDayFormatter)
                    .font(Font.custom("Instrument Sans", size: 17.31818).weight(.bold))
                    .foregroundColor(.white)
                Text(simulatedCurrentTime, formatter: topDateDayOfWeekFormatter)
                    .font(Font.custom("Instrument Sans", size: 17.31818).weight(.bold))
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding(.horizontal, 37).padding(.top, 15)
            
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(red: 0.34, green: 0.34, blue: 0.34))
                .padding(.vertical, 12)
        }
    }
    
    // MARK: - 時間顯示區域
    private var timeDisplayArea: some View {
        HStack {
            if showTimeAndAlarm {
                Text(simulatedCurrentTime, formatter: timeFormatter)
                    .font(Font.custom("Inria Sans", size: 47.93416).weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(alarmStateManager.isAlarmTriggered ? Color(red: 0, green: 0.72, blue: 0.41) : .white)
            }
            
            // Good Morning 文字（動畫時顯示）
            if !showTimeAndAlarm {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Good morning")
                        .font(Font.custom("Inria Sans", size: 47.93416).weight(.bold))
                        .foregroundColor(Color(red: 0, green: 0.72, blue: 0.41))
                    Text("SHIRO") // 這裡之後可以改為動態用戶名
                        .font(Font.custom("Inria Sans", size: 24))
                        .foregroundColor(.white)
                }
            }
            Spacer()
            
            sunriseEffectView
            settingsMenuView
        }
        .padding(.leading, 37)
    }
    
    // MARK: - 日出效果視圖
    private var sunriseEffectView: some View {
        Group {
            if alarmStateManager.isAlarmTriggered && !isSwipeUpCompleted {
                VStack {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.yellow)
                        .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                        .opacity(sunriseOpacity)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulseAnimation)
                    
                    // 日出光線效果
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.orange.opacity(0.3), Color.clear]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 60, height: 40)
                        .opacity(sunriseOpacity * 0.5)
                }
            }
        }
    }
    
    // MARK: - 設置菜單視圖
    private var settingsMenuView: some View {
        Menu {
            #if DEBUG
            Button(action: {
                showDeveloperMode.toggle()
            }) {
                Label(showDeveloperMode ? "隱藏開發者模式" : "顯示開發者模式", systemImage: "hammer")
            }
            
            if showDeveloperMode {
                Divider()
                
                Button(action: {
                    timeOffset += 3600 // 前進1小時
                }) {
                    Label("時間+1小時", systemImage: "clock.arrow.circlepath")
                }
                
                Button(action: {
                    timeOffset += 60 // 前進1分鐘
                }) {
                    Label("時間+1分鐘", systemImage: "clock")
                }
                
                Button(action: {
                    setAlarmToOneMinuteFromNow()
                }) {
                    Label("鬧鐘1分鐘後響", systemImage: "alarm")
                }
                
                Button(action: {
                    testAlarmNow()
                }) {
                    Label("立即測試鬧鐘", systemImage: "bell.badge")
                }
                
                Button(action: {
                    alarmStateManager.triggerAlarm()
                }) {
                    Label("模擬鬧鐘觸發", systemImage: "bell.circle.fill")
                }
                
                Button(action: {
                    timeOffset = 0
                }) {
                    Label("重置時間", systemImage: "arrow.counterclockwise")
                }
                
                Button(action: {
                    alarmStateManager.resetAlarmState()
                }) {
                    Label("重置鬧鐘狀態", systemImage: "xmark.circle")
                }
                
                Button(action: {
                    performSwipeUpAnimation()
                }) {
                    Label("測試滑動動畫", systemImage: "arrow.up.circle")
                }
                
                Button(action: {
                    resetAnimationState()
                }) {
                    Label("重置動畫狀態", systemImage: "arrow.clockwise")
                }
                
                Divider()
            }
            #endif
            
            Button(role: .destructive, action: {
                cancelSleepMode()
            }) {
                Label("取消 Sleep Mode", systemImage: "moon.slash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundColor(.white)
                .font(.system(size: 20))
                .padding(.trailing, 10)
        }
        .menuStyle(.automatic)
        .preferredColorScheme(.dark)
    }
    
    // MARK: - 鬧鐘信息視圖
    private var alarmInfoView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "bell.and.waves.left.and.right")
                    .font(.system(size: 18))
                    .foregroundColor(.gray)
                Text(alarmTimeString)
                    .font(Font.custom("Inria Sans", size: 18.62571).weight(.light))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
            }
            
            #if DEBUG
            if showDeveloperMode && timeOffset != 0 {
                HStack(spacing: 8) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 14)).foregroundColor(.orange)
                    Text("開發模式: 時間偏移 \(formatTimeOffset(timeOffset))")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                }
            }
            #endif
        }
        .padding(.leading, 40)
        .padding(.top, 8)
    }
    
    // MARK: - Good Morning 文字視圖
    private var goodMorningTextView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("Good morning")
                    .font(Font.custom("Inria Sans", size: 32).weight(.bold))
                    .foregroundColor(Color(red: 0, green: 0.72, blue: 0.41))
                Text("SHIRO") // 可以改為動態用戶名
                    .font(Font.custom("Inria Sans", size: 18))
                    .foregroundColor(.white)
            }
            .offset(y: goodMorningOffset)
            Spacer()
        }
        .padding(.leading, 40)
        .padding(.bottom, 150)
    }
    
    // MARK: - 底部區域視圖
    private var bottomAreaView: some View {
        Group {
            if alarmStateManager.isAlarmTriggered && !isSwipeUpCompleted {
                alarmTriggeredBottomUI
            } else if !alarmStateManager.isAlarmTriggered {
                normalBottomUI
            }
        }
    }
    
    // MARK: - 動態內容視圖（分隔線以下）
    private var dynamicContentView: some View {
        VStack {
            Spacer()
            
            if alarmStateManager.isAlarmTriggered && !isSwipeUpCompleted {
                goodMorningTextView
            }
            
            // 額外空間讓stop按鈕位置更靠下
            Spacer()
                .frame(minHeight: 150) // 增加到150讓stop按鈕更靠下
            
            bottomAreaView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .zIndex(1)
    }
    
    // MARK: - onAppear 處理方法
    private func onAppearActions() {
        // 從UserDefaults讀取保存的鬧鐘時間
        if let savedAlarmTime = UserDefaults.standard.string(forKey: "alarmTimeString") {
            alarmTimeString = savedAlarmTime
        }
        
        // 立即計算進度條
        calculateDayProgress(currentTime: simulatedCurrentTime)
        
        // 短暫延遲後再次計算，確保視圖已完全加載
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            calculateDayProgress(currentTime: simulatedCurrentTime)
        }
        
        // 如果是因為鬧鐘觸發而導航到這裡，標記導航完成
        if alarmStateManager.shouldNavigateToSleep01 {
            print("✅ Sleep01 頁面已載入，標記導航完成")
            alarmStateManager.completeNavigation()
        }
        
        // 鬧鐘觸發時的動畫效果
        if alarmStateManager.isAlarmTriggered {
            startAlarmAnimation()
        }
    }
    
    // MARK: - 鬧鐘觸發時的底部UI
    private var alarmTriggeredBottomUI: some View {
        ZStack {
            // 局部背景變暗效果（只影響底部區域）
            Rectangle()
                .fill(Color.black.opacity(backgroundDimming))
                .animation(.easeInOut(duration: 0.3), value: backgroundDimming)
                .allowsHitTesting(false)
            
            VStack(spacing: 0) {
                        // 可拉動的Stop區塊
                        VStack(spacing: 10) {
                            
                            VStack(spacing: 10) {
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Stop")
                                    .font(Font.custom("Inria Sans", size: 20).weight(.bold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                        }
                        .frame(maxWidth: .infinity)
                        .offset(y: -dragOffset)
                        .opacity(stopButtonOpacity)
                        .scaleEffect(isDragging ? 1.05 : 1.0)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isDragging = true
                                    // 限制只能向上拉動，最大拉動距離為350
                                    let dragDistance = -value.translation.height
                                    let newOffset = max(0, min(350, dragDistance))
                                    dragOffset = newOffset
                                    
                                    // 根據拉動距離計算各種效果
                                    let progress = newOffset / 350
                                    eventListHeight = newOffset
                                    blurIntensity = progress * 30
                                    // Stop按鈕隨著拉動逐漸消失，從50%拉動距離開始消失
                                    if progress < 0.5 {
                                        stopButtonOpacity = 1.0
                                    } else {
                                        stopButtonOpacity = 1.0 - ((progress - 0.5) * 2.0)
                                    }
                                    backgroundDimming = progress * 0.6
                                    
                                    // 觸覺反饋
                                    if newOffset > 100 && !isDragging {
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                        impactFeedback.impactOccurred()
                                    }
                                }
                                .onEnded { value in
                                    let dragDistance = -value.translation.height
                                    let finalOffset = max(0, min(350, dragDistance))
                                    
                                    if finalOffset > 175 { // 拉動超過一半距離
                                        // 完全展開到頂部
                                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                            dragOffset = 350
                                            eventListHeight = 350
                                            blurIntensity = 30
                                            stopButtonOpacity = 0.0 // 完全消失
                                            backgroundDimming = 0.6
                                        }
                                        
                                        // 觸覺反饋
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                        impactFeedback.impactOccurred()
                                        
                                    } else {
                                        // 回到原位
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            dragOffset = 0
                                            eventListHeight = 0
                                            blurIntensity = 0
                                            stopButtonOpacity = 1.0
                                            backgroundDimming = 0
                                        }
                                    }
                                    
                                    isDragging = false
                                }
                        )
                        
                        // 事件列表區塊（根據拉動距離顯示）
                        if eventListHeight > 0 {
                            VStack(spacing: 20) {
                                // 事件列表標題
                                HStack {
                                    Text("今日行程")
                                        .font(Font.custom("Inria Sans", size: 18).weight(.bold))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("4 個任務")
                                        .font(Font.custom("Inria Sans", size: 14))
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                                
                                // 事件項目列表（有動畫效果）
                                VStack(spacing: 15) {
                                    ForEach(Array([
                                        ("完成設計提案初稿", "10:00", true),
                                        ("Prepare tomorrow's meeting report", "14:30", false),
                                        ("整理桌面和文件夾", "16:00", false),
                                        ("寫一篇學習筆記", "18:00", false)
                                    ].enumerated()), id: \.offset) { index, item in
                                        EventItemView(title: item.0, time: item.1, isImportant: item.2)
                                            .opacity(eventListHeight > CGFloat(50 + index * 30) ? 1.0 : 0.0)
                                            .offset(y: eventListHeight > CGFloat(50 + index * 30) ? 0 : 20)
                                            .animation(
                                                .easeOut(duration: 0.3)
                                                .delay(Double(index) * 0.1),
                                                value: eventListHeight
                                            )
                                    }
                                }
                                .padding(.horizontal, 20)
                                
                                // 開始今天的按鈕
                                Button(action: {
                                    // 觸覺反饋
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                                    impactFeedback.impactOccurred()
                                    
                                    performSwipeUpAnimation()
                                }) {
                                    Text("開始今天")
                                        .font(Font.custom("Inria Sans", size: 18).weight(.bold))
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .background(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.white, Color.white.opacity(0.9)]),
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .cornerRadius(25)
                                        .shadow(color: .white.opacity(0.3), radius: 8, x: 0, y: 2)
                                }
                                .scaleEffect(eventListHeight > 250 ? 1.0 : 0.8)
                                .opacity(eventListHeight > 250 ? 1.0 : 0.0)
                                .animation(.easeOut(duration: 0.4).delay(0.3), value: eventListHeight)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                            }
                            .background(
                                ZStack {
                                    // 主要毛玻璃背景
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(.ultraThinMaterial)
                                        .environment(\.colorScheme, .dark)
                                    
                                    // 額外的毛玻璃層
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.white.opacity(0.1),
                                                    Color.clear,
                                                    Color.black.opacity(0.2)
                                                ]),
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                    
                                    // 邊框效果
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.white.opacity(0.4),
                                                    Color.white.opacity(0.1),
                                                    Color.clear
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                }
                            )
                            .frame(height: eventListHeight)
                            .clipped()
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
            }
        }
    
    // MARK: - 正常狀態的底部UI
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
                                .frame(width: max(0, geometry.size.width * CGFloat(dayProgress)))
                                .foregroundColor(.white)
                        }
                        .cornerRadius(2)
                        .clipped()
                    }
                    .frame(height: 4)

                    Image(systemName: "bell.and.waves.left.and.right").font(.system(size: 16)).foregroundColor(.gray)
                    Text(alarmTimeString)
                        .font(Font.custom("Inria Sans", size: 18.62571).weight(.light))
                        .multilineTextAlignment(.center).foregroundColor(.gray)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Button(action: {
                    UserDefaults.standard.set(true, forKey: "isSleepMode")
                    UserDefaults.standard.set(alarmTimeString, forKey: "alarmTimeString")
                    navigateToHome = true
                }) {
                    Text("back to home page")
                        .font(Font.custom("Inria Sans", size: 20).weight(.bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                }
                .frame(height: 60)
                .background(Color(white: 0.35, opacity: 0.9))
                .cornerRadius(30)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 32).fill(Color.white.opacity(0.15)))
            .padding(.bottom, 30)
        }
    }
    
    // MARK: - 鬧鐘動畫效果
    private func startAlarmAnimation() {
        // 只保留日出效果動畫，移除所有會影響分隔線以上內容的動畫
        withAnimation(.easeInOut(duration: 1.0)) {
            sunriseOpacity = 1.0
            pulseAnimation = true
        }
    }
    
    private func resetAlarmAnimation() {
        withAnimation(.easeInOut(duration: 0.3)) {
            // 只重置拖動相關的狀態，不影響分隔線以上的內容
            sunriseOpacity = 0.0
            pulseAnimation = false
            dragOffset = 0
            eventListHeight = 0
            isDragging = false
            blurIntensity = 0.0
            stopButtonOpacity = 1.0
            backgroundDimming = 0.0
        }
    }
    
    // MARK: - 開發者模式測試功能
    #if DEBUG
    private func formatTimeOffset(_ offset: TimeInterval) -> String {
        let hours = Int(offset) / 3600
        let minutes = (Int(offset) % 3600) / 60
        if hours > 0 {
            return "+\(hours)小時 \(minutes)分鐘"
        } else {
            return "+\(minutes)分鐘"
        }
    }
    
    private func setAlarmToOneMinuteFromNow() {
        // 取消現有鬧鐘
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // 設定1分鐘後的鬧鐘
        let content = UNMutableNotificationContent()
        content.title = "測試鬧鐘 (開發模式)"
        content.body = "1分鐘測試鬧鐘響了！"
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
        let request = UNNotificationRequest(identifier: "test-alarm-1min", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("設定測試鬧鐘失敗: \(error)")
            } else {
                print("測試鬧鐘已設定為1分鐘後響起")
            }
        }
    }
    
    private func testAlarmNow() {
        // 立即觸發測試通知
        let content = UNMutableNotificationContent()
        content.title = "立即測試鬧鐘"
        content.body = "這是立即觸發的測試通知"
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "test-alarm-now", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("立即測試鬧鐘失敗: \(error)")
            } else {
                print("立即測試鬧鐘已觸發")
            }
        }
    }
    #endif
    

    
    // MARK: - 滑動動畫功能
    private func performSwipeUpAnimation() {
        withAnimation(.easeInOut(duration: 1.0)) {
            // 隱藏時間和鬧鐘相關 UI
            showTimeAndAlarm = false
            
            // 將 good morning 文字向上移動到時間位置
            goodMorningOffset = -300
            
            // 標記滑動完成
            isSwipeUpCompleted = true
        }
        
        // 重置鬧鐘觸發狀態
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            alarmStateManager.resetAlarmState()
        }
    }
    
    #if DEBUG
    private func resetAnimationState() {
        withAnimation(.easeInOut(duration: 0.5)) {
            isSwipeUpCompleted = false
            goodMorningOffset = 0
            showTimeAndAlarm = true
            dragOffset = 0
            eventListHeight = 0
            isDragging = false
            blurIntensity = 0.0
            stopButtonOpacity = 1.0
            backgroundDimming = 0.0
        }
    }
    #endif
    
    // MARK: - 取消 Sleep Mode 功能
    private func cancelSleepMode() {
        // 取消所有通知鬧鐘
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // 清除 UserDefaults 中的相關設定
        UserDefaults.standard.removeObject(forKey: "isSleepMode")
        UserDefaults.standard.removeObject(forKey: "alarmTimeString")
        
        // 更新共享設定（如果有使用）
        if let sleepSettingsClass = NSClassFromString("ToDoList_v1.SettlementView03.SleepSettings") as? NSObject.Type {
            // 這裡我們嘗試重置共享設定，但由於架構限制，主要依賴 UserDefaults
        }
        
        print("已取消 Sleep Mode 並清除所有相關設定")
        
        // 導航回到 Home 頁面
        navigateToHome = true
    }
    
    // 提取進度條計算邏輯到獨立函數
    private func calculateDayProgress(currentTime: Date) {
        let calendar = self.taipeiCalendar
        let localAlarmStringParser = self.alarmStringParser
        var newProgress = 0.0

        guard let parsedAlarmTime = localAlarmStringParser.date(from: alarmTimeString) else {
            self.dayProgress = 0.0
            self.isAlarmTimePassedToday = false
            return
        }
        let alarmHourMinuteComponents = calendar.dateComponents([.hour, .minute], from: parsedAlarmTime)
        guard let alarmHour = alarmHourMinuteComponents.hour,
              let alarmMinute = alarmHourMinuteComponents.minute else {
            self.dayProgress = 0.0
            self.isAlarmTimePassedToday = false
            return
        }

        var todayAlarmDateComponents = calendar.dateComponents([.year, .month, .day], from: currentTime)
        todayAlarmDateComponents.hour = alarmHour
        todayAlarmDateComponents.minute = alarmMinute
        todayAlarmDateComponents.second = 0
        guard let alarmTimeOnCurrentDay = calendar.date(from: todayAlarmDateComponents) else {
            self.dayProgress = 0.0
            self.isAlarmTimePassedToday = false
            return
        }

        self.isAlarmTimePassedToday = currentTime >= alarmTimeOnCurrentDay
        
        let cycleStart: Date
        let cycleEnd: Date

        // 修改邏輯：進度條總是顯示到明天的鬧鐘時間
        guard let tomorrowAlarmTime = calendar.date(byAdding: .day, value: 1, to: alarmTimeOnCurrentDay) else {
            self.dayProgress = 0.0; return
        }
        
        if currentTime < alarmTimeOnCurrentDay {
            // 如果當前時間還沒到今天的鬧鐘時間，
            // 週期是從昨天的鬧鐘到明天的鬧鐘
            guard let yesterdayAlarmTime = calendar.date(byAdding: .day, value: -1, to: alarmTimeOnCurrentDay) else {
                self.dayProgress = 0.0; return
            }
            cycleStart = yesterdayAlarmTime
            cycleEnd = tomorrowAlarmTime
        } else {
            // 如果當前時間已經超過今天的鬧鐘時間，
            // 週期是從今天的鬧鐘到明天的鬧鐘
            cycleStart = alarmTimeOnCurrentDay
            cycleEnd = tomorrowAlarmTime
        }

        let totalCycleDuration = cycleEnd.timeIntervalSince(cycleStart)
        let elapsedInCycle = currentTime.timeIntervalSince(cycleStart)

        if totalCycleDuration > 0 {
            newProgress = elapsedInCycle / totalCycleDuration
        }
        
        self.dayProgress = min(max(newProgress, 0.0), 1.0)
        print("Sleep01 - dayProgress updated: \(self.dayProgress)")
    }
    
    // MARK: - EventItemView 組件
    private struct EventItemView: View {
        let title: String
        let time: String
        let isImportant: Bool
        
        var body: some View {
            HStack(spacing: 12) {
                // 圓形指示器
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 8, height: 8)
                
                // 任務標題
                Text(title)
                    .font(Font.custom("Inria Sans", size: 16))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                // 重要標記
                if isImportant {
                    HStack(spacing: 2) {
                        Text("**")
                            .font(.system(size: 12))
                            .foregroundColor(.yellow)
                    }
                }
                
                // 時間
                Text(time)
                    .font(Font.custom("Inria Sans", size: 14))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }
}

#Preview {
    // For the preview to work, you might need a mock environment object.
    struct PreviewWrapper: View {
        @StateObject private var alarmStateManager = AlarmStateManager()

        var body: some View {
            NavigationView {
                Sleep01View()
                    .environmentObject(alarmStateManager)
            }
        }
    }
    return PreviewWrapper()
}
