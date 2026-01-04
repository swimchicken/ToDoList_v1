import Foundation
import CloudKit

// MARK: - 用戶信息數據模型
struct UserInfo {
    let name: String
    let email: String
    let avatarUrl: String? // ✅ 修改：從本地圖片名稱改為 URL

    init(name: String = "Loading...", email: String = "...", avatarUrl: String? = nil) {
        self.name = name
        self.email = email
        self.avatarUrl = avatarUrl
    }
}

// MARK: - 用戶信息管理器
class UserInfoManager: ObservableObject {
    @Published var userInfo: UserInfo = UserInfo()
    @Published var isLoading: Bool = true

    static let shared = UserInfoManager()

    // ✅ 新增：定義 UserDefaults 的鍵
    private let userNameKey = "userName"
    private let userEmailKey = "userEmail"
    private let userAvatarUrlKey = "userAvatarUrl"

    private init() {
        loadUserInfo()
    }

    // MARK: - 載入用戶信息
    func loadUserInfo() {
        isLoading = true
        // ✅ 優先從 UserDefaults 載入，提供即時反饋
        loadFromUserDefaults()

        // 然後異步從 CloudKit 更新（如果需要的話）
        // 如果已有 avatarUrl，可能不需要再頻繁從 CloudKit 獲取
        if userInfo.avatarUrl == nil {
            fetchFromCloudKit()
        } else {
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }

    // MARK: - 從 UserDefaults 載入信息
    private func loadFromUserDefaults() {
        let name = UserDefaults.standard.string(forKey: userNameKey) ?? "Loading..."
        let email = UserDefaults.standard.string(forKey: userEmailKey) ?? "..."
        let avatarUrl = UserDefaults.standard.string(forKey: userAvatarUrlKey)

        DispatchQueue.main.async {
            self.userInfo = UserInfo(name: name, email: email, avatarUrl: avatarUrl)
        }
    }

    // MARK: - 保存到 UserDefaults
    func saveUserInfo(name: String, email: String, avatarUrl: String?) {
        UserDefaults.standard.set(name, forKey: userNameKey)
        UserDefaults.standard.set(email, forKey: userEmailKey)
        if let avatarUrl = avatarUrl {
            UserDefaults.standard.set(avatarUrl, forKey: userAvatarUrlKey)
        } else {
            UserDefaults.standard.removeObject(forKey: userAvatarUrlKey)
        }
        
        // 立即更新 @Published 屬性以刷新 UI
        DispatchQueue.main.async {
            self.userInfo = UserInfo(name: name, email: email, avatarUrl: avatarUrl)
        }
    }

    // MARK: - 從 CloudKit 獲取用戶信息 (備用)
    private func fetchFromCloudKit() {
        guard let userID = getCurrentUserID() else {
            DispatchQueue.main.async { self.isLoading = false }
            return
        }

        fetchFromApiUser(userID: userID) { [weak self] success in
            if !success {
                self?.fetchFromPersonalData(userID: userID)
            } else {
                DispatchQueue.main.async { self?.isLoading = false }
            }
        }
    }
    
    // MARK: - 獲取當前用戶 ID
    private func getCurrentUserID() -> String? {
        return UserDefaults.standard.string(forKey: "appleAuthorizedUserId") ?? UserDefaults.standard.string(forKey: "googleAuthorizedUserId")
    }

    // MARK: - 從 ApiUser (私有數據庫) 獲取用戶信息
    private func fetchFromApiUser(userID: String, completion: @escaping (Bool) -> Void) {
        // ... 此處邏輯不變，但它沒有 avatarUrl，所以僅作為備用 ...
        completion(false) // 暫時跳過，因為我們主要依賴登入時獲取的 URL
    }

    // MARK: - 從 PersonalData (私有數據庫) 獲取用戶信息
    private func fetchFromPersonalData(userID: String) {
        // ... 此處邏輯不變，但它沒有 avatarUrl，所以僅作為備用 ...
        DispatchQueue.main.async { self.isLoading = false }
    }

    // MARK: - 更新用戶名稱
    func updateUserName(_ newName: String, completion: @escaping (Bool) -> Void) {
        // ... 此處更新名稱的邏輯不變 ...
        // 確保在完成時也更新本地 userInfo
        DispatchQueue.main.async {
            self.saveUserInfo(name: newName, email: self.userInfo.email, avatarUrl: self.userInfo.avatarUrl)
            completion(true) // 假設成功
        }
    }
    
    // MARK: - 刷新用戶信息
    func refreshUserInfo() {
        loadUserInfo()
    }

    // MARK: - 清除用戶信息（登出時使用）
    func clearUserInfo() {
        DispatchQueue.main.async {
            self.userInfo = UserInfo()
            self.isLoading = false
        }
        UserDefaults.standard.removeObject(forKey: userNameKey)
        UserDefaults.standard.removeObject(forKey: userEmailKey)
        UserDefaults.standard.removeObject(forKey: userAvatarUrlKey)
    }
}
