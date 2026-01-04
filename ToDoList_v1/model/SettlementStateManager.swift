import Foundation

class SettlementStateManager: ObservableObject {
    static let shared = SettlementStateManager()
    private init() {}

    // 這裡存放原本在 SettlementView02 的暫存資料
    @Published var pendingOperations: [SettlementOperation] = []
    @Published var tempAddedItems: [TodoItem] = []
    @Published var tempDeletedItemIDs: Set<UUID> = []

    // ✅ 用於樂觀更新的已完成操作記錄
    @Published var completedOperations: [SettlementOperation] = []
    // ✅ 新增：用於樂觀更新的已移動任務
    @Published var movedItems: [TodoItem] = []


    // 清空資料 (用於回到首頁或結算完成時)
    func reset() {
        // ✅ 在清空前，將待處理操作移至已完成記錄中
        completedOperations = pendingOperations
        
        // 注意：movedItems 不在這裡賦值，它由 S03 明確設置
        
        pendingOperations = []
        tempAddedItems = []
        tempDeletedItemIDs = []
    }
}
