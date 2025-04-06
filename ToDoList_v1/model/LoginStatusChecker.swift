import Foundation
import CloudKit

class LoginStatusChecker {
    static let shared = LoginStatusChecker()
    
    enum Destination {
        case home, login
    }
    
    // 定義自定義的 zone，請確認 "new_zone" 為你在 CloudKit 中所建立的 zone 名稱
    private let customZoneID = CKRecordZone.ID(zoneName: "new_zone", ownerName: CKCurrentUserDefaultName)
    
    // 設定最近登入的時間閾值，單位：秒 (此處 300 秒即 5 分鐘)
    private let sessionDuration: TimeInterval = 300

    func checkLoginStatus(completion: @escaping (Destination) -> Void) {
        // 取得使用者的 Apple 授權ID
        guard let userId = UserDefaults.standard.string(forKey: "appleAuthorizedUserId") else {
            completion(.login)
            return
        }
        
        let privateDatabase = CKContainer(identifier: "iCloud.com.fcu.ToDolist1").privateCloudDatabase
        let predicate = NSPredicate(format: "providerUserID == %@ AND provider == %@", userId, "Apple")
        let query = CKQuery(recordType: "ApiUser", predicate: predicate)
        
        // 指定自定義的 zone
        privateDatabase.fetch(withQuery: query, inZoneWith: customZoneID, desiredKeys: nil, resultsLimit: 1) { result in
            switch result {
            case .success(let queryResult):
                if let record = queryResult.matchResults.compactMap({ try? $0.1.get() }).first {
                    let lastLogin = record["lastLoginDate"] as? Date
                    let now = Date()
                    
                    DispatchQueue.main.async {
                        // 如果 lastLogin 存在，且距離現在在 5 分鐘內，就認定為最近登入，導向 Home
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
