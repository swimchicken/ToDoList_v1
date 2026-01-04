import SwiftUI

struct TestPage: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var showingLogoutAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    // 標題
                    Text("測試頁面")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    // 登出按鈕
                    Button(action: {
                        showingLogoutAlert = true
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.title2)
                            
                            Text("登出")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(25)
                    }
                    
                    Spacer()
                }
                .padding(.top, 100)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                }
            }
            .alert("確認登出", isPresented: $showingLogoutAlert) {
                Button("取消", role: .cancel) { }
                Button("登出", role: .destructive) {
                    performLogout()
                }
            } message: {
                Text("確定要登出嗎？這將會清除您的登入狀態。")
            }
        }
    }
    
    private func performLogout() {
        // 1. 清除登入狀態
        LoginStatusChecker.shared.clearPersistedLogin()
        
        // 2. 清除其他相關的應用狀態
        UserDefaults.standard.removeObject(forKey: "isSleepMode")
        UserDefaults.standard.removeObject(forKey: "alarmTimeString")
        
        // 3. 發送登出通知，讓應用程式重新導向到登入頁面
        NotificationCenter.default.post(name: .userDidLogout, object: nil)
        
        // 4. 返回上一頁
        presentationMode.wrappedValue.dismiss()
    }
}

// 通知擴展
extension Notification.Name {
    static let userDidLogout = Notification.Name("userDidLogout")
}

#Preview {
    TestPage()
}
