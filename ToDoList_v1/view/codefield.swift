import SwiftUI

struct CodeField: View {
    @Binding var text: String
    // 透過 @FocusState 追蹤 TextField 是否為焦點
    @FocusState private var isFocused: Bool
    
    var body: some View {
        TextField("", text: $text)
            .font(.system(size: 24)) // 增加文字大小，可以根據需求調整數值
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .foregroundColor(.white) // 輸入的文字顯示顏色（可依需求調整）
            .frame(width: 71.07317, height: 72.21951)
            .cornerRadius(24)
            // 讓這個 TextField 可以被 focus
            .focused($isFocused)
            // 動態決定邊框顏色
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .inset(by: 0.57)
                    .stroke(isFocused ? .white : Color(red: 0.37, green: 0.37, blue: 0.37),
                            lineWidth: 1.14634)
            )
    }
}
