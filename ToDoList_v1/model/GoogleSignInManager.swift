import Foundation
import SwiftUI
import GoogleSignIn

class GoogleSignInManager: NSObject {
    static let shared = GoogleSignInManager()
    private let apiDataManager = APIDataManager.shared
    
    func performSignIn() {
        // 暫時在開發模式也使用真正的 Google Sign-In 進行測試
        performRealGoogleSignIn()
        
        // 如果需要回到模擬模式，取消上面註解並使用下面的條件編譯：
        /*
        #if DEBUG
        // 開發模式：使用模擬登入
        performMockSignIn()
        #else
        // 正式版：使用真正的 Google Sign-In
        performRealGoogleSignIn()
        #endif
        */
    }
    
    // MARK: - 模擬登入（開發用）
    private func performMockSignIn() {
        
        // 模擬 Google 登入成功
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // 模擬 Google 用戶資料
            let userId = "google_user_\(Int.random(in: 1000...9999))"
            let email = "user@gmail.com"
            let name = "Google User"
            
            self.handleSignInSuccess(userId: userId, email: email, name: name)
        }
    }
    
    // MARK: - 真正的 Google Sign-In
    private func performRealGoogleSignIn() {
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        guard let clientID = getGoogleClientID() else {
            return
        }
        
        // 配置 Google Sign-In
        let configuration = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = configuration
        
        // 執行登入
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error {
                    return
                }
                
                guard let result = result else {
                    return
                }
                
                let user = result.user
                guard let profile = user.profile else {
                    return
                }
                
                let userId = user.userID ?? "unknown_user"
                let email = profile.email
                let name = profile.name
                
                self?.handleSignInSuccess(userId: userId, email: email, name: name)
            }
        }
    }
    
    // MARK: - 通用登入成功處理
    private func handleSignInSuccess(userId: String, email: String?, name: String?) {

        // 使用API進行Google登入
        Task<Void, Never> {
            do {
                // 需要獲取 ID Token
                guard let user = GIDSignIn.sharedInstance.currentUser,
                      let idToken = user.idToken?.tokenString else {
                    return
                }

                let authResponse: AuthResponse = try await apiDataManager.loginWithGoogle(idToken: idToken)

                await MainActor.run {
                    // ✅ 新增：登入成功後，立即儲存包括頭像 URL 在內的所有用戶資訊
                    UserInfoManager.shared.saveUserInfo(
                        name: authResponse.user.name ?? "User",
                        email: authResponse.user.email,
                        avatarUrl: authResponse.user.avatarUrl
                    )

                    // 儲存用戶信息
                    UserDefaults.standard.set(userId, forKey: "googleAuthorizedUserId")
                    UserDefaults.standard.set(true, forKey: "hasPersistedLogin")

                    // 強制同步 UserDefaults
                    UserDefaults.standard.synchronize()

                    // 驗證 token 是否已正確保存
                    let savedToken = UserDefaults.standard.string(forKey: "api_auth_token")

                    // 再次驗證 API 登入狀態
                    let isLoggedIn = self.apiDataManager.isLoggedIn()

                    // 判斷導向位置：新用戶進入引導，舊用戶進入主頁
                    let destination = authResponse.user.isNewUser == true ? "onboarding" : "home"

                    // 延遲發送通知，確保所有狀態都已設置
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // 發送登入成功通知
                        NotificationCenter.default.post(
                            name: .didLogin,
                            object: nil,
                            userInfo: ["destination": destination]
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    // 登入失敗時可以顯示錯誤訊息給用戶
                }
            }
        }
    }
    
    // MARK: - Google 配置
    private func getGoogleClientID() -> String? {
        // 從 Google 配置文件讀取 CLIENT_ID
        if let path = Bundle.main.path(forResource: "client_221079984807-jac1p2o47ol60ba3mkngdnbktkqmhu2n.apps.googleusercontent.com", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let clientID = plist["CLIENT_ID"] as? String {
            return clientID
        }
        
        // 備用方案：直接返回硬編碼的 CLIENT_ID
        let clientID = "221079984807-jac1p2o47ol60ba3mkngdnbktkqmhu2n.apps.googleusercontent.com"
        return clientID
    }
    
}