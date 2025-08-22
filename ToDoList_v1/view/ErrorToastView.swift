import SwiftUI

struct ErrorToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .foregroundColor(.white)

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        // ------------------------------------------
        // 手動建立玻璃效果的背景
        // ------------------------------------------
        .background(
            ZStack {
                // 底層：半透明顏色
                Color.white.opacity(0.4)

                // 上層：模糊效果
                // (注意：這裡的 Blur 僅作為視覺效果層，
                // 真正的透明感來自下方的 Color.opacity)
                BlurView(style: .systemMaterialDark)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white, lineWidth: 1) // 畫一個白色的圓角框線
        )
        .shadow(radius: 5)
    }
}

// 創建一個遵循 UIViewRepresentable 的結構來橋接 UIVisualEffectView
struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}


#Preview {
    ErrorToastView(message: "轉譯錯誤，請再試一次")
        .padding()
        .background(Color.gray)
}
