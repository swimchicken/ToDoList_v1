import Foundation
import CloudKit

class LoginStatusChecker {
    static let shared = LoginStatusChecker()
    
    enum Destination {
        case home, login
    }
    
    // 移除時間閾值限制，一次登入永久有效（直到用戶主動登出或清除數據）
    // private let sessionDuration: TimeInterval = 300 // 已移除

    func checkLoginStatus(completion: @escaping (Destination) -> Void) {
        // 檢查是否有持久化的登入狀態
        let hasPersistedLogin = UserDefaults.standard.bool(forKey: "hasPersistedLogin")
        
        // 取得儲存的 Apple 授權 ID
        guard let userId = UserDefaults.standard.string(forKey: "appleAuthorizedUserId") else {
            print("LoginStatusChecker: 無Apple用戶ID，導向登入頁面")
            completion(.login)
            return
        }
        
        // 如果有持久化登入狀態，直接進入主頁
        if hasPersistedLogin {
            print("LoginStatusChecker: 檢測到持久化登入狀態，直接進入主頁")
            completion(.home)
            return
        }
        
        // 否則檢查雲端用戶記錄（僅用於首次登入驗證）
        print("LoginStatusChecker: 首次登入驗證，檢查雲端用戶記錄")
        performLoginStatusQuery(userId: userId, completion: completion)
    }
    
    /// 執行實際的登入狀態查詢（僅用於首次登入驗證）
    private func performLoginStatusQuery(userId: String, completion: @escaping (Destination) -> Void) {
        let privateDatabase = CKContainer(identifier: "iCloud.com.fcu.ToDolist1").privateCloudDatabase
        let predicate = NSPredicate(format: "providerUserID == %@ AND provider == %@", userId, "Apple")
        let query = CKQuery(recordType: "ApiUser", predicate: predicate)
        let defaultZoneID = CKRecordZone.default().zoneID
        print("LoginStatusChecker: 執行首次登入驗證查詢: \(query)")
        
        // 採用預設 zone，inZoneWith 傳 nil
        privateDatabase.fetch(withQuery: query, inZoneWith: defaultZoneID, desiredKeys: nil, resultsLimit: 1) { result in
            switch result {
            case .success(let queryResult):
                if let record = queryResult.matchResults.compactMap({ try? $0.1.get() }).first {
                    print("LoginStatusChecker: 找到用戶記錄，設置持久化登入狀態")
                    
                    DispatchQueue.main.async {
                        // 找到用戶記錄，設置持久化登入狀態
                        UserDefaults.standard.set(true, forKey: "hasPersistedLogin")
                        completion(.home)
                    }
                } else {
                    print("LoginStatusChecker: 找不到用戶記錄，可能是新用戶")
                    DispatchQueue.main.async {
                        completion(.login)
                    }
                }
            case .failure(let error):
                print("登入狀態查詢錯誤：\(error.localizedDescription)")
                
                // CloudKit錯誤時，如果本地有Apple ID就信任並設置持久化狀態
                let nsError = error as NSError
                if nsError.domain == CKErrorDomain || error.localizedDescription.contains("auth token") {
                    print("LoginStatusChecker: CloudKit不可用但有Apple ID，設置持久化登入狀態")
                    DispatchQueue.main.async {
                        UserDefaults.standard.set(true, forKey: "hasPersistedLogin")
                        completion(.home)
                    }
                } else {
                    print("LoginStatusChecker: 其他錯誤，返回登入頁面")
                    DispatchQueue.main.async {
                        completion(.login)
                    }
                }
            }
        }
    }
    
    /// 清除持久化登入狀態（用戶主動登出時調用）
    func clearPersistedLogin() {
        UserDefaults.standard.removeObject(forKey: "hasPersistedLogin")
        UserDefaults.standard.removeObject(forKey: "appleAuthorizedUserId")
        print("LoginStatusChecker: 已清除持久化登入狀態")
    }
}
