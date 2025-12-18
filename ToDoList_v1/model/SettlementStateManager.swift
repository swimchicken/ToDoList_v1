//
//  SettlementStateManager.swift
//  ToDoList_v1
//
//  Created by 林子祐 on 2025/12/18.
//

import Foundation

class SettlementStateManager: ObservableObject {
    static let shared = SettlementStateManager()
    private init() {}

    // 這裡存放原本在 SettlementView02 的暫存資料
    @Published var pendingOperations: [SettlementOperation] = []
    @Published var tempAddedItems: [TodoItem] = []
    @Published var tempDeletedItemIDs: Set<UUID> = []

    // 清空資料 (用於回到首頁或結算完成時)
    func reset() {
        pendingOperations = []
        tempAddedItems = []
        tempDeletedItemIDs = []
        print("🗑️ SettlementStateManager 已重置 (暫存清空)")
    }
}
