import SwiftUI
import UserNotifications

// MARK: - Page03ProgressBarSegment (在 SettlementView03.swift 中定義，或從共用檔案引用)
// 如果您決定將 ProgressBarSegment 做成共用檔案，請確保 SettlementView03 能存取到它
// 並且其 isActive 的行為符合 SettlementView03 的需求：
// isActive = true: 綠色實心
// isActive = false: 深灰底綠框
struct Page03ProgressBarSegment: View { // 此處使用之前為 S03 設計的進度條
    let isActive: Bool
    private let segmentWidth: CGFloat = 165
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
    @State private var navigateToHome: Bool = false
    @State private var selectedHour: Int = 8
    @State private var selectedMinute: Int = 0
    @State private var selectedAmPm: Int = 1
    @State private var isAlarmDisabled: Bool = false
    // 由 Home 端負責關閉整個結算導覽鏈（透過通知），不在此再推一個 Home

    // 接收從SettlementView02傳遞的任務信息
    let uncompletedTasks: [TodoItem]
    let moveTasksToTomorrow: Bool

    // 默認初始化方法（用於preview或無任務情況）
    init(uncompletedTasks: [TodoItem] = [], moveTasksToTomorrow: Bool = false) {
        self.uncompletedTasks = uncompletedTasks
        self.moveTasksToTomorrow = moveTasksToTomorrow
    }

    // 引用已完成日期數據管理器
    private let completeDayDataManager = CompleteDayDataManager.shared
    
    // 引用延遲結算管理器
    private let delaySettlementManager = DelaySettlementManager.shared

    // 數據同步管理器
    private let dataSyncManager = DataSyncManager.shared
    
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
        VStack(alignment: .leading, spacing: 0) {
            topHeaderSection // 使用分解後的子視圖

            MultiComponentPicker(
                hour: $selectedHour,
                minute: $selectedMinute,
                ampm: $selectedAmPm
            )
            .frame(height: 216)
            .frame(maxWidth: .infinity, alignment: .center)
            .opacity(isAlarmDisabled ? 0.3 : 1.0)
            .disabled(isAlarmDisabled)
            .padding(.vertical, 20)

            alarmToggleSection

            Spacer()

            bottomNavigationButtons
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.black.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .background(
            // 使用 isDetailLink: false 可以讓導航回到根視圖
            NavigationLink(
                destination: Home()
                    .navigationBarHidden(true)
                    .navigationBarBackButtonHidden(true)
                    .toolbar(.hidden, for: .navigationBar), 
                isActive: $navigateToHome,
                label: { EmptyView() }
            )
            .isDetailLink(false) // 這會重置導航堆疊
        )
    }

    // MARK: - Sub-views for SettlementView03
    private var topHeaderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
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
//            Spacer() // 左邊 Spacer，用於輔助居中進度條

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
        .padding(.top, 0)
    }

    private var grayDivider: some View {
        Rectangle()
            .frame(height: 1)
            .foregroundColor(Color(red: 0.34, green: 0.34, blue: 0.34))
            .padding(.vertical, 4)
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

                print("保存設置: \(alarmTimeFormatted), 啟用鬧鐘: \(alarmEnabled)")

                // 如果用戶選擇移動任務到明天，先執行移動（無論是否啟用鬧鐘）
                if moveTasksToTomorrow && !uncompletedTasks.isEmpty {
                    moveUncompletedTasksToTomorrow()
                }

                if alarmEnabled {
                    // 啟用鬧鐘：設定鬧鐘並進入睡眠模式

                    // 請求通知權限
                    requestNotificationPermission()

                    // 取消現有的鬧鐘
                    cancelExistingAlarms()

                    // 設定新的鬧鐘
                    setAlarm(hour: hourToSave, minute: minuteToSave, ampm: ampmToSave)

                    // 保存到 UserDefaults，啟動睡眠模式
                    UserDefaults.standard.set(true, forKey: "isSleepMode")
                    UserDefaults.standard.set(alarmTimeFormatted, forKey: "alarmTimeString")

                    // 使用 AlarmStateManager 啟動睡眠模式
                    alarmStateManager.startSleepMode(alarmTime: alarmTimeFormatted)

                    // 保存到共享設置
                    SleepSettings.shared.isSleepMode = true
                    SleepSettings.shared.alarmTime = alarmTimeFormatted

                    print("已設定鬧鐘並啟動睡眠模式: \(alarmTimeFormatted)")
                } else {
                    // 不啟用鬧鐘：只完成結算，不進入睡眠模式

                    // 取消所有現有鬧鐘
                    cancelExistingAlarms()

                    // 確保睡眠模式為關閉狀態
                    UserDefaults.standard.set(false, forKey: "isSleepMode")
                    UserDefaults.standard.removeObject(forKey: "alarmTimeString")

                    // 確保 AlarmStateManager 不在睡眠模式
                    if alarmStateManager.isSleepModeActive {
                        alarmStateManager.endSleepMode()
                    }

                    // 重置共享設置
                    SleepSettings.shared.isSleepMode = false
                    SleepSettings.shared.alarmTime = ""

                    print("已完成結算但不啟動睡眠模式（用戶選擇不使用鬧鐘）")
                }

                // 完成設置並回到 Home 頁面
                navigateToHome = true
            }) {
                Text(isAlarmDisabled ? "完成結算" : "進入睡眠模式")
                    .font(Font.custom("Inria Sans", size: 20).weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .center) // 使整個按鈕區域可點擊
            }
            .frame(width: 279, height: 60).background(.white).cornerRadius(40.5)
        }
        .padding(.bottom, 20)
    }

    // MARK: - Task Movement Logic

    /// 將未完成任務移至明日的數據處理
    private func moveUncompletedTasksToTomorrow() {
        print("睡眠模式啟動時開始將 \(uncompletedTasks.count) 個未完成任務移至明日")

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()

        // 再次篩選，確保只處理當天的未完成事項（排除備忘錄）
        let todayUncompletedTasks = uncompletedTasks.filter { task in
            guard let taskDate = task.taskDate else {
                // 沒有日期的任務（備忘錄）不應該被移動
                return false
            }
            let taskDay = calendar.startOfDay(for: taskDate)
            return taskDay == today
        }

        print("實際將移動的當天未完成任務: \(todayUncompletedTasks.count) 個（從總計 \(uncompletedTasks.count) 個中篩選）")

        for task in todayUncompletedTasks {
            // 決定新的任務時間
            let newTaskDate: Date?

            if let originalTaskDate = task.taskDate {
                // 如果原本有時間，檢查是否為 00:00:00
                let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: originalTaskDate)
                let isTimeZero = (timeComponents.hour == 0 && timeComponents.minute == 0 && timeComponents.second == 0)

                if isTimeZero {
                    // 原本是 00:00:00 的事件（日期無時間），移至明天的 00:00:00
                    newTaskDate = calendar.startOfDay(for: tomorrow)
                    print("任務 '\(task.title)' 原本是日期無時間，移至明天的 00:00:00")
                } else {
                    // 原本有具體時間的事件，保留時間但改日期為明天
                    var tomorrowComponents = calendar.dateComponents([.year, .month, .day], from: tomorrow)
                    tomorrowComponents.hour = timeComponents.hour
                    tomorrowComponents.minute = timeComponents.minute
                    tomorrowComponents.second = timeComponents.second

                    newTaskDate = calendar.date(from: tomorrowComponents)
                    print("任務 '\(task.title)' 保留原時間 \(timeComponents.hour ?? 0):\(timeComponents.minute ?? 0)，移至明天")
                }
            } else {
                // 原本就沒有時間（備忘錄），保持沒有時間
                newTaskDate = nil
                print("任務 '\(task.title)' 原本是備忘錄，移至明日後保持為備忘錄")
            }

            // 創建更新後的任務
            let updatedTask = TodoItem(
                id: task.id,
                userID: task.userID,
                title: task.title,
                priority: task.priority,
                isPinned: task.isPinned,
                taskDate: newTaskDate,
                note: task.note,
                status: task.status,
                createdAt: task.createdAt,
                updatedAt: Date(),
                correspondingImageID: task.correspondingImageID
            )

            // 使用 DataSyncManager 更新任務
            dataSyncManager.updateTodoItem(updatedTask) { result in
                switch result {
                case .success:
                    print("成功將任務 '\(task.title)' 移至明日")
                case .failure(let error):
                    print("移動任務 '\(task.title)' 失敗: \(error.localizedDescription)")
                }
            }
        }

        print("完成未完成任務移至明日的處理")
    }
}

#Preview {
    SettlementView03()
        .environmentObject(AlarmStateManager())
}
