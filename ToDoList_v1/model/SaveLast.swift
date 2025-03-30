//
//  SaveLast.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/3/30.
//

import Foundation
import CloudKit

class SaveLast {
    /// 根據傳入的 Apple 用戶 ID 更新 CloudKit 中 ThirdPartyLogin 記錄的 lastLoginDate
    static func updateLastLoginDate(forUserId userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let container = CKContainer(identifier: "iCloud.com.fcu.ToDolist1")
        let privateDatabase = container.privateCloudDatabase
        // 使用 providerUserID 與 provider ("Apple") 進行查詢
        let predicate = NSPredicate(format: "providerUserID == %@ AND provider == %@", userId, "Apple")
        let query = CKQuery(recordType: "ApiUser", predicate: predicate)
        
        privateDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { result in
            switch result {
            case .success(let queryResult):
                guard let record = queryResult.matchResults.compactMap({ try? $0.1.get() }).first else {
                    let notFoundError = NSError(domain: "SaveLast", code: 404, userInfo: [NSLocalizedDescriptionKey: "找不到對應的記錄"])
                    completion(.failure(notFoundError))
                    return
                }
                // 更新 lastLoginDate 為目前時間
                record["lastLoginDate"] = Date() as CKRecordValue
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
