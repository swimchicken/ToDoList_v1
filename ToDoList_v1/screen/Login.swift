import SwiftUI
import CloudKit

struct Login: View {
    @State private var navigateTo: String? = nil  // 可能值："onboarding"、"home"、"email" 或 nil
    
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
                            .frame(width: 354, height: 160)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(36)
                        
                        VStack(spacing: 16) {
                            // Google 登入按鈕
                            Button(action: {
                                GoogleSignInManager.shared.performSignIn()
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
                            
                            // Apple 登入按鈕
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
                            
                            // Email 登入按鈕（示意）
//                            Button(action: {
//                                navigateTo = "email"
//                            }) {
//                                HStack(spacing: 10) {
//                                    Image(systemName: "envelope.fill")
//                                        .resizable()
//                                        .scaledToFit()
//                                        .frame(width: 20, height: 16)
//                                        .foregroundColor(.white)
//                                    
//                                    Text("Continue with Email")
//                                        .font(Font.custom("Inter", size: 16)
//                                                .weight(.semibold))
//                                        .foregroundColor(Color(red: 0.94, green: 0.94, blue: 0.94))
//                                }
//                                .padding(.leading, 19)
//                                .padding(.trailing, 127)
//                                .padding(.vertical, 17)
//                                .frame(width: 329, alignment: .topLeading)
//                                .background(Color.white.opacity(0.1))
//                                .cornerRadius(28)
//                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 60)
                // 接收 AppleSignInManager 發出的登入結果通知
                .onReceive(NotificationCenter.default.publisher(for: .didLogin)) { notification in
                    if let userInfo = notification.userInfo,
                       let destination = userInfo["destination"] as? String {
                        navigateTo = destination
                    }
                }
                .onAppear {
                    // 進入 Login 頁面時，檢查最近登入狀態，若已登入則直接進入 Home
                    LoginStatusChecker.shared.checkLoginStatus { destination in
                        switch destination {
                        case .home:
                            navigateTo = "home"
                        case .login:
                            navigateTo = nil
                        }
                    }
                }
            }
            
            NavigationLink(tag: "onboarding", selection: $navigateTo) {
                guide3()
                    .navigationBarBackButtonHidden(true)
            } label: {
                EmptyView()
            }
            
            NavigationLink(tag: "home", selection: $navigateTo) {
                Home()
                    .navigationBarBackButtonHidden(true)
            } label: {
                EmptyView()
            }
            
            NavigationLink(tag: "email", selection: $navigateTo) {
                EmailLogin()
                    .navigationBarBackButtonHidden(true)
            } label: {
                EmptyView()
            }
        }
    }
}

#Preview {
    Login()
}
