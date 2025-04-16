//
//  BumpyCircle.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/4/15.
//

import SwiftUI

struct BumpyCircle: Shape {
    var bumps: Int
    var bumpOffset: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseRadius = min(rect.width, rect.height) / 2
        let angleStep = CGFloat.pi * 2 / CGFloat(bumps)
        
        var currentAngle = -CGFloat.pi / 2
        let startPoint = CGPoint(
            x: center.x + baseRadius * cos(currentAngle),
            y: center.y + baseRadius * sin(currentAngle)
        )
        path.move(to: startPoint)
        
        // 每個區段畫一條二次貝茲曲線 (QuadCurve)
        for _ in 0..<bumps {
            let midAngle = currentAngle + angleStep / 2
            let endAngle = currentAngle + angleStep
            
            // 向外凸起的控制點
            let controlPoint = CGPoint(
                x: center.x + (baseRadius + bumpOffset) * cos(midAngle),
                y: center.y + (baseRadius + bumpOffset) * sin(midAngle)
            )
            
            let endPoint = CGPoint(
                x: center.x + baseRadius * cos(endAngle),
                y: center.y + baseRadius * sin(endAngle)
            )
            
            path.addQuadCurve(to: endPoint, control: controlPoint)
            
            currentAngle = endAngle
        }
        
        path.closeSubpath()
        return path
    }
}

struct BumpyCircleView: View {
    var body: some View {
        BumpyCircle(bumps: 17, bumpOffset: 10)
            .fill(Color.gray)
            .frame(width: 35, height: 35)
            // 同樣不加任何背景修飾 → 背景維持透明
    }
}

struct BumpyCircleView_Previews: PreviewProvider {
    static var previews: some View {
        BumpyCircleView()
            .previewLayout(.sizeThatFits)
            .padding()
    }
}

