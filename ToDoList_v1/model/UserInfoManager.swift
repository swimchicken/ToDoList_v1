import Foundation
import CloudKit

// MARK: - 用戶信息數據模型
struct UserInfo {
    let name: String
    let email: String
    let avatarImageName: String?

    init(name: String = "Loading...", email: String = "...", avatarImageName: String? = nil) {
        self.name = name
        self.email = email
        self.avatarImageName = avatarImageName
    }
}

// MARK: - 用戶信息管理器
class UserInfoManager: ObservableObject {
    @Published var userInfo: UserInfo = UserInfo()
    @Published var isLoading: Bool = true

    static let shared = UserInfoManager()

    private init() {
        loadUserInfo()
    }

    // MARK: - 載入用戶信息
    func loadUserInfo() {
        print("[UserInfoManager] 開始載入用戶信息...")
        isLoading = true

        // 先嘗試從本地 UserDefaults 載入基本信息
        loadFromUserDefaults()

        // 然後從 CloudKit 載入完整信息
        fetchFromCloudKit()
    }

    // MARK: - 從 UserDefaults 載入基本信息
    private func loadFromUserDefaults() {
        let storedName = UserDefaults.standard.string(forKey: "userName")
        let storedEmail = UserDefaults.standard.string(forKey: "userEmail")

        if let name = storedName, let email = storedEmail {
            DispatchQueue.main.async {
                self.userInfo = UserInfo(name: name, email: email)
                print("[UserInfoManager] 從 UserDefaults 載入用戶信息: \(name), \(email)")
            }
        }
    }

    // MARK: - 從 CloudKit 獲取用戶信息
    private func fetchFromCloudKit() {
        // 獲取用戶 ID（Apple 或 Google 登入）
        guard let userID = getCurrentUserID() else {
            print("[UserInfoManager] 無法獲取用戶 ID")
            DispatchQueue.main.async {
                self.isLoading = false
            }
            return
        }

        print("[UserInfoManager] 使用用戶 ID 從 CloudKit 獲取信息: \(userID)")

        // 從 ApiUser 表獲取用戶信息
        fetchFromApiUser(userID: userID) { [weak self] success in
            if !success {
                // 如果 ApiUser 表沒有找到，嘗試從 PersonalData 表獲取
                self?.fetchFromPersonalData(userID: userID)
            } else {
                DispatchQueue.main.async {
                    self?.isLoading = false
                }
            }
        }
    }

    // MARK: - 獲取當前用戶 ID
    private func getCurrentUserID() -> String? {
        // 優先使用 Apple ID
        if let appleUserID = UserDefaults.standard.string(forKey: "appleAuthorizedUserId") {
            return appleUserID
        }

        // 然後使用 Google ID
        if let googleUserID = UserDefaults.standard.string(forKey: "googleAuthorizedUserId") {
            return googleUserID
        }

        return nil
    }

    // MARK: - 從 ApiUser (私有數據庫) 獲取用戶信息
    private func fetchFromApiUser(userID: String, completion: @escaping (Bool) -> Void) {
        let container = CKContainer(identifier: "iCloud.com.fcu.ToDolist1")
        let privateDatabase = container.privateCloudDatabase

        // 判斷是 Apple 還是 Google 登入
        let provider = UserDefaults.standard.string(forKey: "appleAuthorizedUserId") != nil ? "Apple" : "Google"

        let predicate = NSPredicate(format: "providerUserID == %@ AND provider == %@", userID, provider)
        let query = CKQuery(recordType: "ApiUser", predicate: predicate)

        privateDatabase.perform(query, inZoneWith: CKRecordZone.default().zoneID) { [weak self] records, error in
            if let error = error {
                print("[UserInfoManager] ApiUser 查詢失敗: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }

            guard let record = records?.first else {
                print("[UserInfoManager] ApiUser 中未找到用戶記錄")
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }

            let name = record["name"] as? String ?? "Unknown User"
            let email = record["email"] as? String ?? "Unknown Email"

            DispatchQueue.main.async {
                self?.userInfo = UserInfo(name: name, email: email)
                self?.saveToUserDefaults(name: name, email: email)
                print("[UserInfoManager] 從 ApiUser 更新用戶信息: \(name), \(email)")
                completion(true)
            }
        }
    }

    // MARK: - 從 PersonalData (私有數據庫) 獲取用戶信息
    private func fetchFromPersonalData(userID: String) {
        let container = CKContainer(identifier: "iCloud.com.fcu.ToDolist1")
        let privateDatabase = container.privateCloudDatabase

        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: "PersonalData", predicate: predicate)

        privateDatabase.perform(query, inZoneWith: CKRecordZone.default().zoneID) { [weak self] records, error in
            DispatchQueue.main.async {
                self?.isLoading = false
            }

            if let error = error {
                print("[UserInfoManager] PersonalData 查詢失敗: \(error.localizedDescription)")
                return
            }

            guard let record = records?.first else {
                print("[UserInfoManager] PersonalData 中未找到用戶記錄")
                return
            }

            let name = record["name"] as? String ?? "Unknown User"

            // PersonalData 中可能沒有 email，使用用戶 ID 作為 email 的占位符
            let email = self?.extractEmailFromUserID(userID) ?? "Unknown Email"

            DispatchQueue.main.async {
                self?.userInfo = UserInfo(name: name, email: email)
                self?.saveToUserDefaults(name: name, email: email)
                print("[UserInfoManager] 從 PersonalData 更新用戶信息: \(name), \(email)")
            }
        }
    }

    // MARK: - 從用戶 ID 提取 email（如果是 email 格式）
    private func extractEmailFromUserID(_ userID: String) -> String {
        // 如果 userID 本身就是 email 格式（Google 登入的情況），直接使用
        if userID.contains("@") {
            return userID
        }

        // 否則返回占位符
        return "Unknown Email"
    }

    // MARK: - 保存到 UserDefaults
    private func saveToUserDefaults(name: String, email: String) {
        UserDefaults.standard.set(name, forKey: "userName")
        UserDefaults.standard.set(email, forKey: "userEmail")
        print("[UserInfoManager] 用戶信息已保存到 UserDefaults")
    }

    // MARK: - 更新用戶名稱
    func updateUserName(_ newName: String, completion: @escaping (Bool) -> Void) {
        guard let userID = getCurrentUserID() else {
            completion(false)
            return
        }

        // 更新 ApiUser 表
        updateNameInApiUser(userID: userID, newName: newName) { [weak self] success in
            if success {
                // 同時更新 PersonalData 表
                self?.updateNameInPersonalData(userID: userID, newName: newName) { _ in
                    // 不管 PersonalData 更新是否成功，都更新本地狀態
                    DispatchQueue.main.async {
                        let currentEmail = self?.userInfo.email ?? "Unknown Email"
                        self?.userInfo = UserInfo(name: newName, email: currentEmail)
                        self?.saveToUserDefaults(name: newName, email: currentEmail)
                        completion(true)
                    }
                }
            } else {
                completion(false)
            }
        }
    }

    // MARK: - 更新 ApiUser 表中的用戶名稱
    private func updateNameInApiUser(userID: String, newName: String, completion: @escaping (Bool) -> Void) {
        let container = CKContainer(identifier: "iCloud.com.fcu.ToDolist1")
        let privateDatabase = container.privateCloudDatabase

        // 判斷是 Apple 還是 Google 登入
        let provider = UserDefaults.standard.string(forKey: "appleAuthorizedUserId") != nil ? "Apple" : "Google"

        let predicate = NSPredicate(format: "providerUserID == %@ AND provider == %@", userID, provider)
        let query = CKQuery(recordType: "ApiUser", predicate: predicate)

        privateDatabase.perform(query, inZoneWith: CKRecordZone.default().zoneID) { records, error in
            if let error = error {
                print("[UserInfoManager] 更新 ApiUser 名稱失敗: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }

            guard let record = records?.first else {
                print("[UserInfoManager] ApiUser 中未找到用戶記錄")
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }

            record["name"] = newName as CKRecordValue

            privateDatabase.save(record) { savedRecord, error in
                if let error = error {
                    print("[UserInfoManager] 保存 ApiUser 名稱失敗: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        completion(false)
                    }
                } else {
                    print("[UserInfoManager] ApiUser 名稱更新成功")
                    DispatchQueue.main.async {
                        completion(true)
                    }
                }
            }
        }
    }

    // MARK: - 更新 PersonalData 表中的用戶名稱
    private func updateNameInPersonalData(userID: String, newName: String, completion: @escaping (Bool) -> Void) {
        let data: [String: CKRecordValue] = [
            "name": newName as CKRecordValue
        ]

        CloudKitManager.shared.saveOrUpdateUserData(recordType: "PersonalData", userID: userID, data: data) { success, error in
            if success {
                print("[UserInfoManager] PersonalData 名稱更新成功")
                completion(true)
            } else if let error = error {
                print("[UserInfoManager] PersonalData 名稱更新失敗: \(error.localizedDescription)")
                completion(false)
            }
        }
    }

    // MARK: - 刷新用戶信息
    func refreshUserInfo() {
        print("[UserInfoManager] 手動刷新用戶信息")
        loadUserInfo()
    }

    // MARK: - 清除用戶信息（登出時使用）
    func clearUserInfo() {
        DispatchQueue.main.async {
            self.userInfo = UserInfo()
            self.isLoading = false
        }

        UserDefaults.standard.removeObject(forKey: "userName")
        UserDefaults.standard.removeObject(forKey: "userEmail")
        print("[UserInfoManager] 用戶信息已清除")
    }
}