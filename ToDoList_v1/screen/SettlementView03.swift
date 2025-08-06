import SwiftUI
import UserNotifications

// MARK: - Page03ProgressBarSegment (在 SettlementView03.swift 中定義，或從共用檔案引用)
// 如果您決定將 ProgressBarSegment 做成共用檔案，請確保 SettlementView03 能存取到它
// 並且其 isActive 的行為符合 SettlementView03 的需求：
// isActive = true: 綠色實心
// isActive = false: 深灰底綠框
struct Page03ProgressBarSegment: View { // 此處使用之前為 S03 設計的進度條
    let isActive: Bool
    private let segmentWidth: CGFloat = 160
    private let segmentHeight: CGFloat = 11
    private let segmentCornerRadius: CGFloat = 29

    var body: some View {
        if isActive {
            Rectangle()
                .fill(Color(red: 0, green: 0.72, blue: 0.41))
                .frame(width: segmentWidth, height: segmentHeight)
                .cornerRadius(segmentCornerRadius)
        } else {
            Rectangle()
                .fill(Color(red: 0.13, green: 0.13, blue: 0.13))
                .frame(width: segmentWidth, height: segmentHeight)
                .cornerRadius(segmentCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: segmentCornerRadius)
                        .inset(by: 0.5)
                        .stroke(Color(red: 0, green: 0.72, blue: 0.41), lineWidth: 1)
                )
        }
    }
}

// MARK: - SettlementView03.swift
struct SettlementView03: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var alarmStateManager: AlarmStateManager
    @State private var selectedHour: Int = 8
    @State private var selectedMinute: Int = 0
    @State private var selectedAmPm: Int = 1
    @State private var isAlarmDisabled: Bool = false
    @State private var navigateToHome: Bool = false
    
    // 引用已完成日期數據管理器
    private let completeDayDataManager = CompleteDayDataManager.shared
    
    // 引用延遲結算管理器
    private let delaySettlementManager = DelaySettlementManager.shared
    
    // 用於將設置傳遞給 Home 視圖
    class SleepSettings: ObservableObject {
        static let shared = SleepSettings()
        @Published var isSleepMode: Bool = false
        @Published var alarmTime: String = "9:00 AM"
    }

    private var tomorrow: Date {
        return Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }
    
    // MARK: - 鬧鐘相關功能
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("通知權限已獲得")
            } else {
                print("通知權限被拒絕")
            }
        }
    }
    
    private func cancelExistingAlarms() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("已取消所有現有鬧鐘")
    }
    
    private func setAlarm(hour: Int, minute: Int, ampm: String) {
        let content = UNMutableNotificationContent()
        content.title = "鬧鐘"
        content.body = "該起床了！"
        content.sound = UNNotificationSound.default
        
        var dateComponents = DateComponents()
        let hour24 = ampm == "AM" ? (hour == 12 ? 0 : hour) : (hour == 12 ? 12 : hour + 12)
        dateComponents.hour = hour24
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "DailyAlarm", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("設定鬧鐘失敗: \(error)")
            } else {
                print("鬧鐘設定成功: \(hour24):\(String(format: "%02d", minute))")
            }
        }
    }

    private func formatDateForDisplay(_ date: Date) -> (monthDay: String, weekday: String) {
        let dateFormatterMonthDay = DateFormatter()
        dateFormatterMonthDay.locale = Locale(identifier: "en_US_POSIX")
        dateFormatterMonthDay.dateFormat = "MMM dd"
        let dateFormatterWeekday = DateFormatter()
        dateFormatterWeekday.locale = Locale(identifier: "en_US_POSIX")
        dateFormatterWeekday.dateFormat = "EEEE"
        return (dateFormatterMonthDay.string(from: date), dateFormatterWeekday.string(from: date))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            topHeaderSection // 使用分解後的子視圖

            MultiComponentPicker(
                hour: $selectedHour,
                minute: $selectedMinute,
                ampm: $selectedAmPm
            )
            .frame(height: 216)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 20)

            alarmToggleSection

            Spacer()

            bottomNavigationButtons
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.black.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .background(
            NavigationLink(
                destination: EmptyView(), // 暫時用EmptyView，我們會通過programmatic navigation處理
                isActive: $navigateToHome,
                label: { EmptyView() }
            )
        )
    }

    // MARK: - Sub-views for SettlementView03
    private var topHeaderSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            progressAndCheckmarkView
            grayDivider
            whatToDoText
            dateDisplayView
            sunAndTempView
            greenLineImageView
        }
    }

    private var progressAndCheckmarkView: some View {
        // *** 修改此處佈局以避免重疊 ***
        HStack {
            Spacer() // 左邊 Spacer，用於輔助居中進度條

            // 進度條組
            HStack(spacing: 8) {
                Page03ProgressBarSegment(isActive: true) // SettlementView03 使用自己的進度條定義
                Page03ProgressBarSegment(isActive: false)
            }
            
            Spacer() // 中間 Spacer，將打勾圖示推到最右邊

            Image(systemName: "checkmark")
                .foregroundColor(.gray)
                .padding(5)
                .background(Color.gray.opacity(0.3))
                .clipShape(Circle())
        }
        .padding(.top, 5)
    }

    private var grayDivider: some View {
        Rectangle()
            .frame(height: 1)
            .foregroundColor(Color(red: 0.34, green: 0.34, blue: 0.34))
            .padding(.vertical, 10)
    }

    private var whatToDoText: some View {
        HStack {
            Text("What do you want to at")
                .font(Font.custom("Instrument Sans", size: 13).weight(.semibold))
                .foregroundColor(.white)
            Spacer()
        }
    }

    private var dateDisplayView: some View {
        let tomorrowParts = formatDateForDisplay(tomorrow)
        return HStack(alignment: .bottom) {
            Text("Tomorrow")
                .font(Font.custom("Instrument Sans", size: 31.79449).weight(.bold))
                .foregroundColor(.white)
            Spacer()
            HStack(spacing: 0) {
                Text(tomorrowParts.monthDay)
                    .font(Font.custom("Instrument Sans", size: 20.65629).weight(.bold))
                    .foregroundColor(.white)
                Text("   ")
                Text(tomorrowParts.weekday)
                    .font(Font.custom("Instrument Sans", size: 20.65629).weight(.bold))
                    .foregroundColor(.gray)
            }
        }
    }

    private var sunAndTempView: some View {
        HStack {
            Image(systemName: "sun.max.fill")
                .foregroundColor(.yellow)
            Text("26°C")
                .font(Font.custom("Inria Sans", size: 11.73462))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.top, 2)
    }

    private var greenLineImageView: some View {
        Image("Vector 81")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity)
            .padding(.top, 5)
    }

    private var alarmToggleSection: some View {
        HStack {
            Text("不使用鬧鐘")
                .font(Font.custom("Inter", size: 16))
                .foregroundColor(.white)
            Spacer()
            Toggle("", isOn: $isAlarmDisabled)
                .labelsHidden()
                .tint(.green)
        }
        .padding()
        .background(Color(white: 0.15))
        .cornerRadius(10)
    }

    private var bottomNavigationButtons: some View {
        HStack {
            Button(action: {
                // 返回上一頁
                self.presentationMode.wrappedValue.dismiss()
            }) { 
                Text("返回")
                    .font(Font.custom("Inria Sans", size: 20))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center) // 使整個按鈕區域可點擊
            }.padding()
            Spacer()
            Button(action: {
                // 標記今天為已完成
                completeDayDataManager.markTodayAsCompleted()
                print("已標記今天為已完成的一天")
                
                // 標記結算流程完成 - 這是整個結算流程的最後一步
                delaySettlementManager.markSettlementCompleted()
                print("已標記結算流程完成")
                
                // 保存鬧鐘設置
                let hourToSave = selectedHour
                let minuteToSave = selectedMinute
                let ampmToSave = selectedAmPm == 0 ? "AM" : "PM"
                let alarmEnabled = !isAlarmDisabled
                
                // 格式化時間字符串，確保分鐘有兩位數字
                let formattedMinute = String(format: "%02d", minuteToSave)
                let alarmTimeFormatted = "\(hourToSave):\(formattedMinute) \(ampmToSave)"
                
                print("保存鬧鐘設置: \(alarmTimeFormatted), 啟用: \(alarmEnabled)")
                
                // 使用AlarmStateManager啟動睡眠模式
                alarmStateManager.startSleepMode(alarmTime: alarmTimeFormatted)
                
                // 保留舊的共享設置（如果其他地方還在使用）
                SleepSettings.shared.isSleepMode = true
                SleepSettings.shared.alarmTime = alarmTimeFormatted
                
                // 設定鬧鐘功能
                if alarmEnabled {
                    // 請求通知權限
                    requestNotificationPermission()
                    
                    // 取消現有的鬧鐘
                    cancelExistingAlarms()
                    
                    // 設定新的鬧鐘
                    setAlarm(hour: hourToSave, minute: minuteToSave, ampm: ampmToSave)
                    
                    print("已設定鬧鐘: \(alarmTimeFormatted)")
                } else {
                    // 如果不啟用鬧鐘，取消所有現有鬧鐘
                    cancelExistingAlarms()
                    print("已取消鬧鐘")
                }
                
                // 完成設置並回到 Home 頁面
                print("SettlementView03 - 準備返回Home並顯示sleep mode")
                
                // 設置一個標記，告訴整個導航鏈需要返回到Home
                UserDefaults.standard.set(true, forKey: "shouldReturnToHomeWithSleepMode")
                
                // 立即發送通知，告訴Home和其他視圖準備顯示sleep mode
                NotificationCenter.default.post(
                    name: Notification.Name("ReturnToHomeWithSleepMode"), 
                    object: nil
                )
                
                // 延遲一點時間後觸發導航返回
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    print("SettlementView03 - 執行dismiss")
                    self.presentationMode.wrappedValue.dismiss()
                }
            }) { 
                Text("Finish")
                    .font(Font.custom("Inria Sans", size: 20).weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .center) // 使整個按鈕區域可點擊
            }
            .frame(width: 279, height: 60).background(.white).cornerRadius(40.5)
        }
        .padding(.bottom, 10)
    }
}

#Preview {
    SettlementView03()
        .environmentObject(AlarmStateManager())
}
