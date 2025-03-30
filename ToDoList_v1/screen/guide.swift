//
//  guide.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/2/23.
//

import SwiftUI

struct guide: View {
    @State private var email: String = "swimchickenouo@gmail.com"
    @State private var password: String = ""
    @State private var confirmPassword: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 15) {
                    
                    // 進度條 (可依需求改成 4 顆圓點或其他樣式)
                    ZStack(alignment: .leading) {
                        HStack{
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
                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 10)
                                .cornerRadius(10)
                            Image("Gride01")
                        }
                        
//                        Rectangle()
//                            .fill(Color.white.opacity(0.2))
//                            .frame(height: 4)
//                        Rectangle()
//                            .fill(Color.green)
//                            .frame(width: 80, height: 4) // 這裡假設 4 步驟中的第 1 步，約 1/4 寬度
                    }
                    .frame(maxWidth: .infinity) // 讓底條佔滿整行
                    .padding(.bottom, 10)
                    
                    // 標題
                    Text("Signup")
                        .font(
                        Font.custom("Inria Sans", size: 25.45489)
                        .weight(.bold)
                        .italic()
                        )
                        .foregroundColor(.white)

                        .frame(maxWidth: .infinity, alignment: .leading)
                        .opacity(0.9)
                    
                    Spacer()
                    
                    // 底部卡片區塊
                    ZStack {
                        // 半透明背景
                        Rectangle()
                            .foregroundColor(.clear)
                            .background(.white.opacity(0.06))
                            .frame(width: 354, height: 280)
                            .cornerRadius(36)
//                            .blur(radius: 2)
                        
                        VStack(alignment: .leading, spacing: 31) {
                            // Email 輸入
                            Text(email)
                                .font(Font.custom("Inter", size: 20).weight(.medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, minHeight: 25, alignment: .bottomLeading)
                            .foregroundColor(.white) // 輸入後文字的顏色
                                .font(
                                Font.custom("Inter", size: 20)
                                .weight(.medium)
                                )
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, minHeight: 25, maxHeight: 25, alignment: .bottomLeading)
                            
                            // Password 輸入
                            SecureField("Password", text: $password)
                                .font(Font.custom("Inter", size: 22).weight(.semibold)) // 增加字體大小和粗細
                                .foregroundColor(.white) // 確保文字是白色
                                .frame(maxWidth: .infinity, minHeight: 25, alignment: .bottomLeading)
                                .placeholder(when: password.isEmpty) {
                                    Text("Password")
                                        .font(Font.custom("Inter", size: 22).weight(.medium))
                                        .foregroundColor(.white.opacity(0.6)) // 占位符更明顯
                                }
                            // Confirm Password 輸入
                            SecureField("Confirm password", text: $confirmPassword)
                                .font(Font.custom("Inter", size: 22).weight(.semibold)) // 增加字體大小和粗細
                                .foregroundColor(.white) // 確保文字是白色
                                .frame(maxWidth: .infinity, alignment: .bottomLeading)
                                .placeholder(when: confirmPassword.isEmpty) {
                                    Text("Confirm password")
                                        .font(Font.custom("Inter", size: 22).weight(.medium))
                                        .foregroundColor(.white.opacity(0.6)) // 占位符更明顯
                                }
                                
                            
                            // 建立帳號按鈕
                            
                            Button(action: {
                                // Create account 行為
                            }) {
                                Text("Create account")
                                    .font(
                                    Font.custom("Inter", size: 16)
                                        .weight(.semibold)
                                    )
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.black)
                            }
                            .frame(width: 300, height: 56)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(44)
                            
                            
                        }
                        .padding(0)
                        .frame(width: 297, alignment: .topLeading)
                            

                        
                        
                        
                    }
                    .frame(maxWidth: .infinity, maxHeight: 300)
                    
                    // 條款文字
                    (
                        Text("By creating an account or signing you agree to our ")
                            .foregroundColor(.white.opacity(0.7))
                            +
                        Text("Terms and Conditions")
                            .foregroundColor(.white)
                            .underline(true, color: .white)
                    )
                        .font(Font.custom("Inter", size: 14))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 259)
                        .opacity(0.69)
                    
                }
                // 與上一頁相同的邊距設定
                .padding(.horizontal, 12)
                .padding(.vertical, 60)
                
                
            }
            
        }
    }
}

// 文字修飾器

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
    guide()
}
