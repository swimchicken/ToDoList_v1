//  SaveLast.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/3/30.
//

import Foundation
import CloudKit

class SaveLast {
    /// 根據傳入的 Apple 用戶 ID 更新 CloudKit 中 ApiUser 記錄的 lastLoginDate 並設定 guidedInputCompleted 為 1
    static func updateLastLoginDate(forUserId userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let container = CKContainer(identifier: "iCloud.com.fcu.ToDolist1")
        let privateDatabase = container.privateCloudDatabase
        
        // 使用預設區域 (_defaultZone)
        let defaultZoneID = CKRecordZone.default().zoneID
        
        // 使用 providerUserID 和 provider 來查詢記錄
        let predicate = NSPredicate(format: "providerUserID == %@ AND provider == %@", userId, "Apple")
        let query = CKQuery(recordType: "ApiUser", predicate: predicate)
        
        // 查詢指定預設區的資料
        privateDatabase.fetch(withQuery: query, inZoneWith: defaultZoneID, desiredKeys: nil, resultsLimit: 1) { result in
            switch result {
            case .success(let queryResult):
                guard let record = queryResult.matchResults.compactMap({ try? $0.1.get() }).first else {
                    let notFoundError = NSError(domain: "SaveLast", code: 404, userInfo: [NSLocalizedDescriptionKey: "找不到對應的記錄"])
                    completion(.failure(notFoundError))
                    return
                }
                // 更新 lastLoginDate 和 guidedInputCompleted 欄位
                record["lastLoginDate"] = Date() as CKRecordValue
                record["guidedInputCompleted"] = 1 as CKRecordValue  // 設置 guidedInputCompleted 為 1
                
                // 儲存更新的記錄
                privateDatabase.save(record) { _, error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
