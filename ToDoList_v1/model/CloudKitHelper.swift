//
//  CloudKitHelper.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/4/15.
//
import CloudKit

struct CloudKitHelper {
    /// 檢查並建立指定的 CloudKit zone
    static func createZoneIfNeeded(database: CKDatabase, zoneID: CKRecordZone.ID, completion: @escaping (Bool) -> Void) {
        let zone = CKRecordZone(zoneID: zoneID)
        let modifyZonesOp = CKModifyRecordZonesOperation(recordZonesToSave: [zone], recordZoneIDsToDelete: nil)
        modifyZonesOp.modifyRecordZonesCompletionBlock = { savedZones, deletedZoneIDs, error in
            if let error = error {
                completion(false)
            } else {
                completion(true)
            }
        }
        database.add(modifyZonesOp)
    }
}
