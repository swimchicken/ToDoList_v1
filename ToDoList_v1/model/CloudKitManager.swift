import SwiftUI
import CloudKit

class CloudKitManager {
    static let shared = CloudKitManager()
    
    // 使用 privateCloudDatabase，不再指定自訂的 zone，改用預設 zone
    private let privateDatabase = CKContainer(identifier: "iCloud.com.fcu.ToDolist1").privateCloudDatabase
    
    /// 儲存或更新資料到 privateCloudDatabase 中的 PersonalData
    /// 會以 userIDString 來判斷是否已有記錄，若有則更新，否則新建記錄
    func saveOrUpdateUserData(recordType: String, userID: String, data: [String: CKRecordValue], completion: @escaping (Bool, Error?) -> Void) {
        // 用 userID 進行查詢
        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: recordType, predicate: predicate)
//        defaultZoneID
        // 使用預設的 zoneID 進行查詢
        privateDatabase.perform(query, inZoneWith: CKRecordZone.default().zoneID) { records, error in
            if let error = error {
                completion(false, error)
                return
            }
            
            if let record = records?.first {
                // 找到記錄，更新資料欄位
                for (key, value) in data {
                    record[key] = value
                }
                self.privateDatabase.save(record) { savedRecord, error in
                    if let error = error {
                        completion(false, error)
                    } else {
                        completion(true, nil)
                    }
                }
            } 
            else {
                // 沒有記錄，建立新記錄
                let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: CKRecordZone.default().zoneID)
                let record = CKRecord(recordType: recordType, recordID: recordID)
                // 確保包含 userID 欄位
                record["userID"] = userID as CKRecordValue
                for (key, value) in data {
                    record[key] = value
                }
                self.privateDatabase.save(record) { savedRecord, error in
                    if let error = error {
                        completion(false, error)
                    } else {
                        completion(true, nil)
                    }
                }
            }
        }
    }
}
