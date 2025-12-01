import SwiftUI

// MARK: - 主設定頁面 View

struct SettingView: View {
    @Environment(\.dismiss) var dismiss // 用於關閉本頁面
    
    // 基礎設定
    @State private var selectedLanguage: String = "繁體中文"
    
    // 行事曆設定
    @State private var startOfWeek: String = "星期日"
    @State private var holidayRegion: String = "臺灣"
    @State private var displayHolidays: Bool = true
    
    // 通知設定
    @State private var notificationsOn: Bool = true
    @State private var reminderTime: String = "30 分鐘前"
    
    @State private var isShowingWeekStartPicker = false
    @State private var isShowingReminderTimePicker = false
    @State private var isShowingHolidayPicker = false
    
    var body: some View {
        ZStack {
            // 背景顏色
            Color(hex: "111111").ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                // 1. 頂部標題與關閉按鈕 (靜態不滾動)
                headerView
                    .padding(.bottom, 10)
                
                // 2. 可滾動的設定項目
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // --- 基礎設定 ---
                        SettingsSection(title: "基礎設定") {
                            // 語言
                            SettingRow(title: "語言", value: selectedLanguage, isToggle: false, hasChevron: true) {
                                print("導航至語言設定")
                            }
                        }
                        
                        // --- 行事曆設定 ---
                        SettingsSection(title: "行事曆設定") {
                            // 一週起始於
                            SettingRow(title: "一週起始於", value: startOfWeek, isToggle: false, hasChevron: true) {
                                isShowingWeekStartPicker = true
                                print("開啟一週起始於選擇器")
                            }
                            
                            // 節假日
                            Divider().background(Color.gray.opacity(0.3)).padding(.horizontal, 20)
                            
                            SettingRow(title: "節假日", value: holidayRegion, isToggle: false, hasChevron: true) {
                                isShowingHolidayPicker = true
                                print("導航至節假日地區選擇")
                            }
                            
                            // 顯示節假日 (Toggle)
                            Divider().background(Color.gray.opacity(0.3)).padding(.horizontal, 20)
                            
                            SettingRow(title: "顯示節假日", isToggle: true, hasChevron: false, toggleState: $displayHolidays)
                        }
                        
                        // --- 通知設定 ---
                        SettingsSection(title: "通知設定") {
                            // 通知 (Toggle)
                            SettingRow(title: "通知", isToggle: true, hasChevron: false, toggleState: $notificationsOn)
                            
                            // 通知提醒時間
                            Divider().background(Color.gray.opacity(0.3)).padding(.horizontal, 20)
                            
                            // 只有在通知開啟時才可見和互動
                            SettingRow(
                                title: "通知提醒時間",
                                value: reminderTime,
                                isToggle: false,
                                hasChevron: true,
                                action: {
                                    print("開啟通知提醒時間選擇器")
                                    isShowingReminderTimePicker = true
                                }
                            )
                            .opacity(notificationsOn ? 1.0 : 0.5)
                            .disabled(!notificationsOn)
                        }
                        
                        // [Log out 區塊已移至 ScrollView 外部]
                        
                    }
                    .padding(.bottom, 20) // 在滾動內容底部增加一些間距
                }
                
                // 3. Spacer 會將 ScrollView 往上推，並將下面的 Log out 區塊推到最底部
                Spacer(minLength: 20)
                
                // 4. 登出按鈕 (固定在畫面底部)
                logOutSection
                    .padding(.bottom, 20) // 增加底部間距，使其與螢幕邊緣保持距離
            }
        }
        .sheet(isPresented: $isShowingWeekStartPicker) {
            WeekStartPickerView(selectedDay: $startOfWeek)
                // 1. 設定高度，230 左右的高度應該符合圖片
                .presentationDetents([.height(230)])
                // 2. 顯示頂部的拖移指示器 (那條灰色小橫槓)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingReminderTimePicker) {
            ReminderTimePickerView(selectedTime: $reminderTime)
                // 5 個選項需要更高的高度
                .presentationDetents([.height(340)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingHolidayPicker) {
            HolidayPickerView(selectedRegion: $holidayRegion)
                // 列表很長，給它一個較大的固定高度
                .presentationDetents([.height(600)])
                .presentationDragIndicator(.visible)
        }
    }
    
    // 頂部標題和關閉按鈕
    private var headerView: some View {
// ... (existing code)
        HStack {
            Text("settings.title")
                .font(.system(size: 20).weight(.semibold))
                .foregroundColor(.white)
            
            Spacer()
            /*
            Button(action: {
                // 點擊 X 時關閉本頁面
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16).weight(.medium))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.gray.opacity(0.3))
                    .clipShape(Circle())
            }*/
        }
        .padding(.horizontal, 20)
        .padding(.top, 15)
    }
    
    // 登出區塊 (模擬 SettingsSection 的樣式)
    private var logOutSection: some View {
// ... (existing code)
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                print("使用者登出")
                // 執行登出操作
            }) {
                Text("common.logout")
                    .font(.system(size: 16).weight(.regular))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading) // 保持左對齊
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15) // 模擬 SettingRow 的垂直間距
            .contentShape(Rectangle()) // 確保整個區域可點擊
        }
        .background(Color(hex: "2C2C2E")) // 區塊背景色
        .cornerRadius(10) // 圓角
        .padding(.horizontal, 20) // 左右邊距
    }
}

// MARK: - 輔助 View：設定區塊標題

struct SettingsSection<Content: View>: View {
// ... (existing code)
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 14).weight(.regular))
                .foregroundColor(.gray)
                .textCase(nil) // 取消 SwiftUI List/Form 預設的標題大寫
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .padding(.top, 10)
            
            VStack(spacing: 0) {
                content
            }
            .background(Color(hex: "2C2C2E")) // 模擬設定區塊的深色背景
            .cornerRadius(10) // 模擬圓角
            .padding(.horizontal, 20) // 應用左右間距
        }
    }
}

// MARK: - 輔助 View：單個設定項目

struct SettingRow: View {
// ... (existing code)
    let title: String
    var value: String? = nil // 用於顯示當前值的文字
    let isToggle: Bool
    let hasChevron: Bool
    var toggleState: Binding<Bool>? = nil // 用於開關狀態
    var action: (() -> Void)? = nil // 點擊的動作
    
    var body: some View {
        Group {
            if isToggle {
                HStack {
                    Text(title)
                        .foregroundColor(.white)
                    Spacer()
                    Toggle("", isOn: toggleState!)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: .green)) // 綠色開關
                }
            } else {
                Button(action: action ?? {}) {
                    HStack {
                        Text(title)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        if let value = value {
                            Text(value)
                                .foregroundColor(.gray)
                        }
                        
                        if hasChevron {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
        // 確保所有 SettingRow 都有水平內邊距和垂直間距
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .frame(minHeight: 30)
    }
}

// MARK: - 輔助 View：一週起始日選擇器

struct WeekStartPickerView: View {
    @Binding var selectedDay: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            // 1. 背景顏色 (使用你 App 的主背景色)
            Color(hex: "1C1C1E").ignoresSafeArea()
            
            VStack(alignment: .center, spacing: 0) {
                // 2. 頂部標題
                Text("settings.week_starts_on")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.7))
                    .padding(.top, 25) // 頂部留空間給拖移條
                    .padding(.bottom, 10)

                // 3. 選項區塊 (使用你 App 的區塊背景色)
                VStack(spacing: 0) {
                    // 星期一
                    OptionRow(
                        title: "星期一",
                        isSelected: selectedDay == "星期一",
                        action: {
                            selectedDay = "星期一"
                            dismiss() // 點選後關閉
                        }
                    )
                    
                    // 分隔線
                    //Divider().background(Color.gray.opacity(0.3)).padding(.horizontal, 16)

                    // 星期日
                    OptionRow(
                        title: "星期日",
                        isSelected: selectedDay == "星期日",
                        action: {
                            selectedDay = "星期日"
                            dismiss() // 點選後關閉
                        }
                    )
                }
                //.background(Color(hex: "2C2C2E"))
                .cornerRadius(10)
                .padding(.horizontal, 10) // 讓區塊左右留白
                
                Spacer() // 將內容推到頂部
            }
        }
    }
}

// MARK: - 輔助 View：選擇器中的單個選項 (完全複製圖片樣式)

private struct OptionRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(.white) // 文字固定為白色
                
                Spacer()
                
                // 狀態指示圈圈
                Circle()
                    .fill(isSelected ? Color.green : Color.gray.opacity(0.4))
                    .frame(width: 22, height: 22)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle()) // 確保整行都可點擊
        }
        .buttonStyle(.plain) // 移除按鈕的預設樣式
    }
}

// MARK: - 輔助 View：通知提醒時間選擇器

struct ReminderTimePickerView: View {
    @Binding var selectedTime: String
    @Environment(\.dismiss) var dismiss

    // 1. 定義選項
    private let reminderOptions = [
        "10 分鐘前",
        "15 分鐘前",
        "20 分鐘前",
        "30 分鐘前",
        "60 分鐘前"
    ]

    var body: some View {
        ZStack {
            // 2. 背景顏色
            Color(hex: "1C1C1E").ignoresSafeArea()
            
            VStack(alignment: .center, spacing: 0) {
                // 3. 頂部標題
                Text("settings.notification_time")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.7))
                    // 保持和上一個 picker 相同的頂部間距 (25)
                    .padding(.top, 25)
                    .padding(.bottom, 10)

                // 4. 選項區塊
                VStack(spacing: 0) {
                    // 5. 使用 ForEach 迴圈來建立所有選項
                    ForEach(reminderOptions, id: \.self) { option in
                        // 重用 OptionRow !
                        OptionRow(
                            title: option,
                            isSelected: selectedTime == option,
                            action: {
                                selectedTime = option
                                dismiss() // 點選後關閉
                            }
                        )
                        /*
                        // 只要不是最後一個選項，就加上分隔線
                        if option != reminderOptions.last {
                            Divider().background(Color.gray.opacity(0.3)).padding(.horizontal, 16)
                        }
                         */
                    }
                }
                //.background(Color(hex: "2C2C2E"))
                .cornerRadius(10)
                .padding(.horizontal, 10) // 讓區塊左右留白
                
                Spacer() // 將內容推到頂部
            }
        }
    }
}

// MARK: - 輔助 View：節假日地區選擇器

struct HolidayPickerView: View {
    @Binding var selectedRegion: String
    @Environment(\.dismiss) var dismiss

    // 1. 範例國家/地區列表 (在真實 App 中應來自數據模型)
    // "臺灣" 在列表中我們用 "Taiwan" 來對應
    private let regionOptions = [
        "Australia", "Austria", "Azerbaijan", "Bahamas", "Bahrain",
        "Bangladesh", "Belgium", "Brazil", "Canada", "Chile",
        "China", "Colombia", "Croatia", "Czech Republic", "Denmark",
        "Egypt", "France", "Germany", "Greece", "Hong Kong",
        "Hungary", "Iceland", "India", "Indonesia", "Ireland",
        "Israel", "Italy", "Japan", "Malaysia", "Mexico",
        "Netherlands", "New Zealand", "Nigeria", "Norway", "Philippines",
        "Poland", "Portugal", "Russia", "Saudi Arabia", "Singapore",
        "South Africa", "South Korea", "Spain", "Sweden", "Switzerland",
        "Taiwan", // 列表中的 "Taiwan"
        "Thailand", "Turkey", "Ukraine", "United Arab Emirates",
        "United Kingdom", "USA", "Vietnam"
    ]
    
    // 2. 建立一個內部計算屬性來處理 "臺灣" 和 "Taiwan" 之間的轉換
    private var internalSelectedRegion: String {
        selectedRegion == "臺灣" ? "Taiwan" : selectedRegion
    }

    var body: some View {
        ZStack {
            // 3. 背景顏色
            Color(hex: "1C1C1E").ignoresSafeArea()
            
            VStack(alignment: .center, spacing: 0) {
                // 4. 頂部標題
                Text("settings.holidays")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.7))
                    .padding(.top, 25) // 保持一致的頂部間距
                    .padding(.bottom, 10)

                // 5. 選項區塊 (包含 ScrollView)
                VStack(spacing: 0) {
                    ScrollView {
                        // 使用 LazyVStack 提升長列表的效能
                        LazyVStack(spacing: 0) {
                            ForEach(regionOptions, id: \.self) { option in
                                // 重用 OptionRow
                                OptionRow(
                                    title: option,
                                    // 檢查時，使用轉換後的名稱
                                    isSelected: internalSelectedRegion == option,
                                    action: {
                                        // 儲存時，把 "Taiwan" 轉回 "臺灣"
                                        if option == "Taiwan" {
                                            selectedRegion = "臺灣"
                                        } else {
                                            selectedRegion = option
                                        }
                                        dismiss() // 點選後關閉
                                    }
                                )
                                /*
                                // 只要不是最後一個選項，就加上分隔線
                                if option != regionOptions.last {
                                    Divider().background(Color.gray.opacity(0.3)).padding(.horizontal, 16)
                                }
                                 */
                            }
                        }
                    }
                }
                //.background(Color(hex: "2C2C2E"))
                .cornerRadius(10)
                .padding(.horizontal, 20) // 讓區塊左右留白
                
                // 註：這裡不需要 Spacer()，因為 ScrollView 會自動填滿 VStack 中的剩餘空間
            }
        }
    }
}

// MARK: - 預覽
#Preview {
// ... (existing code)
    SettingView()
}

#if DEBUG
struct SettingView_Previews: PreviewProvider {
// ... (existing code)
    static var previews: some View {
        // 在 NavigationStack 中預覽，以模擬導航環境
        NavigationStack {
            SettingView()
        }
        .preferredColorScheme(.dark)
    }
}
#endif
