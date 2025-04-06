import SwiftUI

struct CodeField: View {
    @Binding var text: String
    // 透過 @FocusState 追蹤 TextField 是否為焦點
    @FocusState private var isFocused: Bool
    
    var body: some View {
        TextField("", text: $text)
            .font(.system(size: 24))
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .foregroundColor(.white)
            .frame(width: 71.07317, height: 72.21951)
            .cornerRadius(24)
            .focused($isFocused)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .inset(by: 0.57)
                    .stroke(isFocused ? .white : Color(red: 0.37, green: 0.37, blue: 0.37),
                            lineWidth: 1.14634)
            )
            .onChange(of: text) { newValue in
                // 過濾掉非數字
                let filtered = newValue.filter { $0.isNumber }
                // 限制最多只留一個數字
                if filtered.count > 1 {
                    text = String(filtered.prefix(1))
                } else {
                    text = filtered
                }
            }
    }
}
