import SwiftUI

struct coolmark: View {
    @State private var email: String = ""
    @State private var passward: String = ""
    @State private var isEditing: Bool = false
    @State private var showPassword: Bool = false
    @FocusState private var isFieldFocused: Bool
    
    var body: some View {
        ZStack {
            // 背景
            Color.black.ignoresSafeArea()
                // 點擊背景收起鍵盤
                .onTapGesture {
                    if isEditing {
                        isFieldFocused = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isEditing = false
                        }
                    }
                }
            
            // 主畫面內容
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
                
                Spacer() // 撐開空間，讓輸入框能貼到底部
                
                // -- 2) 底部輸入框區域 --
                ZStack {
                    // 背景框：若想在編輯時更明顯，可以在 isEditing=true 時改變透明度
                    RoundedRectangle(cornerRadius: 36)
                        .fill(isEditing ? Color.white.opacity(0.08) : Color.white.opacity(0.08))
                        .frame(height: 166)
                        .onTapGesture {
                            // 點擊後進入編輯狀態 & 聚焦 TextField
                            isEditing = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isFieldFocused = true
                            }
                        }
                    
                    // -- 根據 isEditing 決定顯示 TextField 或「Email address」 --
                    VStack {
                        if isEditing {
                            // 可輸入的 TextField
                            TextField("", text: $email)
                                .keyboardType(.default)
                                .font(Font.custom("Inter", size: 20))
                                .foregroundColor(.white)
                                .padding()
                                .frame(width: 320, height: 50)
                                .background(Color.black.opacity(0.2))
                                .cornerRadius(10)
                                .focused($isFieldFocused)
                        } else {
                            // 預設文字
                            Text("Email address")
                                .font(Font.custom("Inter", size: 20).weight(.medium))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        
                        // 與 Next 按鈕之間的空隙
                        Spacer().frame(height: 16)
                        
                        // Next 按鈕
                        HStack {
                            Spacer()
                            Text("Next")
                                .font(Font.custom("Inter", size: 16).weight(.semibold))
                                .foregroundColor(.black)
                                .frame(width: 329, height: 56)
                                .background(Color.white.opacity(isEditing ? 1.0 : 0.2))
                                .cornerRadius(20)
                            Spacer()
                        }
                    }
                    .padding(.top, 20) // 讓文字稍微往上
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30) // 與畫面底部保持距離
            }
            
            // -- 3) 你原本的四條灰色邊線 (若需要) --
            // 建議改用 offset 或其他方式定位，這裡略示
        }
        // **千萬不要** 使用 .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

struct coolmark_Previews: PreviewProvider {
    static var previews: some View {
        coolmark()
    }
}
