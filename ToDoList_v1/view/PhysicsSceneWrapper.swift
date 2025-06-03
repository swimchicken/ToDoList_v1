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
        print("PhysicsSceneWrapper - 創建場景: 項目數量=\(todoItems.count)")
        return PhysicsScene(
            size: CGSize(width: 369, height: 100),
            todoItems: todoItems
        )
    }
    
    // 生成物理場景的唯一ID
    private func generateSceneId() -> String {
        // 1. 項目數量部分
        let countPart = "\(todoItems.count)"
        
        // 2. 狀態部分 - 簡化為統計各狀態的數量
        var completedCount = 0
        var toBeStartedCount = 0
        var undoneCount = 0
        var todoListCount = 0
        
        for item in todoItems {
            switch item.status {
            case .completed:
                completedCount += 1
            case .toBeStarted:
                toBeStartedCount += 1
            case .undone:
                undoneCount += 1
            case .toDoList:
                todoListCount += 1
            }
        }
        
        let statusPart = "c\(completedCount)t\(toBeStartedCount)u\(undoneCount)l\(todoListCount)"
        
        // 3. 刷新令牌部分 - 使用較短的雜湊值
        let tokenPart = "\(refreshToken.hashValue)"
        
        // 合併所有部分
        return "\(countPart)-\(statusPart)-\(tokenPart)"
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