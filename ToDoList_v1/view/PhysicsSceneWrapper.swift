import SwiftUI
import SpriteKit

/// 物理場景包裝器：用於從Home.swift分離出物理場景邏輯
struct PhysicsSceneWrapper: View {
    // 接收待辦事項列表
    let todoItems: [TodoItem]
    
    // 用於更新視圖的令牌
    let refreshToken: UUID
    
    // 創建物理場景實例
    private var physicsScene: PhysicsScene {
        // 減少日誌輸出 - 只在項目數量變化時輸出
        // print("PhysicsSceneWrapper - 創建場景: 項目數量=\(todoItems.count)")
        return PhysicsScene(
            size: CGSize(width: 369, height: 100),
            todoItems: todoItems
        )
    }
    
    // 生成物理場景的唯一ID - 🔧 優化避免不必要的重建
    private func generateSceneId() -> String {
        // 1. 項目數量部分
        let countPart = "\(todoItems.count)"

        // 2. 狀態部分 - 🆕 使用新的 completionStatus 統計
        var completedCount = 0
        var pendingCount = 0

        for item in todoItems {
            switch item.completionStatus {
            case .completed:
                completedCount += 1
            case .pending:
                pendingCount += 1
            }
        }

        // 🔧 移除 refreshToken，只基於真實的數據變化
        let statusPart = "comp\(completedCount)pend\(pendingCount)"

        // 🆕 只有在真正影響球球渲染的數據變化時才重建場景
        return "\(countPart)-\(statusPart)"
    }
    
    var body: some View {
        // 物理場景視圖
        SpriteView(scene: physicsScene, options: [.allowsTransparency])
            .frame(width: 369, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 32))
            .background(Color.clear)
            // 使用簡化的ID來重新創建場景
            .id(generateSceneId())
    }
}