import SwiftUI
import CloudKit

struct guide2: View {
    let email: String   // 從 guide 傳入的 email
    @State private var code1 = ""
    @State private var code2 = ""
    @State private var code3 = ""
    @State private var code4 = ""
    @State private var navigateToHome = false  // 驗證成功後跳轉到 Home
    @Environment(\.presentationMode) var presentationMode // 用於返回上一頁
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 15) {
                    
                    // 進度條
                    ZStack(alignment: .leading) {
                        HStack {
                            Rectangle()
                                .fill(Color.green)
                                .frame(height: 10)
                                .cornerRadius(10)
                            
                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 10)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.green, lineWidth: 2)
                                )
                            
                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 10)
                                .cornerRadius(10)
                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 10)
                                .cornerRadius(10)
                            
                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 10)
                                .cornerRadius(10)
                            
                            Image("Gride01")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 10)
                    
                    // 主標題
                    Text("guide2.check_email")
                        .font(
                            Font.custom("Inria Sans", size: 25.45489)
                                .weight(.bold)
                                .italic()
                        )
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .opacity(0.9)
                    
                    // 副標題：動態顯示遮罩後的 email
                    Text("We've sent a code to \(maskEmail(email))")
                        .font(Font.custom("Inter", size: 16))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer()
                    
                    // 輸入驗證碼的卡片區塊
                    ZStack {
                        Rectangle()
                            .foregroundColor(.clear)
                            .frame(width: 354, height: 230)
                            .background(.white.opacity(0.08))
                            .cornerRadius(36)
                        
                        VStack(spacing: 25) {
                            // 4 個驗證碼輸入框
                            HStack(spacing: 16) {
                                CodeField(text: $code1)
                                CodeField(text: $code2)
                                CodeField(text: $code3)
                                CodeField(text: $code4)
                            }
                            
                            // 驗證按鈕
                            Button(action: {
                                let code = code1 + code2 + code3 + code4
                                EmailAccountManager.shared.verifyEmailAccount(email: email, code: code) { success, error in
                                    DispatchQueue.main.async {
                                        if success {
                                            navigateToHome = true
                                        } else {
                                            // Verification failed
                                        }
                                    }
                                }
                            }) {
                                Text("common.verify")
                                    .font(Font.custom("Inter", size: 16).weight(.semibold))
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity, minHeight: 56)
                            }
                            .padding(.vertical, 17)
                            .frame(width: 329, height: 56, alignment: .center)
                            .background(Color(red: 0.94, green: 0.94, blue: 0.94))
                            .cornerRadius(44)
                            
                            // 添加 Back 按鈕 (放在卡片內)
                            Button(action: {
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                Text("common.back")
                                    .font(Font.custom("Inter", size: 16).weight(.medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.top, -10)
                        }
                        .padding(.horizontal, 20)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // 重寄驗證碼區塊
                    HStack(spacing: 5) {
                        Button(action: {
                            // 重新發送驗證碼的邏輯
                        }) {
                            Text("guide2.send_code_again")
                                .foregroundColor(.white)
                                .underline(true, color: .white)
                        }
                        Text("common.timer_placeholder")
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .font(Font.custom("Inter", size: 14))
                    .padding(.top, 5)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 60)
            }
            .navigationBarBackButtonHidden(true) // 隱藏默認的返回按鈕
            
            // 當驗證成功時，跳轉到 Home 頁面
            NavigationLink(destination: Home(), isActive: $navigateToHome) {
                EmptyView()
            }
        }
    }
    
    /// 將 email 中間部分遮罩，只顯示首尾各一個字元
    private func maskEmail(_ email: String) -> String {
        let parts = email.split(separator: "@")
        guard parts.count == 2 else { return email }
        let name = String(parts[0])
        let domain = String(parts[1])
        let maskedName: String
        if name.count <= 2 {
            maskedName = String(repeating: "*", count: name.count)
        } else {
            let first = name.prefix(1)
            let last = name.suffix(1)
            let stars = String(repeating: "*", count: name.count - 2)
            maskedName = "\(first)\(stars)\(last)"
        }
        return "\(maskedName)@\(domain)"
    }
}


#Preview {
    guide2(email: "swimchickenouo@gmail.com")
}
