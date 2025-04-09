import SwiftUI
import CloudKit

struct EmailLogin: View {
    // 狀態管理
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false    // 控制是否顯示密碼輸入框
    @State private var isEditing: Bool = false
    @State private var navigateToRegister = false   // 若 email 不存在則跳轉到註冊頁面
    @State private var navigateToHome = false       // 密碼驗證成功後跳轉到 Home
    
    // 焦點管理
    @FocusState private var isEmailFocused: Bool
    @FocusState private var isPasswordFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                Color.black
                    .ignoresSafeArea()
                    .onTapGesture {
                        closeKeyboard()
                    }
                
                VStack {
                    // -- 上方文字區域 --
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tomorrow")
                            .font(Font.custom("Inria Sans", size: 25.45489)
                                    .weight(.bold)
                                    .italic())
                            .foregroundColor(.white)
                            .opacity(0.9)
                        
                        Text("Todo")
                            .font(Font.custom("Inria Sans", size: 25.45489)
                                    .weight(.bold)
                                    .italic())
                            .foregroundColor(.white)
                            .opacity(0.9)
                        
                        Text("計畫-執行-回顧")
                            .font(Font.custom("Inter", size: 16.33333))
                            .foregroundColor(Color.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 30)
                    .padding(.top, 40)
                    
                    Spacer()
                    
                    // -- 輸入框區域 --
                    ZStack {
                        // 輸入框背景（高度依據是否顯示密碼欄做調整）
                        RoundedRectangle(cornerRadius: 36)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: showPassword ? 220 : 166)
                            .allowsHitTesting(false)
                        
                        VStack(spacing: 16) {
                            // Email 輸入框
                            TextField("", text: $email, prompt: Text("Email address").foregroundColor(.white.opacity(0.4)))
                                .keyboardType(.emailAddress)
                                .font(Font.custom("Inter", size: 20))
                                .foregroundColor(.white)
                                .padding()
                                .frame(width: 320, height: 50)
                                .background(Color.black.opacity(0.02))
                                .cornerRadius(36)
                                .focused($isEmailFocused)
                                .onChange(of: isEmailFocused) { newValue in
                                    isEditing = newValue
                                }
                            
                            // 當 showPassword 為 true 時顯示密碼輸入框
                            if showPassword {
                                SecureField("", text: $password, prompt: Text("Password").foregroundColor(.white.opacity(0.4)))
                                    .font(Font.custom("Inter", size: 20))
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(width: 320, height: 50)
                                    .background(Color.black.opacity(0.02))
                                    .cornerRadius(36)
                                    .focused($isPasswordFocused)
                                    .onChange(of: isPasswordFocused) { newValue in
                                        isEditing = newValue
                                    }
                            }
                            
                            // 按鈕：依據狀態顯示 "Next" 或 "Login"
                            HStack {
                                Spacer()
                                Button(action: {
                                    if showPassword {
                                        // 已顯示密碼欄，進行密碼驗證，成功後跳轉到 Home
                                        loginWithEmail()
                                    } else {
                                        // 尚未顯示密碼欄，先檢查 email 是否存在
                                        checkEmailExistence()
                                    }
                                }) {
                                    Text(showPassword ? "Login" : "Next")
                                        .font(Font.custom("Inter", size: 16).weight(.semibold))
                                        .foregroundColor(.black)
                                        .frame(width: 310, height: 56)
                                        .background(Color.white.opacity(isEditing ? 1.0 : 0.5))
                                        .cornerRadius(44)
                                }
                                Spacer()
                            }
                        }
                        .padding(.top, 20)
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 30)
                    
                    // -- 忘記密碼 (僅在密碼輸入時顯示) --
                    if showPassword {
                        Button(action: {
                            print("忘記密碼")
                        }) {
                            Text("忘記密碼？")
                                .font(Font.custom("Inter", size: 14))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.bottom, 20)
                    }
                }
                
                // NavigationLink 跳轉到註冊頁面 (guide)
                NavigationLink("", destination: guide(email: email), isActive: $navigateToRegister)
                // NavigationLink 跳轉到 Home 頁面
                NavigationLink("", destination: Home(), isActive: $navigateToHome)
                //aasss
            }
        }
    }
    
    // 檢查 email 是否存在於 normalUser 資料表中
    private func checkEmailExistence() {
        EmailChecker.shared.checkEmailExists(email: email) { exists in
            DispatchQueue.main.async {
                if exists {
                    // 若 email 存在，顯示密碼輸入框，等待使用者輸入
                    showPassword = true
                } else {
                    // 若 email 不存在，跳轉至註冊流程
                    navigateToRegister = true
                }
            }
        }
    }
    
    // 執行 email 登入（假設 EmailChecker.shared.loginWithEmail 處理密碼驗證）
    private func loginWithEmail() {
        EmailChecker.shared.loginWithEmail(email: email, password: password) { success in
            DispatchQueue.main.async {
                if success {
                    navigateToHome = true
                } else {
                    // 密碼錯誤或驗證失敗，顯示錯誤訊息
                    print("Login failed. Please check your password.")
                }
            }
        }
    }
    
    // 關閉鍵盤
    private func closeKeyboard() {
        isEmailFocused = false
        isPasswordFocused = false
        isEditing = false
    }
}

struct EmailLogin_Previews: PreviewProvider {
    static var previews: some View {
        EmailLogin()
    }
}
