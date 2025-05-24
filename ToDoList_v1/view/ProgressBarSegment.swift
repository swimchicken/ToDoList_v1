
import SwiftUI

struct ProgressBarSegment: View {
    let isActive: Bool
    let width: CGFloat // 允許外部傳入寬度

    private let segmentHeight: CGFloat = 11
    private let segmentCornerRadius: CGFloat = 29

    var body: some View {
        // isActive = true 代表您在 SettlementView03 中定義的「第一個」進度條 (實心綠色)
        // isActive = false 代表您在 SettlementView03 中定義的「第二個」進度條 (深灰底綠框)
        if isActive {
            Rectangle()
                .fill(Color(red: 0, green: 0.72, blue: 0.41)) // 綠色背景
                .frame(width: width, height: segmentHeight)
                .cornerRadius(segmentCornerRadius)
        } else {
            Rectangle()
                .fill(Color(red: 0.13, green: 0.13, blue: 0.13)) // 深灰色背景
                .frame(width: width, height: segmentHeight)
                .cornerRadius(segmentCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: segmentCornerRadius)
                        .inset(by: 0.5)
                        .stroke(Color(red: 0, green: 0.72, blue: 0.41), lineWidth: 1) // 綠色邊框
                )
        }
    }
}
