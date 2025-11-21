import Foundation

class LoginStatusChecker {
    static let shared = LoginStatusChecker()
    private let apiDataManager = APIDataManager.shared

    enum Destination {
        case home, login
    }

    func checkLoginStatus(completion: @escaping (Destination) -> Void) {
        // 檢查是否有API token
        let hasToken = apiDataManager.isLoggedIn()
        let savedToken = UserDefaults.standard.string(forKey: "api_auth_token")
        print("LoginStatusChecker: API登入狀態檢查 - hasToken: \(hasToken), savedToken: \(savedToken ?? "nil")")

        if hasToken {
            print("LoginStatusChecker: 檢測到API登入狀態，進入主頁")
            completion(.home)
            return
        }

        // 檢查本地持久化登入狀態
        let hasPersistedLogin = UserDefaults.standard.bool(forKey: "hasPersistedLogin")
        let appleUserId = UserDefaults.standard.string(forKey: "appleAuthorizedUserId")
        let googleUserId = UserDefaults.standard.string(forKey: "googleAuthorizedUserId")

        guard appleUserId != nil || googleUserId != nil else {
            print("LoginStatusChecker: 無第三方登入ID，導向登入頁面")
            completion(.login)
            return
        }

        if hasPersistedLogin {
            print("LoginStatusChecker: 檢測到持久化登入狀態但無API token，嘗試健康檢查")

            // 使用API健康檢查來驗證連接狀態
            Task {
                do {
                    let _ = try await apiDataManager.healthCheck()
                    await MainActor.run {
                        print("LoginStatusChecker: API連接正常，進入主頁")
                        completion(.home)
                    }
                } catch {
                    await MainActor.run {
                        print("LoginStatusChecker: API連接失敗，清除登入狀態: \(error.localizedDescription)")
                        self.clearPersistedLogin()
                        completion(.login)
                    }
                }
            }
        } else {
            print("LoginStatusChecker: 無持久化登入狀態，導向登入頁面")
            completion(.login)
        }
    }
    /// 清除持久化登入狀態（用戶主動登出時調用）
    func clearPersistedLogin() {
        UserDefaults.standard.removeObject(forKey: "hasPersistedLogin")
        UserDefaults.standard.removeObject(forKey: "appleAuthorizedUserId")
        UserDefaults.standard.removeObject(forKey: "googleAuthorizedUserId")
        apiDataManager.logout() // 同時清除API登入狀態
        print("LoginStatusChecker: 已清除持久化登入狀態")
    }
}
