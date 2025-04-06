import SwiftUI
import CloudKit

class CloudKitManager {
    static let shared = CloudKitManager()
    
    // 使用 privateCloudDatabase 並指定自訂的 zone
    private let privateDatabase = CKContainer(identifier: "iCloud.com.fcu.ToDolist1").privateCloudDatabase
    private let customZoneID = CKRecordZone.ID(zoneName: "new_zone", ownerName: CKCurrentUserDefaultName)
    
    /// 儲存或更新資料到 privateCloudDatabase 中的 PersonalData
    /// 會以 userIDString 來判斷是否已有記錄，若有則更新，否則新建記錄
    func saveOrUpdateUserData(recordType: String, userID: String, data: [String: CKRecordValue], completion: @escaping (Bool, Error?) -> Void) {
        // 用 userIDString 進行查詢
        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        
        privateDatabase.perform(query, inZoneWith: customZoneID) { records, error in
            if let error = error {
                print("查詢資料錯誤: \(error.localizedDescription)")
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
                        print("更新資料錯誤: \(error.localizedDescription)")
                        completion(false, error)
                    } else {
                        print("資料更新成功!")
                        completion(true, nil)
                    }
                }
            } else {
                // 沒有記錄，建立新記錄
                let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: self.customZoneID)
                let record = CKRecord(recordType: recordType, recordID: recordID)
                // 確保包含 userIDString
                record["userID"] = userID as CKRecordValue
                for (key, value) in data {
                    record[key] = value
                }
                self.privateDatabase.save(record) { savedRecord, error in
                    if let error = error {
                        print("建立新資料錯誤: \(error.localizedDescription)")
                        completion(false, error)
                    } else {
                        print("建立新資料成功!")
                        completion(true, nil)
                    }
                }
            }
        }
    }
}
