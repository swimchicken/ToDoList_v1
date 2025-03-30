import Foundation
import CloudKit

class LoginStatusChecker {
    static let shared = LoginStatusChecker()
    
    enum Destination {
        case onboarding, home, login
    }

    func checkLoginStatus(completion: @escaping (Destination) -> Void) {
        guard let userId = UserDefaults.standard.string(forKey: "appleAuthorizedUserId") else {
            completion(.login)
            return
        }
        
        let privateDatabase = CKContainer(identifier: "iCloud.com.fcu.ToDolist1").privateCloudDatabase
        let predicate = NSPredicate(format: "providerUserID == %@ AND provider == %@", userId, "Apple")
        let query = CKQuery(recordType: "ApiUser", predicate: predicate)
        
        privateDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { result in
            switch result {
            case .success(let queryResult):
                if let record = queryResult.matchResults.compactMap({ try? $0.1.get() }).first {
                    let guidedInputCompleted = record["guidedInputCompleted"] as? Bool ?? false
                    let lastLogin = record["lastLoginDate"] as? Date
                    let now = Date()
                    let calendar = Calendar.current
                    
                    DispatchQueue.main.async {
                        if !guidedInputCompleted {
                            completion(.onboarding)
                        } else if let lastLogin = lastLogin, calendar.isDate(lastLogin, inSameDayAs: now) {
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
