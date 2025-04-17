import SwiftUI
import SpriteKit

struct BumpyCircle: Shape {
    var bumps: Int
    var bumpOffset: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseRadius = min(rect.width, rect.height) / 2
        let angleStep = .pi * 2 / CGFloat(bumps)

        var currentAngle = -CGFloat.pi / 2
        let start = CGPoint(
            x: center.x + baseRadius * cos(currentAngle),
            y: center.y + baseRadius * sin(currentAngle)
        )
        path.move(to: start)

        for _ in 0..<bumps {
            let mid   = currentAngle + angleStep/2
            let end   = currentAngle + angleStep
            let cp = CGPoint(
                x: center.x + (baseRadius + bumpOffset) * cos(mid),
                y: center.y + (baseRadius + bumpOffset) * sin(mid)
            )
            let ep = CGPoint(
                x: center.x + baseRadius * cos(end),
                y: center.y + baseRadius * sin(end)
            )
            path.addQuadCurve(to: ep, control: cp)
            currentAngle = end
        }

        path.closeSubpath()
        return path
    }
}
