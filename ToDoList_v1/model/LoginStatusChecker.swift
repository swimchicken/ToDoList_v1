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
                DispatchQueue.main.async {
                    completion(.login)
                }
            }
        }
    }
}
