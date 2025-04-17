import SwiftUI
import SpriteKit

class PhysicsScene: SKScene {
    private let itemsCount: Int

    init(size: CGSize, itemsCount: Int) {
        self.itemsCount = itemsCount
        super.init(size: size)

        // 1) 讓 SKView 背景透明
        backgroundColor = .clear
        // 2) 下面我們也會在 Home 裡面把 SKView 的 UIView 背景設為 .clear

        scaleMode = .resizeFill
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) 未實作")
    }

    override func didMove(to view: SKView) {
        // 1. 設重力
        physicsWorld.gravity = CGVector(dx: 0, dy: -9.8)

        // 2. 整個場景只有一條「地面邊緣」，放在 y=0
        let floor = SKNode()
        floor.physicsBody = SKPhysicsBody(
            edgeFrom: CGPoint(x: 0, y: 0),
            to:   CGPoint(x: size.width, y: 0)
        )
        floor.physicsBody?.isDynamic = false
        addChild(floor)

        // 3. 生成 BumpyCircle nodes
        let diameter: CGFloat = 40
        for i in 0..<itemsCount {
            let circlePath = BumpyCircle(bumps: 13, bumpOffset: 9)
                .path(in: CGRect(x: 0, y: 0, width: diameter, height: diameter))

            let node = SKShapeNode(path: circlePath.cgPath)
            node.fillColor   = SKColor.white.withAlphaComponent(0.6)
            node.strokeColor = .clear

            // x 均分
            let x = diameter/2 + (size.width - diameter) * CGFloat(i) / CGFloat(max(1, itemsCount - 1))
            // y 初始置頂
            node.position = CGPoint(x: x, y: size.height - diameter/2)

            // 物理身體
            node.physicsBody = SKPhysicsBody(polygonFrom: circlePath.cgPath)
            node.physicsBody?.restitution = 0.6
            node.physicsBody?.friction    = 0.4

            addChild(node)
        }
    }
}
