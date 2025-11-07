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
    
    var body: some View {
        ZStack {
            // 背景顏色
            Color(hex: "1C1C1E").ignoresSafeArea()
            
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
                                print("開啟一週起始於選擇器")
                            }
                            
                            // 節假日
                            Divider().background(Color.gray.opacity(0.3)).padding(.horizontal, 20)
                            
                            SettingRow(title: "節假日", value: holidayRegion, isToggle: false, hasChevron: true) {
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
    }
    
    // 頂部標題和關閉按鈕
    private var headerView: some View {
// ... (existing code)
        HStack {
            Text("設定")
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
                Text("Log out")
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
