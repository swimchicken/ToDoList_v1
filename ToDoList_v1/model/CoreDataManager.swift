//
//  CoreDataManager.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/5/10.
//

import Foundation
import CoreData

/// CoreData 管理器 - 用於本地持久化存儲
/// 注意：由於您選擇了混合模式，我們保留此核心數據結構，但主要使用 LocalDataManager 進行操作
class CoreDataManager {
    // MARK: - 單例模式
    static let shared = CoreDataManager()
    
    // MARK: - Core Data 堆棧
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "TodoItems")
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("無法加載持久化存儲：\(error), \(error.userInfo)")
            }
        }
        return container
    }()
    
    // MARK: - CoreData 上下文
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - 初始化
    private init() {
        print("DEBUG: 初始化 CoreDataManager")
    }
    
    // MARK: - 核心數據操作方法
    
    /// 保存上下文變更
    func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
                print("DEBUG: 成功保存 CoreData 上下文")
            } catch {
                let nsError = error as NSError
                print("ERROR: 保存 CoreData 上下文失敗: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    /// 創建空的待辦事項數據模型
    /// 這個功能保留以供將來擴展，目前使用 LocalDataManager 進行操作
    func createEmptyTodoItemModel() {
        // 由於我們使用 UserDefaults 存儲和 CloudKit 同步，
        // 此方法保留為未來擴展做準備，目前僅作為占位符
        print("INFO: 創建空的待辦事項數據模型功能已保留")
    }
    
    /// 將 TodoItem 轉換為 Core Data 實體
    /// 這個功能保留以供將來擴展，目前使用 LocalDataManager 進行操作
    func convertToEntity(_ todoItem: TodoItem) {
        // 由於我們使用 UserDefaults 存儲和 CloudKit 同步，
        // 此方法保留為未來擴展做準備，目前僅作為占位符
        print("INFO: CoreData 轉換功能已保留以供將來擴展")
    }
}
