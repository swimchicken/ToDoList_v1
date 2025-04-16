//
//  GearShape.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/4/15.
//

import SwiftUI

struct GearShape: Shape {
    let teeth: Int          // 齒數，決定外圍突起的個數
    let innerRatio: CGFloat // 內圈半徑與外圈半徑的比例（0~1之間）
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * innerRatio
        let totalPoints = teeth * 2       // 每一齒包含兩個頂點：外圈與內圈
        let angleStep = CGFloat.pi * 2 / CGFloat(totalPoints)
        
        // 從正上方（-90°）作為起始點
        var angle = -CGFloat.pi / 2
        path.move(to: CGPoint(
            x: center.x + outerRadius * cos(angle),
            y: center.y + outerRadius * sin(angle))
        )
        
        for i in 1...totalPoints {
            // 偶數索引取外圓，奇數索引取內圓
            let radius = (i % 2 == 0) ? outerRadius : innerRadius
            angle += angleStep
            let nextPoint = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            path.addLine(to: nextPoint)
        }
        
        path.closeSubpath()
        return path
    }
}

struct AdjustableGearView: View {
    // 可以由外部傳入參數：
    var color: Color
    var size: CGFloat
    var teeth: Int
    var innerRatio: CGFloat
    
    var body: some View {
        GearShape(teeth: teeth, innerRatio: innerRatio)
            .fill(color)
            .frame(width: size, height: size)
    }
}

struct AdjustableGearView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // 範例 1：藍色齒輪，200x200，12 齒，內圈比例 0.8
            AdjustableGearView(color: .gray, size: 23, teeth: 12, innerRatio: 0.8)
            
            // 範例 2：紅色齒輪，150x150，8 齒，內圈比例 0.7
            AdjustableGearView(color: .gray, size: 20, teeth: 20, innerRatio: 0.8)
        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
