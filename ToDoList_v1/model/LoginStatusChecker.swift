import Foundation
import CloudKit

class LoginStatusChecker {
    static let shared = LoginStatusChecker()
    
    enum Destination {
        case home, login
    }
    
    // 設定最近登入的時間閾值：300 秒（5 分鐘）
    private let sessionDuration: TimeInterval = 300

    func checkLoginStatus(completion: @escaping (Destination) -> Void) {
        // 取得儲存的 Apple 授權 ID
        guard let userId = UserDefaults.standard.string(forKey: "appleAuthorizedUserId") else {
            completion(.login)
            return
        }
        
        // 先確保 CloudKit 認證狀態正常
        let cloudKitService = CloudKitService.shared
        
        // 直接執行查詢，如果失敗就返回登入頁面
        performLoginStatusQuery(userId: userId, completion: completion)
    }
    
    /// 執行實際的登入狀態查詢
    private func performLoginStatusQuery(userId: String, completion: @escaping (Destination) -> Void) {
        let privateDatabase = CKContainer(identifier: "iCloud.com.fcu.ToDolist1").privateCloudDatabase
        let predicate = NSPredicate(format: "providerUserID == %@ AND provider == %@", userId, "Apple")
        let query = CKQuery(recordType: "ApiUser", predicate: predicate)
        let defaultZoneID = CKRecordZone.default().zoneID
        print("\(query)")
        
        // 採用預設 zone，inZoneWith 傳 nil
        privateDatabase.fetch(withQuery: query, inZoneWith: defaultZoneID, desiredKeys: nil, resultsLimit: 1) { result in
            switch result {
            case .success(let queryResult):
                if let record = queryResult.matchResults.compactMap({ try? $0.1.get() }).first {
                    let lastLogin = record["lastLoginDate"] as? Date
                    let now = Date()
                    
                    DispatchQueue.main.async {
                        // 若 lastLogin 在 5 分鐘內，則視為已登入
                        if let lastLogin = lastLogin, now.timeIntervalSince(lastLogin) < self.sessionDuration {
                            completion(.home)
                        } else {
                            completion(.login)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.login)
                    }
                }
            case .failure(let error):
                print("登入狀態查詢錯誤：\(error.localizedDescription)")
                
                // 檢查是否是認證問題
                let nsError = error as NSError
                print("LoginStatusChecker: CloudKit 查詢失敗，返回登入頁面")
                DispatchQueue.main.async {
                    completion(.login)
                }
            }
        }
    }
}
