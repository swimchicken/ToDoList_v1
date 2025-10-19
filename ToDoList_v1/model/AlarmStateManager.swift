import SwiftUI
import UserNotifications

class AlarmStateManager: ObservableObject {
    @Published var isAlarmTriggered: Bool = false
    @Published var shouldNavigateToSleep01: Bool = false
    @Published var sleepProgress: Double = 0.0
    @Published var isSleepModeActive: Bool = false
    @Published var alarmTimeString: String = "9:00 AM"

    private var progressTimer: Timer?
    private var hasTriggeredAlarmToday: Bool = false // 防止同一天重複觸發通知
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
        // 防止重複觸發
        guard !hasTriggeredAlarmToday else {
            print("⏰ 今天已經觸發過鬧鐘，跳過重複觸發")
            return
        }

        hasTriggeredAlarmToday = true

        DispatchQueue.main.async {
            self.isAlarmTriggered = true
            self.shouldNavigateToSleep01 = true
        }

        // 先檢查並請求通知權限，然後發送通知
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("=== 通知權限狀態 ===")
            print("授權狀態: \(settings.authorizationStatus.rawValue)")
            print("聲音權限: \(settings.soundSetting.rawValue)")
            print("橫幅權限: \(settings.alertSetting.rawValue)")
            print("==================")
            
            if settings.authorizationStatus == .notDetermined {
                // 如果權限未確定，先請求權限
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    if granted {
                        print("✅ 通知權限已獲得")
                    } else {
                        print("❌ 通知權限被拒絕: \(error?.localizedDescription ?? "未知原因")")
                    }
                }
            } else if settings.authorizationStatus == .authorized {
                print("✅ 已有通知權限")
            } else {
                print("❌ 通知權限被拒絕或受限，狀態: \(settings.authorizationStatus)")
            }
        }
    }
    
    
    func resetAlarmState() {
        hasTriggeredAlarmToday = false
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
        // 嘗試使用自訂鬧鐘聲音，如果沒有則關閉聲音
        if Bundle.main.path(forResource: "alarm_sound", ofType: "caf") != nil {
            content.sound = UNNotificationSound(named: UNNotificationSoundName("alarm_sound.caf"))
        } else {
            content.sound = nil // 關閉預設通知聲音
        }
        
        // 創建日期組件
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        
        // 設定觸發器 - 改為不重複
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
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
        
        // Debug：檢查sleepStartTime的狀態
        let sleepStartTime = UserDefaults.standard.object(forKey: "sleepStartTime") as? Date
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "Asia/Taipei")

        print("AlarmStateManager初始化: sleepModeExists=\(sleepModeExists), isSleepModeActive=\(isSleepModeActive), alarmTime=\(alarmTimeString)")
        if let sleepStartTime = sleepStartTime {
            print("已保存的睡眠開始時間: \(formatter.string(from: sleepStartTime))")
        } else {
            print("未找到睡眠開始時間")
        }
        
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
        hasTriggeredAlarmToday = false
        DispatchQueue.main.async {
            self.isSleepModeActive = false
            self.sleepProgress = 0.0
            self.alarmTimeString = "9:00 AM" // 重置為默認值
            self.isAlarmTriggered = false
            self.shouldNavigateToSleep01 = false
            
            // 完全清除UserDefaults
            UserDefaults.standard.removeObject(forKey: "isSleepMode")
            UserDefaults.standard.removeObject(forKey: "sleepStartTime")
            UserDefaults.standard.removeObject(forKey: "alarmTimeString")
            
            print("睡眠模式已結束，所有設定已清除")
            
            // 發送狀態變更通知
            NotificationCenter.default.post(name: Notification.Name("SleepModeStateChanged"), object: nil)
            
            // 強制同步狀態 - 確保 UI 更新
            self.objectWillChange.send()
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

        // 獲取睡眠設定的開始時間（鬧鐘設定的瞬間）
        // 這個時間應該在睡眠模式啟動時就已經設定好，不應該在這裡重新設定
        guard let sleepStartTime = UserDefaults.standard.object(forKey: "sleepStartTime") as? Date else {
            print("警告：沒有找到睡眠開始時間，進度條無法計算")
            DispatchQueue.main.async {
                self.sleepProgress = 0.0
            }
            return
        }

        // 計算離當前時間最近的鬧鐘時間點
        let todayAlarmDateComponents = taipeiCalendar.dateComponents([.year, .month, .day], from: currentTime)
        var targetAlarmDateComponents = todayAlarmDateComponents
        targetAlarmDateComponents.hour = alarmHour
        targetAlarmDateComponents.minute = alarmMinute
        targetAlarmDateComponents.second = 0

        guard let todayAlarmTime = taipeiCalendar.date(from: targetAlarmDateComponents) else {
            DispatchQueue.main.async {
                self.sleepProgress = 0.0
            }
            return
        }

        // 決定使用今天還是明天的鬧鐘時間
        let targetAlarmTime: Date
        if todayAlarmTime <= sleepStartTime {
            // 如果今天的鬧鐘時間在睡眠開始時間之前或相等，使用明天的鬧鐘時間
            guard let tomorrowAlarmTime = taipeiCalendar.date(byAdding: .day, value: 1, to: todayAlarmTime) else {
                DispatchQueue.main.async {
                    self.sleepProgress = 0.0
                }
                return
            }
            targetAlarmTime = tomorrowAlarmTime
        } else {
            // 使用今天的鬧鐘時間
            targetAlarmTime = todayAlarmTime
        }

        // 計算鬧鐘時間和進度
        if currentTime >= targetAlarmTime {
            // 如果已經到了或過了鬧鐘時間，進度設為100%
            newProgress = 1.0
            print("⏰ 鬧鐘時間已到，設定進度為100%")
        } else {
            // 如果還沒到鬧鐘時間，計算正常進度
            let totalCycleDuration = targetAlarmTime.timeIntervalSince(sleepStartTime)
            let elapsedInCycle = currentTime.timeIntervalSince(sleepStartTime)

            if totalCycleDuration > 0 {
                newProgress = elapsedInCycle / totalCycleDuration
            }
        }

        DispatchQueue.main.async {
            self.sleepProgress = min(max(newProgress, 0.0), 1.0)

            // 詳細的調試信息
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            formatter.timeZone = TimeZone(identifier: "Asia/Taipei")

            print("=== 統一進度條邏輯 - AlarmStateManager ===")
            print("當前時間: \(formatter.string(from: currentTime))")
            print("睡眠開始: \(formatter.string(from: sleepStartTime))")
            print("目標鬧鐘: \(formatter.string(from: targetAlarmTime))")

            if currentTime >= targetAlarmTime {
                print("鬧鐘已響起，進度: 100%")
            } else {
                let totalDuration = targetAlarmTime.timeIntervalSince(sleepStartTime)
                let elapsed = currentTime.timeIntervalSince(sleepStartTime)
                print("總時長: \(String(format: "%.1f", totalDuration/3600))小時")
                print("已過時間: \(String(format: "%.1f", elapsed/3600))小時")
                print("進度: \(String(format: "%.1f", self.sleepProgress * 100))%")
            }
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