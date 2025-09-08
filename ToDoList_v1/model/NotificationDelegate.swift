import SwiftUI
import UserNotifications

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    static let shared = NotificationDelegate()
    
    private override init() {
        super.init()
    }
    
    // 當應用在前景時收到通知
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("🔔 收到前景通知: \(notification.request.identifier)")
        print("   標題: \(notification.request.content.title)")
        print("   內容: \(notification.request.content.body)")
        
        // 檢查是否是鬧鐘通知
        let isAlarmNotification = notification.request.identifier.lowercased().contains("alarm") || notification.request.identifier == "DailyAlarm"
        print("   是否為鬧鐘通知: \(isAlarmNotification)")
        
        if isAlarmNotification {
            print("   觸發鬧鐘處理邏輯")
            handleAlarmNotification()
        }
        
        // 顯示通知 (聲音 + 橫幅)
        print("   準備顯示通知 (橫幅 + 聲音)")
        completionHandler([.banner, .sound])
    }
    
    // 當用戶點擊通知時
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print("用戶點擊通知: \(response.notification.request.identifier)")
        
        // 檢查是否是鬧鐘通知
        if response.notification.request.identifier.lowercased().contains("alarm") || response.notification.request.identifier == "DailyAlarm" {
            handleAlarmNotification()
        }
        
        completionHandler()
    }
    
    // 處理鬧鐘通知
    private func handleAlarmNotification() {
        DispatchQueue.main.async {
            print("🚨 處理鬧鐘通知，發送 AlarmTriggered 事件")
            // 發送通知給 UI 層進行導航
            NotificationCenter.default.post(name: Notification.Name("AlarmTriggered"), object: nil)
            print("🚨 AlarmTriggered 事件已發送")
        }
    }
}