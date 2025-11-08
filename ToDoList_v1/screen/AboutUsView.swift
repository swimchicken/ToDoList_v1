import SwiftUI

// MARK: - 主設定頁面 View

struct AboutUsView: View {
    @Environment(\.dismiss) var dismiss // 用於關閉本頁面
    
    @State private var isShowingAboutUsSheet = false
    
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
                        
                        // --- Help ---
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
                        
                        // --- Communities---
                        SettingsSection(title: "Communities") {
                            // Follow us on Instagram
                            SettingRow(title: "Follow us on Instagram", isToggle: false, hasChevron: true) {
                                print("Follow us on Instagram")
                            }
                            
                            Divider().background(Color.gray.opacity(0.3)).padding(.horizontal, 20)
                            
                            // Join us Discord
                            SettingRow(title: "Join us Discord", isToggle: false, hasChevron: true) {
                                print("Join us Discord")
                            }
                            
                            Divider().background(Color.gray.opacity(0.3)).padding(.horizontal, 20)
                            
                            // Share to your friend
                            SettingRow(title: "Share to your friend", isToggle: false, hasChevron: true) {
                                print("Share to your friend")
                            }
                            
                        }
                        
                        // --- About us---
                        SettingsSection(title: "About us") {
                            StaticInfoBlock(
                                title: "We Are YUNIVER ®",
                                    content: "In the quiet moments before dawn breaks, the dim light, still incomplete, is filled with anticipation and palpitations.In the quiet moments before dawn breaks, the dim light, still incomplete, is filled with anticipation and palpitations.In the quiet moments before dawn breaks, the dim light, still incomplete, is filled with anticipation and palpitations."
                                )
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

// MARK: - 輔助 View：靜態資訊區塊 (用於 About us)
struct StaticInfoBlock: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) { // 靠左對齊
            // 標題 (如圖所示)
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 20)
                .padding(.horizontal, 20)
            
            // 內文 (如圖所示)
            Text(content)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color.white.opacity(0.8)) // 內文顏色
                .lineSpacing(5) // 增加行距
                .padding(.horizontal, 15)
                .padding(.bottom, 15)
            
        }
        
        .frame(maxWidth: .infinity, alignment: .leading) // 確保填滿寬度並靠左
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

