import SwiftUI
import SpriteKit
import CryptoKit
import CoreMotion

class PhysicsScene: SKScene {
    private let itemsCount: Int
    private let todoItems: [TodoItem]
    private let motionManager = CMMotionManager()
    
    init(size: CGSize, todoItems: [TodoItem]) {
        self.todoItems = todoItems
        self.itemsCount = todoItems.count
        super.init(size: size)
        
        // 讓 SKView 背景透明
        backgroundColor = .clear
        scaleMode = .resizeFill
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) 未實作")
    }
    
    // 使用correspondingImageID创建一个确定性的随机种子
    private func createRandomGenerator(from seed: String) -> SeededRandomGenerator {
        let seedString = seed.isEmpty ? UUID().uuidString : seed
        return SeededRandomGenerator(seed: seedString)
    }
    override func willMove(from view: SKView) {
        super.willMove(from: view)
        motionManager.stopAccelerometerUpdates()
    }
    
    override func didMove(to view: SKView) {
        // 1. 設定重力 (修改為陀螺儀/加速度計控制)
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 1.0 / 60.0 // 60Hz 更新率
            motionManager.startAccelerometerUpdates(to: .main) { [weak self] (data, error) in
                guard let self = self, let data = data else { return }
                        
                // 重力倍率：數字越大，球對手機傾斜的反應越靈敏、掉落越快
                // 如果覺得球太輕，可以把 15.0 改成 20.0 或更高
                let gravityMultiplier: Double = 15.0
                        
                // 將手機的傾斜數據轉換為遊戲世界的重力向量
                let dx = data.acceleration.x * gravityMultiplier
                let dy = data.acceleration.y * gravityMultiplier
                        
                self.physicsWorld.gravity = CGVector(dx: dx, dy: dy)
            }
        } else {
            // 如果是模擬器或裝置不支援，使用預設重力
            physicsWorld.gravity = CGVector(dx: 0, dy: -3.5)
        }
        // 設置物理世界的其他屬性
        physicsWorld.speed = 0.8 // 降低模擬速度，使運動更加穩定
        
        // 2. 創建邊界 - 使用實際視圖大小
        let inset: CGFloat = 10
        let boundaryRect = CGRect(
            x: inset,
            y: inset,
            width: size.width - (inset * 2),
            height: size.height - (inset * 2)
        )
        
        let bounds = SKPhysicsBody(edgeLoopFrom: boundaryRect)
        bounds.friction = 0.4     // 增加邊界摩擦力
        bounds.restitution = 0.2  // 大幅降低邊界彈性係數，防止球體彈跳
        
        let boundsNode = SKNode()
        boundsNode.physicsBody = bounds
        boundsNode.physicsBody?.isDynamic = false
        addChild(boundsNode)
        
        // 3. 設置佈局參數 - 重新計算以確保更均勻的分佈
        let containerWidth = boundaryRect.width
        let containerHeight = boundaryRect.height
        
        // 固定為2行，以適應高度較小的容器
        let maxRows = 2
        let ballsPerRow = Int(ceil(Double(itemsCount) / Double(maxRows)))
        
        // 提高球體尺寸差異，同時確保不會超出容器
        let minBallDiameter: CGFloat = 18 // 降低最小直徑以增加差異
        let maxBallDiameter: CGFloat = min(50, containerHeight / 3)  // 增加最大直徑，但限制不超出容器高度
        let maxBallRadius: CGFloat = maxBallDiameter / 2
        let safeDistance: CGFloat = 3  // 進一步減小安全距離，使球體可以更緊密排列
        
        // 計算均勻分佈球體所需的間距
        let horizontalSpace = containerWidth - (CGFloat(ballsPerRow) * maxBallDiameter)
        let horizontalSpacing = max(5, horizontalSpace / CGFloat(ballsPerRow + 1))
        
        // 垂直間距確保球體在可見區域內
        let verticalSpace = containerHeight - (CGFloat(maxRows) * maxBallDiameter)
        let verticalSpacing = max(5, verticalSpace / CGFloat(maxRows + 1))
        
        // 每行的起始垂直位置
        let rowPositions: [CGFloat] = [
            boundaryRect.minY + verticalSpacing + maxBallRadius,  // 第一行
            boundaryRect.minY + (2 * verticalSpacing) + maxBallDiameter + maxBallRadius  // 第二行
        ]
        
        // 4. 生成 BumpyCircle nodes
        for i in 0..<itemsCount {
            // 獲取當前項目
            let todoItem = todoItems[i]
            
            // 使用correspondingImageID作為種子
            let randomGen = createRandomGenerator(from: todoItem.correspondingImageID)
            
            // 根據種子和優先級產生確定性的隨機大小
            // 高優先級項目生成更大的球體
            let diameterRange: ClosedRange<CGFloat>
            
            // 根據優先級調整直徑範圍
            if todoItem.isPinned {
                // 置頂項目使用較大尺寸範圍
                diameterRange = (maxBallDiameter * 0.7)...maxBallDiameter
            } else {
                switch todoItem.priority {
                    case 1: // 優先級1：較小
                        diameterRange = minBallDiameter...(minBallDiameter + (maxBallDiameter - minBallDiameter) * 0.4)
                    case 2: // 優先級2：中等
                        diameterRange = (minBallDiameter + (maxBallDiameter - minBallDiameter) * 0.3)...(minBallDiameter + (maxBallDiameter - minBallDiameter) * 0.7)
                    case 3: // 優先級3：較大
                        diameterRange = (minBallDiameter + (maxBallDiameter - minBallDiameter) * 0.6)...maxBallDiameter
                    default: // 預設或優先級0：較小
                        diameterRange = minBallDiameter...(minBallDiameter + (maxBallDiameter - minBallDiameter) * 0.4)
                }
            }
            
            let diameter = randomGen.randomCGFloat(in: diameterRange)
            
            // 根據優先級調整bumps數量，並使用種子產生確定性隨機值
            let bumpsRange: ClosedRange<Int>
            
            // 新增邏輯：如果是置頂項目(isPinned=true)，則使用優先級3的齒輪數量(14-16)
            if todoItem.isPinned {
                bumpsRange = 14...16  // 置頂項目使用優先級3的齒輪數量範圍
            } else {
                // 非置頂項目依照原本的優先級邏輯
                switch todoItem.priority {
                    case 1: // 優先級1：齒輪數6-9
                        bumpsRange = 6...9
                    case 2: // 優先級2：齒輪數10-13
                        bumpsRange = 10...13
                    case 3: // 優先級3：齒輪數14-16
                        bumpsRange = 14...16
                    default: // 預設或優先級0：齒輪數6-9
                        bumpsRange = 6...9
                }
            }
            // 使用種子生成確定性的齒輪數
            let bumpsCount = randomGen.randomInt(in: bumpsRange, salt: 1)
            
            // 根據種子決定bumpOffset
            let bumpOffset = randomGen.randomCGFloat(in: 6...9)
            
            // 創建BumpyCircle路徑
            let circlePath = BumpyCircle(bumps: bumpsCount, bumpOffset: bumpOffset)
                .path(in: CGRect(x: 0, y: 0, width: diameter, height: diameter))
            
            // 創建節點
            let node = SKShapeNode(path: circlePath.cgPath)
            
            // 根據任務狀態和置頂狀態設置不同的顏色
            if todoItem.status == .completed {
                // 已完成項目 - 使用綠色
                node.fillColor = SKColor(red: 0, green: 0.72, blue: 0.41, alpha: 1.0)
                node.strokeColor = .clear
            } else if todoItem.isPinned {
                // 置頂項目 - 使用深紅色
                node.fillColor = SKColor(red: 0.28, green: 0.17, blue: 0.17, alpha: 1.0)
                node.strokeColor = .clear
            } else {
                // 一般項目 - 使用白色，透明度根據優先級調整
                let alpha = 0.6 + min(0.3, CGFloat(todoItem.priority) * 0.1)
                node.fillColor = SKColor.white.withAlphaComponent(alpha)
                node.strokeColor = .clear
            }
            
            // 計算位置 - 確保均勻分佈在可見區域內
            let row = i / ballsPerRow
            let col = i % ballsPerRow
            
            // 基於列計算水平位置
            let segmentWidth = containerWidth / CGFloat(ballsPerRow)
            let baseX = boundaryRect.minX + (segmentWidth * CGFloat(col)) + (segmentWidth / 2)
            
            // 添加小的確定性隨機偏移（限制偏移範圍）
            let maxOffset = min(5.0, segmentWidth / 4) // 限制偏移範圍避免重疊
            let randomXOffset = randomGen.randomCGFloat(in: -maxOffset...maxOffset)
            
            // 使用預計算的行位置，確保每個球體都有固定的基準y位置
            let baseY = row < rowPositions.count ? rowPositions[row] : boundaryRect.minY + verticalSpacing
            let randomYOffset = randomGen.randomCGFloat(in: -2...2) // 極小的垂直偏移
            
            // 設置最終位置
            node.position = CGPoint(x: baseX + randomXOffset, y: baseY + randomYOffset)
            
            // 設置物理屬性 - 增強防止球體跳出的特性
            node.physicsBody = SKPhysicsBody(polygonFrom: circlePath.cgPath)
            
            // 根據球體大小調整物理屬性，較大的球體需要更高的阻尼和較低的彈性
            let sizeRatio = (diameter - minBallDiameter) / (maxBallDiameter - minBallDiameter)
            
            // 調整彈性 - 大球更低的彈性防止彈出
            let restitution = max(0.05, 0.2 - sizeRatio * 0.15)  // 彈性範圍: 0.05-0.2
            node.physicsBody?.restitution = restitution
            
            // 調整摩擦 - 大球更高的摩擦以穩定運動
            let friction = min(0.9, 0.7 + sizeRatio * 0.2)  // 摩擦範圍: 0.7-0.9
            node.physicsBody?.friction = friction
            
            // 調整阻尼 - 大球更高的阻尼以降低動能
            let damping = min(1.0, 0.8 + sizeRatio * 0.2)  // 阻尼範圍: 0.8-1.0
            node.physicsBody?.linearDamping = damping
            
            // 調整密度 - 較大的球體需要更高的密度以模擬真實物理效果
            let density = 1.0 + sizeRatio * 0.5  // 密度範圍: 1.0-1.5
            node.physicsBody?.density = density
            
            // 根據球體大小調整初始力量 - 較大的球體力量更小以避免跳出
            let maxForce = 0.1 * (1.0 - sizeRatio * 0.7)  // 較大的球體使用更小的力
            let impulseX = randomGen.randomCGFloat(in: -maxForce...maxForce)
            let impulseY = randomGen.randomCGFloat(in: -(maxForce * 2)...0.0)
            node.physicsBody?.applyImpulse(CGVector(dx: impulseX, dy: impulseY))
            
            // 將待辦事項信息存儲在節點的userData中
            node.userData = NSMutableDictionary()
            node.userData?.setValue(todoItem.id.uuidString, forKey: "todoID")
            
            addChild(node)
            
            // 打印調試信息
            print("創建球體 \(i): ID=\(todoItem.id), 直徑=\(diameter), 位置=(\(node.position.x), \(node.position.y))")
        }
    }
}

// 基於種子的隨機數生成器（保持不變）
struct SeededRandomGenerator {
    private let seed: String
    
    init(seed: String) {
        self.seed = seed
    }
    
    // 使用SHA-256生成一個確定性的數值
    private func generateDeterministicValue(using salt: Int) -> UInt64 {
        let saltedSeed = "\(seed)-\(salt)"
        if let data = saltedSeed.data(using: .utf8) {
            let hash = SHA256.hash(data: data)
            let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
            if let firstEightChars = hashString.prefix(16).data(using: .utf8) {
                return firstEightChars.withUnsafeBytes { $0.load(as: UInt64.self) }
            }
        }
        // 如果發生錯誤，返回一個基於種子的簡單數值
        return UInt64(abs(seed.hash))
    }
    
    // 生成一個區間內的CGFloat隨機數
    func randomCGFloat(in range: ClosedRange<CGFloat>, salt: Int = 0) -> CGFloat {
        let value = generateDeterministicValue(using: salt)
        let normalized = CGFloat(value) / CGFloat(UInt64.max)
        return range.lowerBound + normalized * (range.upperBound - range.lowerBound)
    }
    
    // 生成一個區間內的Int隨機數
    func randomInt(in range: ClosedRange<Int>, salt: Int = 0) -> Int {
        let value = generateDeterministicValue(using: salt)
        let normalized = Double(value) / Double(UInt64.max)
        return range.lowerBound + Int(normalized * Double(range.upperBound - range.lowerBound))
    }
}
