// EmailAccountManager.swift
// ToDoList_v1
//
// Created by swimchichen on 2025/4/6.
//

import CloudKit
import Foundation
import CryptoKit

class EmailAccountManager {
    static let shared = EmailAccountManager()
    
    // 使用 privateCloudDatabase 並指定 custom zone
    private let privateDatabase = CKContainer(identifier: "iCloud.com.fcu.ToDolist1").privateCloudDatabase
    private let customZoneID = CKRecordZone.ID(zoneName: "new_zone", ownerName: CKCurrentUserDefaultName)
    
    /// 對密碼做 SHA-256 雜湊，並回傳十六進位字串
    private func hashPassword(_ password: String) -> String {
        let data = Data(password.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    /// 建立新的 Email 帳號
    func createEmailAccount(email: String, password: String, completion: @escaping (Bool, Error?) -> Void) {
        // 在 custom zone 中建立 recordID
        let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: customZoneID)
        let record = CKRecord(recordType: "NormalUser", recordID: recordID)
        let now = Date()
        let passwordHash = hashPassword(password)
        
        record["createdAt"]  = now as CKRecordValue
        record["updatedAt"]  = now as CKRecordValue
        record["email"] = email as CKRecordValue
        record["passwordHash"]  = passwordHash as CKRecordValue
        record["emailVerified"]    = 0 as CKRecordValue
        record["recordID"]      = recordID.recordName as CKRecordValue
        
        privateDatabase.save(record) { savedRecord, error in
            if let error = error {
                completion(false, error)
            } else {
                completion(true, nil)
            }
        }
    }
    
    /// 驗證 Email 帳號（假設正確驗證碼為 "1234"）
    func verifyEmailAccount(email: String, code: String, completion: @escaping (Bool, Error?) -> Void) {
        let predicate = NSPredicate(format: "email == %@", email)
        let query = CKQuery(recordType: "NormalUser", predicate: predicate)
        
        privateDatabase.fetch(withQuery: query, inZoneWith: customZoneID, desiredKeys: nil, resultsLimit: 1) { result in
            switch result {
            case .success(let queryResult):
                guard let record = queryResult.matchResults.compactMap({ try? $0.1.get() }).first else {
                    completion(false, nil)
                    return
                }
                if code == "1234" {
                    record["emailVerified"]    = 1 as CKRecordValue
                    record["updatedAt"]  = Date() as CKRecordValue
                    self.privateDatabase.save(record) { _, error in
                        if let error = error {
                            completion(false, error)
                        } else {
                            completion(true, nil)
                        }
                    }
                } else {
                    completion(false, nil)
                }
            case .failure(let error):
                completion(false, error)
            }
        }
    }
    
    /// 使用 email 與密碼登入
    func loginWithEmail(email: String, password: String, completion: @escaping (Bool) -> Void) {
        let predicate = NSPredicate(format: "email == %@", email)
        let query = CKQuery(recordType: "NormalUser", predicate: predicate)
        
        privateDatabase.fetch(withQuery: query, inZoneWith: customZoneID, desiredKeys: ["passwordHash"], resultsLimit: 1) { result in
            switch result {
            case .success(let queryResult):
                guard let record = queryResult.matchResults.compactMap({ try? $0.1.get() }).first,
                      let storedHash = record["passwordHash"] as? String
                else {
                    completion(false)
                    return
                }
                let inputHash = self.hashPassword(password)
                completion(inputHash == storedHash)
            case .failure(let error):
                completion(false)
            }
        }
    }
}
