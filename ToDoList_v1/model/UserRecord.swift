//
//  UserRecord.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/2/23.
//

import CloudKit

struct UserRecord {
    static let recordType = "AppUser"
    
    var name: String
    var email: String
    
    // init record
    init(record: CKRecord) {
        self.name = record["name"] as? String ?? ""
        self.email = record["email"] as? String ?? ""
    }
    
    
    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: UserRecord.recordType)
        record["name"] = name as NSString
        record["email"] = email as NSString
        return record
    }
}
