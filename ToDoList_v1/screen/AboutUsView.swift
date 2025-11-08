/*import SwiftUI

// MARK: - 主設定頁面 View

struct AboutUsView: View {
    @Environment(\.dismiss) var dismiss // 用於關閉本頁面
    
    
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
                        SettingsSection(title: "Help") {
                            // what's new
                            SettingRow(title: "What's new", isToggle: false, hasChevron: true) {
                                print("What's new")
                            }
                            
                            Divider().background(Color.gray.opacity(0.3)).padding(.horizontal, 20)
                            
                            // How to use
                            SettingRow(title: "How to use", isToggle: false, hasChevron: true) {
                                print("How to use")
                            }
                            
                            Divider().background(Color.gray.opacity(0.3)).padding(.horizontal, 20)
                            
                            // Contact us
                            SettingRow(title: "Contact us", isToggle: false, hasChevron: true) {
                                print("Contact us")
                            }
                            
                            Divider().background(Color.gray.opacity(0.3)).padding(.horizontal, 20)
                            
                            // Terms of Service
                            SettingRow(title: "Terms of Service", isToggle: false, hasChevron: true) {
                                print("Terms of Service")
                            }
                        }
                        
                        // --- 行事曆設定 ---
                        SettingsSection(title: "行事曆設定") {
                            // 一週起始於
                            SettingRow(title: "一週起始於", isToggle: false, hasChevron: true) {
                                print("開啟一週起始於選擇器")
                            }
                            Divider().background(Color.gray.opacity(0.3)).padding(.horizontal, 20)
                            // 節假日
                            
                            
                            SettingRow(title: "節假日", isToggle: false, hasChevron: true) {
                                print("導航至節假日地區選擇")
                            }
                            
                            // 顯示節假日 (Toggle)
                            Divider().background(Color.gray.opacity(0.3)).padding(.horizontal, 20)
                            
                            SettingRow(title: "顯示節假日", isToggle: true, hasChevron: false)
                        }
                        
                        
                        
                    }
                    .padding(.bottom, 20) // 在滾動內容底部增加一些間距
                }
                
                
            }
        }
    }
    
    // 頂部標題和關閉按鈕
    private var headerView: some View {
// ... (existing code)
        HStack {
            Text("關於我們")
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
    
 
}


// MARK: - 預覽
#Preview {
// ... (existing code)
    AboutUsView()
}

#if DEBUG
struct AboutUsView_Previews: PreviewProvider {
// ... (existing code)
    static var previews: some View {
        // 在 NavigationStack 中預覽，以模擬導航環境
        NavigationStack {
            AboutUsView()
        }
        .preferredColorScheme(.dark)
    }
}
#endif
*/
