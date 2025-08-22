import SwiftUI
import UserNotifications

class AlarmStateManager: ObservableObject {
    @Published var isAlarmTriggered: Bool = false
    @Published var shouldNavigateToSleep01: Bool = false
    @Published var sleepProgress: Double = 0.0
    @Published var isSleepModeActive: Bool = false
    @Published var alarmTimeString: String = "9:00 AM"
    
    private var progressTimer: Timer?
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
    
    init() {
        // 檢查是否有待處理的鬧鐘通知
        checkPendingAlarms()
        
        // 載入睡眠模式狀態
        loadSleepModeState()
        
        // 開始進度計時器
        startProgressTimer()
    }
    
    func triggerAlarm() {
        DispatchQueue.main.async {
            self.isAlarmTriggered = true
            self.shouldNavigateToSleep01 = true
        }
    }
    
    func resetAlarmState() {
        DispatchQueue.main.async {
            self.isAlarmTriggered = false
            self.shouldNavigateToSleep01 = false
        }
    }
    
    func completeNavigation() {
        DispatchQueue.main.async {
            self.shouldNavigateToSleep01 = false
        }
    }
    
    private func checkPendingAlarms() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            // 檢查是否有鬧鐘通知
            let alarmRequests = requests.filter { request in
                request.identifier.contains("alarm") || request.identifier.contains("sleep")
            }
            
            if !alarmRequests.isEmpty {
                print("發現待處理的鬧鐘通知: \(alarmRequests.count) 個")
            }
        }
    }
    
    // 設定鬧鐘
    func scheduleAlarm(at time: Date, identifier: String = "sleep-alarm") {
        let content = UNMutableNotificationContent()
        content.title = "起床時間到了！"
        content.body = "新的一天開始了"
        content.sound = UNNotificationSound.default
        
        // 創建日期組件
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        
        // 設定觸發器
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("設定鬧鐘失敗: \(error)")
            } else {
                print("鬧鐘已設定為 \(time)")
            }
        }
    }
    
    // 取消所有鬧鐘
    func cancelAllAlarms() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("已取消所有鬧鐘")
    }
    
    // MARK: - 睡眠模式管理
    
    // 載入睡眠模式狀態
    private func loadSleepModeState() {
        let sleepModeExists = UserDefaults.standard.object(forKey: "isSleepMode") != nil
        isSleepModeActive = sleepModeExists && UserDefaults.standard.bool(forKey: "isSleepMode")
        
        if let savedAlarmTime = UserDefaults.standard.string(forKey: "alarmTimeString") {
            alarmTimeString = savedAlarmTime
        }
        
        print("AlarmStateManager初始化: sleepModeExists=\(sleepModeExists), isSleepModeActive=\(isSleepModeActive), alarmTime=\(alarmTimeString)")
        
        if isSleepModeActive {
            updateSleepProgress()
        }
    }
    
    // 啟動睡眠模式
    func startSleepMode(alarmTime: String) {
        DispatchQueue.main.async {
            self.isSleepModeActive = true
            self.alarmTimeString = alarmTime
            
            // 保存到UserDefaults
            UserDefaults.standard.set(true, forKey: "isSleepMode")
            UserDefaults.standard.set(alarmTime, forKey: "alarmTimeString")
            UserDefaults.standard.set(Date(), forKey: "sleepStartTime")
            
            // 立即更新進度
            self.updateSleepProgress()
            
            print("睡眠模式已啟動，鬧鐘時間: \(alarmTime)")
            
            // 發送狀態變更通知
            NotificationCenter.default.post(name: Notification.Name("SleepModeStateChanged"), object: nil)
        }
    }
    
    // 結束睡眠模式
    func endSleepMode() {
        DispatchQueue.main.async {
            self.isSleepModeActive = false
            self.sleepProgress = 0.0
            self.alarmTimeString = "9:00 AM" // 重置為默認值
            
            // 完全清除UserDefaults
            UserDefaults.standard.removeObject(forKey: "isSleepMode")
            UserDefaults.standard.removeObject(forKey: "sleepStartTime")
            UserDefaults.standard.removeObject(forKey: "alarmTimeString")
            
            print("睡眠模式已結束，所有設定已清除")
            
            // 發送狀態變更通知
            NotificationCenter.default.post(name: Notification.Name("SleepModeStateChanged"), object: nil)
        }
    }
    
    // 開始進度計時器
    private func startProgressTimer() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if self.isSleepModeActive {
                self.updateSleepProgress()
            }
        }
    }
    
    // 更新睡眠進度
    private func updateSleepProgress() {
        let currentTime = Date()
        var newProgress = 0.0
        
        guard let parsedAlarmTime = alarmStringParser.date(from: alarmTimeString) else {
            DispatchQueue.main.async {
                self.sleepProgress = 0.0
            }
            return
        }
        
        let alarmHourMinuteComponents = taipeiCalendar.dateComponents([.hour, .minute], from: parsedAlarmTime)
        guard let alarmHour = alarmHourMinuteComponents.hour,
              let alarmMinute = alarmHourMinuteComponents.minute else {
            DispatchQueue.main.async {
                self.sleepProgress = 0.0
            }
            return
        }

        var todayAlarmDateComponents = taipeiCalendar.dateComponents([.year, .month, .day], from: currentTime)
        todayAlarmDateComponents.hour = alarmHour
        todayAlarmDateComponents.minute = alarmMinute
        todayAlarmDateComponents.second = 0
        
        guard let alarmTimeOnCurrentDay = taipeiCalendar.date(from: todayAlarmDateComponents) else {
            DispatchQueue.main.async {
                self.sleepProgress = 0.0
            }
            return
        }

        // 獲取睡眠設定的開始時間
        let sleepStartTime: Date
        if let savedSleepStartTime = UserDefaults.standard.object(forKey: "sleepStartTime") as? Date {
            sleepStartTime = savedSleepStartTime
        } else {
            sleepStartTime = currentTime
            UserDefaults.standard.set(currentTime, forKey: "sleepStartTime")
        }
        
        // 計算最近的鬧鐘時間（可能是今天或明天）
        let todayAlarmTime = alarmTimeOnCurrentDay
        guard let tomorrowAlarmTime = taipeiCalendar.date(byAdding: .day, value: 1, to: alarmTimeOnCurrentDay) else {
            DispatchQueue.main.async {
                self.sleepProgress = 0.0
            }
            return
        }
        
        // 選擇最近的鬧鐘時間作為終點
        let cycleEnd: Date
        if currentTime <= todayAlarmTime {
            // 如果當前時間還沒到今天的鬧鐘時間，使用今天的鬧鐘時間
            cycleEnd = todayAlarmTime
            print("使用今天的鬧鐘時間作為終點: \(todayAlarmTime)")
        } else {
            // 如果已經過了今天的鬧鐘時間，使用明天的鬧鐘時間
            cycleEnd = tomorrowAlarmTime
            print("使用明天的鬧鐘時間作為終點: \(tomorrowAlarmTime)")
        }

        let totalCycleDuration = cycleEnd.timeIntervalSince(sleepStartTime)
        let elapsedInCycle = currentTime.timeIntervalSince(sleepStartTime)

        if totalCycleDuration > 0 {
            newProgress = elapsedInCycle / totalCycleDuration
        }
        
        DispatchQueue.main.async {
            self.sleepProgress = min(max(newProgress, 0.0), 1.0)
            
            // 詳細的調試信息
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            formatter.timeZone = TimeZone(identifier: "Asia/Taipei")
            
            print("=== AlarmStateManager 進度條更新 ===")
            print("當前時間: \(formatter.string(from: currentTime))")
            print("睡眠開始: \(formatter.string(from: sleepStartTime))")
            print("週期終點: \(formatter.string(from: cycleEnd))")
            print("總週期長度: \(String(format: "%.1f", totalCycleDuration/3600))小時")
            print("已經過時間: \(String(format: "%.1f", elapsedInCycle/3600))小時")
            print("進度百分比: \(String(format: "%.1f", self.sleepProgress * 100))%")
            print("===============================")
        }
    }
    
    // 強制重新載入狀態（用於調試和確保同步）
    func forceReloadState() {
        loadSleepModeState()
    }
    
    deinit {
        progressTimer?.invalidate()
    }
} 