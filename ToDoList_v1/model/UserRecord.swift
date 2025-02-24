//
//  UserRecord.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/2/23.
//

import CloudKit

struct UserRecord {
    static let recordType = "User"
    
    var name: String
    var email: String
    
    // 由 CKRecord 建立模型
    init(record: CKRecord) {
        self.name = record["name"] as? String ?? ""
        self.email = record["email"] as? String ?? ""
    }
    
    // 將模型轉換成 CKRecord
    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: UserRecord.recordType)
        record["name"] = name as NSString
        record["email"] = email as NSString
        return record
    }
}
