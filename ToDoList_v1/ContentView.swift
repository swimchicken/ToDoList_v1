import SwiftUI

// 引用登入通知
extension Notification.Name {
    static let didLogin = Notification.Name("didLogin")
}

struct ContentView: View {
    // 綠色光暈參數
    private let greenStages: [(width: CGFloat, height: CGFloat)] = [
        (411.6, 411.6),
        (522.6, 522.6),
        (693.85, 693.85)
    ]
    
    // 灰色光暈參數
    private let grayStages: [(width: CGFloat, height: CGFloat, cornerRadius: CGFloat)] = [
        (235.3, 235.3, 298.78),
        (298.78, 298.78, 298.78),
        (396.66, 396.66, 396.66)
    ]
    
    // 圖片＋文字資料
    private let stages: [(text: String, imageName: String)] = [
        ("計畫", "Tick01"),
        ("計畫-執行", "Tick02"),
        ("計畫-執行-回顧", "Tick03")
    ]
    
    // 動畫頁面階段
    @State private var currentStageIndex = 0
    // Splash 層透明度
    @State private var splashOpacity: Double = 1.0
    // Login 頁面透明度
    @State private var loginOpacity: Double = 0.0
    // Home 頁面透明度
    @State private var homeOpacity: Double = 0.0
    // 控制是否顯示 Splash 層
    @State private var showSplash: Bool = false
    // 登入狀態檢查
    @State private var isCheckingLogin = true
    @State private var shouldShowAnimation = false
    @State private var shouldShowHome = false
    @State private var shouldShowSettlement = false
    
    var body: some View {
        ZStack {
            // 全螢幕黑色背景
            Color.black.ignoresSafeArea()
            
            if shouldShowAnimation && showSplash {
                // Splash 層 (以 transition 平滑移除)
                ZStack {
                    // 背景動畫層
                    ZStack {
                        // 綠色光暈
                        Rectangle()
                            .foregroundColor(.clear)
                            .frame(width: greenStages[currentStageIndex].width,
                                   height: greenStages[currentStageIndex].height)
                            .background(Color(red: 0.2, green: 0.66, blue: 0.33))
                            .cornerRadius(greenStages[currentStageIndex].width)
                            .blur(radius: 81.85)
                            .blendMode(.screen)
                            .animation(.easeInOut(duration: 0.8), value: currentStageIndex)
                        
                        // 灰色光暈（右下角）
                        Rectangle()
                            .foregroundColor(.clear)
                            .frame(width: grayStages[currentStageIndex].width,
                                   height: grayStages[currentStageIndex].height)
                            .background(Color(red: 0.63, green: 0.63, blue: 0.63))
                            .cornerRadius(grayStages[currentStageIndex].cornerRadius)
                            .blur(radius: 81.85)
                            .opacity(0.4)
                            .offset(x: 100, y: 150)
                            .blendMode(.screen)
                            .animation(.easeInOut(duration: 0.8), value: currentStageIndex)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 60)
                    .opacity(splashOpacity)
                    
                    // 文字搭配圖片 (依照 currentStageIndex 切換)
                    VStack {
                        Spacer()
                        if currentStageIndex == 0 {
                            Image("Tick01")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 246, height: 200)
                            Spacer().frame(height: 100)
                            Text("計畫")
                                .font(.title2)
                                .foregroundColor(.white)
                        } else if currentStageIndex == 1 {
                            Image("Tick02")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 246, height: 200)
                            Spacer().frame(height: 100)
                            Text("計畫-執行")
                                .font(.title2)
                                .foregroundColor(.white)
                        } else {
                            Image("Tick03")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 246, height: 200)
                            Spacer().frame(height: 100)
                            Text("計畫-執行-回顧")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    .opacity(splashOpacity)
                }
                .zIndex(0)
                .transition(.opacity)
            }
            
            // Login 頁面層 (預先佈局，透明度控制顯示)
            if !shouldShowHome {
                Login()
                    .opacity(loginOpacity)
                    .zIndex(1)
                    .transition(.opacity)
            }
            
            // Settlement 頁面層 (需要延遲結算時顯示)
            if shouldShowSettlement {
                NavigationView {
                    SettlementView()
                }
                .navigationViewStyle(StackNavigationViewStyle()) // 確保在iPad上也使用stack導航
                .opacity(homeOpacity)
                .zIndex(2)
                .transition(.opacity)
            }
            // Home 頁面層 (已登入且不需要結算的用戶顯示)
            else if shouldShowHome {
                Home()
                    .opacity(homeOpacity)
                    .zIndex(2)
                    .transition(.opacity)
            }
        }
        .onAppear {
            // 只在首次載入或明確需要檢查時執行登入檢查
            if !shouldShowHome && isCheckingLogin {
                checkLoginAndNavigate()
            }
            setupLogoutObserver()
        }
    }

    // 檢查延遲結算狀態並導航
    private func checkSettlementAndNavigate() {
        let delaySettlementManager = DelaySettlementManager.shared

        if delaySettlementManager.shouldShowSettlement() {
            print("ContentView: 檢測到需要延遲結算，直接導向 SettlementView")
            shouldShowSettlement = true
            shouldShowHome = false
            shouldShowAnimation = false
            withAnimation(.easeInOut(duration: 1.0)) {
                homeOpacity = 1.0
                loginOpacity = 0.0
            }
        } else {
            print("ContentView: 不需要結算，導向 Home")
            shouldShowHome = true
            shouldShowSettlement = false
            shouldShowAnimation = false
            withAnimation(.easeInOut(duration: 1.0)) {
                homeOpacity = 1.0
                loginOpacity = 0.0
            }
        }
    }

    // 檢查登入狀態並導航
    private func checkLoginAndNavigate() {
        LoginStatusChecker.shared.checkLoginStatus { destination in
            DispatchQueue.main.async {
                isCheckingLogin = false

                switch destination {
                case .home:
                    // 已登入：檢查是否需要延遲結算
                    checkSettlementAndNavigate()

                case .login:
                    // 未登入：顯示啟動動畫
                    shouldShowAnimation = true
                    showSplash = true
                    withAnimation(.easeInOut(duration: 1.0)) {
                        shouldShowHome = false
                        homeOpacity = 0.0
                    }
                    startSplashAnimation()
                }
            }
        }
    }

    // 設置登出通知監聽
    private func setupLogoutObserver() {
        // 監聽登出通知
        NotificationCenter.default.addObserver(
            forName: Notification.Name("UserLoggedOut"),
            object: nil,
            queue: .main
        ) { _ in
            print("收到登出通知，重新導向到登入頁面")
            // 重置所有狀態
            self.shouldShowHome = false
            self.shouldShowAnimation = true
            self.showSplash = true
            self.currentStageIndex = 0

            withAnimation(.easeInOut(duration: 1.0)) {
                self.homeOpacity = 0.0
                self.splashOpacity = 1.0
            }

            // 延遲開始動畫以確保狀態重置完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.startSplashAnimation()
            }
        }

        // 監聽登入成功通知
        NotificationCenter.default.addObserver(
            forName: .didLogin,
            object: nil,
            queue: .main
        ) { notification in
            print("ContentView: 收到登入成功通知")

            // 檢查當前登入狀態
            let apiDataManager = APIDataManager.shared
            let hasToken = apiDataManager.isLoggedIn()
            let savedToken = UserDefaults.standard.string(forKey: "api_auth_token")
            print("ContentView: 登入通知時的狀態 - hasToken: \(hasToken), savedToken: \(savedToken ?? "nil")")

            if let userInfo = notification.userInfo,
               let destination = userInfo["destination"] as? String {

                switch destination {
                case "home":
                    print("ContentView: 導向到 Home，檢查結算狀態")
                    self.checkSettlementAndNavigate()

                case "onboarding":
                    print("ContentView: 導向到引導頁面，保持在 Login 視圖")
                    // 新用戶進入引導，保持 Login 視圖顯示
                    // Login 頁面的 NavigationLink 會處理到 guide3 的導航
                    break

                default:
                    print("ContentView: 未知導向目標: \(destination)")
                }
            }
        }

        // 監聽結算完成通知
        NotificationCenter.default.addObserver(
            forName: Notification.Name("SettlementCompleted"),
            object: nil,
            queue: .main
        ) { _ in
            print("ContentView: 收到結算完成通知，導向 Home")
            self.shouldShowSettlement = false
            self.shouldShowHome = true
        }
    }

    // 啟動動畫函數（分離原有邏輯）
    private func startSplashAnimation() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if currentStageIndex < stages.count - 1 {
                withAnimation {
                    currentStageIndex += 1
                }
            } else {
                showSplash = false
                timer.invalidate()
                withAnimation(.easeInOut(duration: 2.0)) {
                    splashOpacity = 0
                    loginOpacity = 1
                }
            }
        }
    }
}

#Preview {
    ContentView()
//        .modelContainer(for: Item.self, inMemory: true)
}
