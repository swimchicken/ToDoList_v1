import CloudKit
import Foundation
import CryptoKit

class EmailChecker {
    static let shared = EmailChecker()
    
    private let privateDatabase = CKContainer(identifier: "iCloud.com.fcu.ToDolist1").privateCloudDatabase
    private let customZoneID = CKRecordZone.ID(zoneName: "new_zone", ownerName: CKCurrentUserDefaultName)
    
    /// 檢查 email 是否存在於 NormalUser 資料表中
    func checkEmailExists(email: String, completion: @escaping (Bool) -> Void) {
        let predicate = NSPredicate(format: "email == %@", email)
        let query = CKQuery(recordType: "NormalUser", predicate: predicate)
        
        privateDatabase.fetch(withQuery: query, inZoneWith: customZoneID, desiredKeys: nil, resultsLimit: 1) { result in
            switch result {
            case .success(let qr):
                let exists = !qr.matchResults.compactMap { try? $0.1.get() }.isEmpty
                completion(exists)
            case .failure:
                completion(false)
            }
        }
    }
    
    /// 對密碼做 SHA-256 雜湊
    private func hashPassword(_ password: String) -> String {
        let data = Data(password.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    /// 使用 email 與密碼登入，比對 hash
    func loginWithEmail(email: String, password: String, completion: @escaping (Bool) -> Void) {
        let predicate = NSPredicate(format: "email == %@", email)
        let query = CKQuery(recordType: "NormalUser", predicate: predicate)
        
        privateDatabase.fetch(withQuery: query, inZoneWith: customZoneID, desiredKeys: ["passwordHash"], resultsLimit: 1) { result in
            switch result {
            case .success(let qr):
                guard let record = qr.matchResults.compactMap({ try? $0.1.get() }).first,
                      let storedHash = record["passwordHash"] as? String
                else {
                    completion(false)
                    return
                }
                let inputHash = self.hashPassword(password)
                completion(inputHash == storedHash)
                
            case .failure:
                completion(false)
            }
        }
    }
}
