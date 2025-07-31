import SwiftUI
import UserNotifications

struct Sleep01View: View {
    // MARK: - 屬性包裝器 & 狀態管理
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var alarmStateManager: AlarmStateManager
    
    // MARK: - 主要狀態變數
    @State private var currentDate = Date()
    @State private var alarmTimeString: String = "9:00 AM"
    @State private var navigateToHome: Bool = false
    @State private var dayProgress: Double = 0.5 // 用於鬧鐘未響時的進度條

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
        ZStack {
            backgroundView
            sunriseBackgroundView
            
            VStack(alignment: .leading, spacing: 0) {
                topDateView
                    .opacity(showTopUI ? 1 : 0)

                ZStack(alignment: .leading) {
                    Text(simulatedCurrentTime, formatter: timeFormatter)
                        .font(Font.custom("Inria Sans", size: 47.93416).weight(.bold))
                        .foregroundColor(showBottomAlarmUI && !isSwipeUpAnimationCompleted ? Color(red: 0, green: 0.72, blue: 0.41) : .white)
                        .opacity(showTopUI ? 1 : 0)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Good morning")
                            .font(Font.custom("Inria Sans", size: isSwipeUpAnimationCompleted ? 47.93416 : 32).weight(.bold))
                        Text("SHIRO")
                            .font(Font.custom("Inria Sans", size: isSwipeUpAnimationCompleted ? 24 : 18))
                    }
                    .foregroundColor(isSwipeUpAnimationCompleted ? Color(red: 0, green: 0.72, blue: 0.41) : .white)
                    .offset(y: isSwipeUpAnimationCompleted ? 0 : UIScreen.main.bounds.height * 0.5)
                    .opacity(isSwipeUpAnimationCompleted || (showBottomAlarmUI && eventListHeight == 0) ? 1 : 0)
                    
                    HStack {
                        Spacer()
                        settingsMenuView()
                    }
                    .opacity(showTopUI ? 1 : 0)
                }
                .frame(height: 90)

                alarmInfoView
                    .opacity(showTopUI ? 1 : 0)

                Spacer()
            }
            .padding(.horizontal, 37)

            ZStack {
                if showBottomAlarmUI {
                    bottomSlidingView
                } else {
                    VStack {
                        Spacer()
                        normalBottomUI
                    }
                }
            }
            .opacity(isSwipeUpAnimationCompleted ? 0 : 1)
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            NavigationLink(destination: Home().navigationBarHidden(true), isActive: $navigateToHome) { EmptyView() }
        )
        .navigationBarHidden(true)
        .onAppear(perform: onAppearActions)
        .onReceive(timer) { receivedTime in
            self.currentDate = receivedTime
            self.calculateDayProgress(currentTime: simulatedCurrentTime)
        }
        .onChange(of: alarmStateManager.isAlarmTriggered) { isTriggered in
            withAnimation(.easeInOut) {
                showBottomAlarmUI = isTriggered
            }
        }
        .preferredColorScheme(.dark)
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
            Color.black.opacity(backgroundDimming)
                .ignoresSafeArea()
            
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
                                .frame(width: max(0, geometry.size.width * CGFloat(dayProgress)))
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
                .padding(.horizontal, 20).padding(.bottom, 20)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 32).fill(Color.white.opacity(0.15)))
            .padding(.bottom, 30)
            .padding(.horizontal)
        }
    }
    
    private var sunriseBackgroundView: some View {
        GeometryReader { geometry in
            let dragProgress = min(max(dragOffset, 0), maxDragHeight) / maxDragHeight
            let startX = geometry.size.width * 0.9, startY = geometry.size.height * 0.9
            let endX = geometry.size.width * 0.75, endY = geometry.size.height * 0.3
            let currentX = startX + (endX - startX) * dragProgress
            let currentY = startY + (endY - startY) * dragProgress
            
            ZStack {
                Circle().fill(RadialGradient(gradient: Gradient(colors: [Color.orange.opacity(0.4 * dragProgress), Color.clear]), center: .center, startRadius: 20, endRadius: 120)).frame(width: 240, height: 240).blur(radius: 25)
                Circle().fill(RadialGradient(gradient: Gradient(colors: [Color.orange.opacity(0.6 * dragProgress), Color.clear]), center: .center, startRadius: 10, endRadius: 60)).frame(width: 120, height: 120).blur(radius: 15)
                Circle().fill(RadialGradient(gradient: Gradient(colors: [Color.orange.opacity(0.8 * dragProgress), Color.clear]), center: .center, startRadius: 5, endRadius: 30)).frame(width: 60, height: 60).blur(radius: 8)
            }
            .position(x: currentX, y: currentY)
            .opacity(showBottomAlarmUI ? 1 : 0)
        }
        .allowsHitTesting(false)
    }
    
    private var eventListView: some View {
        VStack {
            Spacer()
            VStack(spacing: 20) {
                HStack {
                    Text("今天有").font(.system(size: 16, weight: .medium)).foregroundColor(.gray)
                    Text("4 個任務").font(.system(size: 28, weight: .bold)).foregroundColor(.white)
                    Spacer()
                }
                .padding([.horizontal, .top], 30)
                
                VStack(spacing: 15) {
                    EventItemView(title: "完成設計提案初稿", time: "10:00", isImportant: true)
                    EventItemView(title: "Prepare tomorrow's meeting report", time: "", isImportant: false)
                    EventItemView(title: "整理桌面和文件夾", time: "", isImportant: false)
                    EventItemView(title: "寫一篇學習筆記", time: "", isImportant: false)
                }
                .padding(.horizontal, 30)
                
                Spacer()
                
                Button(action: performSwipeUpAnimation) {
                    Text("開始今天")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.white)
                        .cornerRadius(25)
                }
                .padding(.horizontal, 30).padding(.bottom, 50)
            }
            .frame(height: UIScreen.main.bounds.height * 0.6)
            .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial).environment(\.colorScheme, .dark))
        }
        .ignoresSafeArea()
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
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        eventListHeight = UIScreen.main.bounds.height
                        dragOffset = 0
                        backgroundDimming = 0
                    }
                } else {
                    withAnimation(.spring()) {
                        dragOffset = 0
                        backgroundDimming = 0
                    }
                }
            }
    }
    
    // MARK: - Functions
    private func onAppearActions() {
        if let savedAlarmTime = UserDefaults.standard.string(forKey: "alarmTimeString") {
            alarmTimeString = savedAlarmTime
        }
    }
    
    private func performSwipeUpAnimation() {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) {
            showTopUI = false
            isSwipeUpAnimationCompleted = true
            eventListHeight = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            alarmStateManager.resetAlarmState()
            showBottomAlarmUI = false
        }
    }
    
    private func calculateDayProgress(currentTime: Date) {
        // ... (這部分邏輯不變，保持原樣)
    }

    // MARK: - Developer Mode & Other Functions
    #if DEBUG
    private func resetAnimationState() {
        withAnimation(.easeInOut(duration: 0.5)) {
            isSwipeUpAnimationCompleted = false
            showTopUI = true
            showBottomAlarmUI = false
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
                Button(action: { alarmStateManager.triggerAlarm() }) { Label("模擬鬧鐘觸發", systemImage: "bell.circle.fill") }
                Button(action: { resetAnimationState() }) { Label("重置動畫狀態", systemImage: "arrow.clockwise") }
                Divider()
            }
            Button(role: .destructive, action: { /* cancel sleep mode */ }) {
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
             Button(role: .destructive, action: { /* cancel sleep mode */ }) {
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
        let title: String
        let time: String
        let isImportant: Bool
        
        var body: some View {
            HStack(spacing: 15) {
                Circle()
                    .fill(isImportant ? Color.white.opacity(0.3) : Color.clear)
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                    .frame(width: 12, height: 12)
                Text(title).font(.system(size: 16)).foregroundColor(.white)
                Spacer()
                if isImportant { HStack(spacing: 2) { Text("**").font(.system(size: 12)).foregroundColor(.yellow) } }
                Text(time).font(.system(size: 14)).foregroundColor(.gray)
            }
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
