import SwiftUI

struct Login: View {
    @State private var navigateTo: String? = nil  // "onboarding" 或 "home"
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // 標題區塊
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tomorrow Todo")
                            .font(Font.custom("Inria Sans", size: 25.45489)
                                    .weight(.bold)
                                    .italic())
                            .foregroundColor(.white)
                            .opacity(0.9)
                        
                        Text("計畫-執行-回顧")
                            .font(Font.custom("Inter", size: 16.33333))
                            .foregroundColor(Color.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    
                    // 中間圖片
                    Image("Tick04")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 246, height: 200)
                    
                    Spacer()
                    
                    // 按鈕區塊
                    ZStack {
                        Rectangle()
                            .foregroundColor(.clear)
                            .frame(width: 354, height: 240)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(36)
                        
                        VStack(spacing: 16) {
                            // Google 登入（示意）
                            Button(action: {
                                // Google 登入行為
                            }) {
                                HStack(spacing: 10) {
                                    Image("Google")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)
                                    
                                    Text("Continue with Google")
                                        .font(Font.custom("Inter", size: 16)
                                                .weight(.semibold))
                                        .foregroundColor(Color(red: 0.94, green: 0.94, blue: 0.94))
                                }
                                .padding(.leading, 19)
                                .padding(.trailing, 127)
                                .padding(.vertical, 17)
                                .frame(width: 329, alignment: .topLeading)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(28)
                            }
                            
                            // Apple 登入
                            Button(action: {
                                AppleSignInManager.shared.performSignIn()
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "applelogo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)
                                        .foregroundColor(.white)
                                    
                                    Text("Continue with Apple")
                                        .font(Font.custom("Inter", size: 16)
                                                .weight(.semibold))
                                        .foregroundColor(Color(red: 0.94, green: 0.94, blue: 0.94))
                                }
                                .padding(.leading, 19)
                                .padding(.trailing, 127)
                                .padding(.vertical, 17)
                                .frame(width: 329, alignment: .topLeading)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(28)
                            }
                            
                            // Email 登入（示意）
                            Button(action: {
                                // Email 登入行為
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "envelope.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 16)
                                        .foregroundColor(.white)
                                    
                                    Text("Continue with Email")
                                        .font(Font.custom("Inter", size: 16)
                                                .weight(.semibold))
                                        .foregroundColor(Color(red: 0.94, green: 0.94, blue: 0.94))
                                }
                                .padding(.leading, 19)
                                .padding(.trailing, 127)
                                .padding(.vertical, 17)
                                .frame(width: 329, alignment: .topLeading)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(28)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 60)
                // 接收登入完成後的通知，決定導向哪個頁面
                .onReceive(NotificationCenter.default.publisher(for: .didLogin)) { notification in
                    if let userInfo = notification.userInfo,
                        let destination = userInfo["destination"] as? String {
                        navigateTo = destination
                    }
                }
            }
            
            
            NavigationLink(tag: "onboarding", selection: $navigateTo) {
                guide()
            } label: {
                EmptyView()
            }
            
                
            NavigationLink(tag: "home", selection: $navigateTo) {
                Home()
            } label: {
                EmptyView()
            }
        }
    }
}

#Preview {
    Login()
}
