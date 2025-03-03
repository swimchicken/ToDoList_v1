import SwiftUI

struct coolmark2: View {
    // 狀態管理
    @State private var email: String = ""            // 預設空字串
    @State private var password: String = ""
    @State private var showPassword: Bool = false    // 是否顯示密碼欄
    @State private var isEditing: Bool = false       // 是否正在編輯輸入框
    
    // 分別控制 Email 與 Password 的焦點
    @FocusState private var isEmailFocused: Bool
    @FocusState private var isPasswordFocused: Bool
    
    var body: some View {
        ZStack {
            // 背景 (黑色)
            Color.black
                .ignoresSafeArea()
                // 點擊背景時關閉鍵盤
                .onTapGesture {
                    closeKeyboard()
                }
            
            VStack {
                // -- 1) 上方文字區域 --
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
                
                Spacer() // 撐開空間，讓下方輸入框貼底
                
                // -- 2) 輸入框區域 --
                ZStack {
                    // 輸入框背景
                    RoundedRectangle(cornerRadius: 36)
                        .fill(Color.white.opacity(0.1))
                        // 根據是否顯示密碼欄調整高度
                        .frame(height: showPassword ? 220 : 166)
                        .allowsHitTesting(false) // 讓背景不攔截點擊
                        
                    // 計算按鈕透明度
                    // - 如果 showPassword = true → 0.5 (半透明)
                    // - 如果 showPassword = false 且 isEditing = true → 1.0 (不透明)
                    // - 否則 → 0.5 (半透明)
                    let buttonOpacity: Double = showPassword
                        ? 0.5
                        : (isEditing ? 1.0 : 0.5)
                    
                    VStack(spacing: 16) {
                        // -- Email 輸入框 (預設文字 "Email address") --
                        TextField("", text: $email, prompt: Text("Email address").foregroundColor(.white.opacity(0.4)))
                            .keyboardType(.emailAddress)
                            .font(Font.custom("Inter", size: 20))
                            .foregroundColor(.white)
                            .padding(.top, -20)
                            .padding()
                            .frame(width: 320, height: 50)
                            .background(Color.black.opacity(0.02))
                            .cornerRadius(36)
                            // 綁定焦點
                            .focused($isEmailFocused)
                            // 監聽焦點變化
                            .onChange(of: isEmailFocused) { oldValue, newValue in
                                if newValue {
                                    // Email 輸入框被聚焦 → 進入編輯狀態
                                    isEditing = true
                                } else if !isPasswordFocused {
                                    // 如果連 Password 都沒焦點 → 結束編輯狀態
                                    isEditing = false
                                }
                            }

                        // -- Password 輸入框 (showPassword = true 時顯示) --
                        if showPassword {
                            SecureField("", text: $password, prompt: Text("Password").foregroundColor(.white.opacity(0.4)))
                                .font(Font.custom("Inter", size: 20))
                                .foregroundColor(.white)
                                .padding()
                                .frame(width: 320, height: 50)
                                .background(Color.black.opacity(0.02))
                                .cornerRadius(10)
                                // 綁定焦點
                                .focused($isPasswordFocused)
                                // 監聽焦點變化
                                .onChange(of: isPasswordFocused) { oldValue, newValue in
                                    if newValue {
                                        isEditing = true
                                    } else if !isEmailFocused {
                                        isEditing = false
                                    }
                                }
                        }
                        
                        // -- Next / Login 按鈕 --
                        HStack {
                            Spacer()
                            Button(action: {
                                if !showPassword {
                                    // 點擊 Next -> 顯示密碼欄
                                    showPassword = true
                                } else {
                                    // 已顯示密碼欄 -> 點擊 Login
                                    print("登入：Email = \(email), Password = \(password)")
                                }
                            }) {
                                Text(showPassword ? "Login" : "Next")
                                    .font(Font.custom("Inter", size: 16).weight(.semibold))
                                    .foregroundColor(.black)
                                    .frame(width: 310, height: 56)
                                    .background(Color.white.opacity(buttonOpacity))
                                    .cornerRadius(44)
                            }
                            Spacer()
                        }
                    }
                    .padding(.top, 20)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
                
                // -- 3) 忘記密碼 (只有顯示密碼欄時出現) --
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
        }
    }
    
    // 關閉鍵盤
    private func closeKeyboard() {
        isEmailFocused = false
        isPasswordFocused = false
        isEditing = false
    }
}

struct coolmark2Previews: PreviewProvider {
    static var previews: some View {
        coolmark2()
    }
}
