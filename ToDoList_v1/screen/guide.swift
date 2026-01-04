import SwiftUI

struct guide: View {
    let email: String                 // 從 EmailLogin 傳入
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var navigateToGuide2 = false  // 導向 guide2
    @Environment(\.presentationMode) var presentationMode // 用於返回上一頁
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 15) {
                    // 進度條
                    ZStack(alignment: .leading) {
                        HStack {
                            ForEach(0..<5) { _ in
                                Rectangle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 10)
                                    .cornerRadius(10)
                            }
                            Image("Gride01")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 10)
                    
                    // 標題
                    Text("Signup")
                        .font(Font.custom("Inria Sans", size: 25.45489)
                                .weight(.bold)
                                .italic())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .opacity(0.9)
                    
                    Spacer()
                    
                    // 卡片
                    ZStack {
                        Rectangle()
                            .foregroundColor(.clear)
                            .background(.white.opacity(0.06))
                            .frame(width: 354, height: 325)
                            .cornerRadius(36)
                        
                        VStack(alignment: .leading, spacing: 31) {
                            // 顯示從上頁傳入的 Email
                            Text(email)
                                .font(Font.custom("Inter", size: 20).weight(.medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, minHeight: 25, alignment: .bottomLeading)
                            
                            // 密碼輸入
                            SecureField("", text: $password)
                                .font(Font.custom("Inter", size: 22).weight(.semibold))
                                .foregroundColor(.white)
                                .placeholder(when: password.isEmpty) {
                                    Text("Password")
                                        .font(Font.custom("Inter", size: 22).weight(.medium))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .frame(maxWidth: .infinity, minHeight: 25, alignment: .bottomLeading)
                            
                            // 確認密碼
                            SecureField("", text: $confirmPassword)
                                .font(Font.custom("Inter", size: 22).weight(.semibold))
                                .foregroundColor(.white)
                                .placeholder(when: confirmPassword.isEmpty) {
                                    Text("Confirm password")
                                        .font(Font.custom("Inter", size: 22).weight(.medium))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .frame(maxWidth: .infinity, alignment: .bottomLeading)
                            
                            // 建立帳號按鈕
                            Button(action: {
                                guard password == confirmPassword else {
                                    return
                                }
                                EmailAccountManager.shared.createEmailAccount(email: email, password: password) { success, error in
                                    DispatchQueue.main.async {
                                        if success {
                                            navigateToGuide2 = true
                                        } else {
                                            // Error creating account
                                        }
                                    }
                                }
                            }) {
                                Text("Create account")
                                    .font(Font.custom("Inter", size: 16).weight(.semibold))
                                    .foregroundColor(.black)
                                    .frame(width: 300, height: 56)
                                    .background(Color.white.opacity(0.2))
                                    .cornerRadius(44)
                            }
                            
                            // 新增的 Back 按鈕
                            Button(action: {
                                // 返回 EmailLogin 頁面
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                Text("Back")
                                    .font(Font.custom("Inter", size: 16).weight(.medium))
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 300, height: 30)
                            }
                            .padding(.top, -10)
                        }
                        .frame(width: 297, alignment: .topLeading)
                    }
                    .frame(maxWidth: .infinity, maxHeight: 300)
                    
                    // 條款
                    (
                        Text("By creating an account or signing you agree to our ")
                            .foregroundColor(.white.opacity(0.7))
                        +
                        Text("Terms and Conditions")
                            .foregroundColor(.white)
                            .underline()
                    )
                    .font(Font.custom("Inter", size: 14))
                    .multilineTextAlignment(.center)
                    .frame(width: 259)
                    .opacity(0.69)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 60)
                
                // 導航到 guide2，傳入相同 email
                NavigationLink(destination: guide2(email: email).navigationBarBackButtonHidden(true), isActive: $navigateToGuide2) {
                    EmptyView()
                }
            }
            .navigationBarBackButtonHidden(true) // 隱藏默認的返回按鈕
        }
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 0.35 : 0)
            self
        }
    }
}

#Preview {
    guide(email: "example@mail.com")
}
