//
//  CloudKitService.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/5/6.
//

import Foundation
import CloudKit

class CloudKitService {
    // MARK: - Properties
    static let shared = CloudKitService()
    
    // 設定公開資料庫及識別碼
    private let container: CKContainer
    private let publicDatabase: CKDatabase
    private let defaultZoneID = CKRecordZone.default().zoneID
    
    // MARK: - Initialization
    private init() {
        self.container = CKContainer(identifier: "iCloud.com.fcu.ToDolist1")
        self.publicDatabase = container.publicCloudDatabase
    }
    
    // MARK: - CRUD Operations
    
    /// 儲存待辦事項至 CloudKit
    /// - Parameters:
    ///   - todoItem: 待儲存的待辦事項
    ///   - completion: 完成後的回調，返回結果或錯誤
    func saveTodoItem(_ todoItem: TodoItem, completion: @escaping (Result<TodoItem, Error>) -> Void) {
        // 創建 CKRecord 物件
        let recordID = CKRecord.ID(recordName: todoItem.id.uuidString, zoneID: defaultZoneID)
        let record = CKRecord(recordType: "TodoItem", recordID: recordID)
        
        // 設置記錄欄位
        record.setValue(todoItem.id.uuidString, forKey: "id")
        record.setValue(todoItem.userID, forKey: "userID")
        record.setValue(todoItem.title, forKey: "title")
        record.setValue(todoItem.priority, forKey: "priority")
        record.setValue(todoItem.isPinned, forKey: "isPinned")
        record.setValue(todoItem.taskDate, forKey: "taskDate")
        record.setValue(todoItem.note, forKey: "note")
        record.setValue(todoItem.status.rawValue, forKey: "status")
        record.setValue(todoItem.createdAt, forKey: "createdAt")
        record.setValue(todoItem.updatedAt, forKey: "updatedAt")
        record.setValue(todoItem.correspondingImageID, forKey: "correspondingImageID")
        
        // 儲存到 CloudKit
        publicDatabase.save(record) { (savedRecord, error) in
            if let error = error {
                print("儲存待辦事項到 CloudKit 失敗: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let savedRecord = savedRecord else {
                let error = NSError(domain: "CloudKitService", code: 0, userInfo: [NSLocalizedDescriptionKey: "無法儲存記錄"])
                completion(.failure(error))
                return
            }
            
            // 從已儲存的記錄重新創建 TodoItem
            let savedTodoItem = self.todoItemFromRecord(savedRecord)
            completion(.success(savedTodoItem))
        }
    }
    
    /// 從 CloudKit 記錄轉換為 TodoItem 實例
    /// - Parameter record: CloudKit 記錄
    /// - Returns: TodoItem 實例
    private func todoItemFromRecord(_ record: CKRecord) -> TodoItem {
        // 從記錄中提取數據
        let id = UUID(uuidString: record.value(forKey: "id") as? String ?? "") ?? UUID()
        let userID = record.value(forKey: "userID") as? String ?? ""
        let title = record.value(forKey: "title") as? String ?? ""
        let priority = record.value(forKey: "priority") as? Int ?? 0
        let isPinned = record.value(forKey: "isPinned") as? Bool ?? false
        let taskDate = record.value(forKey: "taskDate") as? Date ?? Date()
        let note = record.value(forKey: "note") as? String ?? ""
        let statusRawValue = record.value(forKey: "status") as? String ?? TodoStatus.toDoList.rawValue
        let status = TodoStatus(rawValue: statusRawValue) ?? .toDoList
        let createdAt = record.value(forKey: "createdAt") as? Date ?? Date()
        let updatedAt = record.value(forKey: "updatedAt") as? Date ?? Date()
        let correspondingImageID = record.value(forKey: "correspondingImageID") as? String ?? ""
        
        // 創建並返回 TodoItem
        return TodoItem(
            id: id,
            userID: userID,
            title: title,
            priority: priority,
            isPinned: isPinned,
            taskDate: taskDate,
            note: note,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            correspondingImageID: correspondingImageID
        )
    }
    
    /// 從 CloudKit 獲取所有待辦事項
    /// - Parameter completion: 完成後的回調，返回結果或錯誤
    func fetchAllTodoItems(completion: @escaping (Result<[TodoItem], Error>) -> Void) {
        // 創建查詢
        let query = CKQuery(recordType: "TodoItem", predicate: NSPredicate(value: true))
        
        // 執行查詢
        publicDatabase.perform(query, inZoneWith: defaultZoneID) { (records, error) in
            if let error = error {
                print("從 CloudKit 獲取待辦事項失敗: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let records = records else {
                completion(.success([]))
                return
            }
            
            // 將記錄轉換為 TodoItem
            let todoItems = records.compactMap { self.todoItemFromRecord($0) }
            completion(.success(todoItems))
        }
    }
    
    /// 從 CloudKit 刪除待辦事項
    /// - Parameters:
    ///   - todoItemID: 待刪除的待辦事項 ID
    ///   - completion: 完成後的回調，返回成功或錯誤
    func deleteTodoItem(withID todoItemID: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        let recordID = CKRecord.ID(recordName: todoItemID.uuidString, zoneID: defaultZoneID)
        
        publicDatabase.delete(withRecordID: recordID) { (recordID, error) in
            if let error = error {
                print("從 CloudKit 刪除待辦事項失敗: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            completion(.success(()))
        }
    }
    
    /// 更新 CloudKit 中的待辦事項
    /// - Parameters:
    ///   - todoItem: 待更新的待辦事項
    ///   - completion: 完成後的回調，返回結果或錯誤
    func updateTodoItem(_ todoItem: TodoItem, completion: @escaping (Result<TodoItem, Error>) -> Void) {
        // 創建記錄 ID
        let recordID = CKRecord.ID(recordName: todoItem.id.uuidString, zoneID: defaultZoneID)
        
        // 先獲取現有記錄
        publicDatabase.fetch(withRecordID: recordID) { (record, error) in
            if let error = error {
                print("從 CloudKit 獲取待辦事項失敗: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard var record = record else {
                let error = NSError(domain: "CloudKitService", code: 0, userInfo: [NSLocalizedDescriptionKey: "找不到要更新的記錄"])
                completion(.failure(error))
                return
            }
            
            // 更新記錄欄位
            record.setValue(todoItem.userID, forKey: "userID")
            record.setValue(todoItem.title, forKey: "title")
            record.setValue(todoItem.priority, forKey: "priority")
            record.setValue(todoItem.isPinned, forKey: "isPinned")
            record.setValue(todoItem.taskDate, forKey: "taskDate")
            record.setValue(todoItem.note, forKey: "note")
            record.setValue(todoItem.status.rawValue, forKey: "status")
            record.setValue(todoItem.updatedAt, forKey: "updatedAt")
            record.setValue(todoItem.correspondingImageID, forKey: "correspondingImageID")
            
            // 儲存更新後的記錄
            self.publicDatabase.save(record) { (savedRecord, error) in
                if let error = error {
                    print("更新 CloudKit 中的待辦事項失敗: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let savedRecord = savedRecord else {
                    let error = NSError(domain: "CloudKitService", code: 0, userInfo: [NSLocalizedDescriptionKey: "無法儲存更新的記錄"])
                    completion(.failure(error))
                    return
                }
                
                // 返回更新後的 TodoItem
                let updatedTodoItem = self.todoItemFromRecord(savedRecord)
                completion(.success(updatedTodoItem))
            }
        }
    }
}
