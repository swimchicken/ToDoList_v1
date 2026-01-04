import SwiftUI
import UserNotifications

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    static let shared = NotificationDelegate()
    
    private override init() {
        super.init()
    }
    
    // 當應用在前景時收到通知
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        // 檢查是否是鬧鐘通知
        let isAlarmNotification = notification.request.identifier.lowercased().contains("alarm") || notification.request.identifier == "DailyAlarm"
        
        if isAlarmNotification {
            handleAlarmNotification()
        }
        
        // 顯示通知 (聲音 + 橫幅)
        completionHandler([.banner, .sound])
    }
    
    // 當用戶點擊通知時
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        // 檢查是否是鬧鐘通知
        if response.notification.request.identifier.lowercased().contains("alarm") || response.notification.request.identifier == "DailyAlarm" {
            handleAlarmNotification()
        }
        
        completionHandler()
    }
    
    // 處理鬧鐘通知
    private func handleAlarmNotification() {
        DispatchQueue.main.async {

            // 開始播放鬧鐘聲音
            AlarmAudioManager.shared.playAlarmSound()

            // 發送通知給 UI 層進行導航
            NotificationCenter.default.post(name: Notification.Name("AlarmTriggered"), object: nil)
        }
    }
}