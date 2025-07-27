import SwiftUI
import UserNotifications

class AlarmStateManager: ObservableObject {
    @Published var isAlarmTriggered: Bool = false
    @Published var shouldNavigateToSleep01: Bool = false
    
    init() {
        // 檢查是否有待處理的鬧鐘通知
        checkPendingAlarms()
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
} 