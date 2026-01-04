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

        if hasToken {
            completion(.home)
            return
        }

        // 檢查本地持久化登入狀態
        let hasPersistedLogin = UserDefaults.standard.bool(forKey: "hasPersistedLogin")
        let appleUserId = UserDefaults.standard.string(forKey: "appleAuthorizedUserId")
        let googleUserId = UserDefaults.standard.string(forKey: "googleAuthorizedUserId")

        guard appleUserId != nil || googleUserId != nil else {
            completion(.login)
            return
        }

        if hasPersistedLogin {

            // 使用API健康檢查來驗證連接狀態
            Task {
                do {
                    let _ = try await apiDataManager.healthCheck()
                    await MainActor.run {
                        completion(.home)
                    }
                } catch {
                    await MainActor.run {
                        self.clearPersistedLogin()
                        completion(.login)
                    }
                }
            }
        } else {
            completion(.login)
        }
    }
    /// 清除持久化登入狀態（用戶主動登出時調用）
    func clearPersistedLogin() {
        UserDefaults.standard.removeObject(forKey: "hasPersistedLogin")
        UserDefaults.standard.removeObject(forKey: "appleAuthorizedUserId")
        UserDefaults.standard.removeObject(forKey: "googleAuthorizedUserId")
        apiDataManager.logout() // 同時清除API登入狀態
    }
}
