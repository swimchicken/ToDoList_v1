//
//  guide2.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/3/13.
//

import SwiftUI

struct guide2: View {
    // 假設要讓使用者輸入 4 位數驗證碼
    @State private var code1 = ""
    @State private var code2 = ""
    @State private var code3 = ""
    @State private var code4 = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 15) {
                    
                    // 進度條 (可依需求調整，示範 4~5 個方塊或圓點)
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
                    Text("Please check your email")
                        .font(
                            Font.custom("Inria Sans", size: 25.45489)
                                .weight(.bold)
                                .italic()
                        )
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .opacity(0.9)
                    
                    // 副標題 (提示已寄出驗證碼)
                    Text("We've sent a code to s*****o@yuniverses.com")
                        .font(Font.custom("Inter", size: 16))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer()
                    
                    // 輸入驗證碼的卡片區塊
                    ZStack {
                        Rectangle()
                            .foregroundColor(.clear)
                            .frame(width: 354, height: 179)
                            .background(.white.opacity(0.08))
                            .cornerRadius(36)
//                            .blur(radius: 31.8)
                        VStack(spacing: 25){
                            // 4 個驗證碼輸入框
                            HStack(spacing: 16) {
                                CodeField(text: $code1)
                                CodeField(text: $code2)
                                CodeField(text: $code3)
                                CodeField(text: $code4)
                            }
                            
                            // 驗證按鈕
                            Button(action: {
                                // 驗證行為
                            }) {
                                Text("Verify")
                                    .font(Font.custom("Inter", size: 16).weight(.semibold))
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity, minHeight: 56)
                            }
//                            .padding(.horizontal, 152)
                            .padding(.vertical, 17)
                            .frame(width: 329, height: 56, alignment: .center)
                            .background(Color(red: 0.94, green: 0.94, blue: 0.94))
                            .cornerRadius(44)
                        }
                        
                        
                        
                    }
                    .frame(maxWidth: .infinity)
                    
                    
                    
                    // 重寄驗證碼區塊
                    HStack(spacing: 5) {
                        Text("Send code again")
                            .foregroundColor(.white)
                            .underline(true, color: .white)
                        Text("00:20")
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .font(Font.custom("Inter", size: 14))
                    
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 60)
            }
        }
    }
    
    
}

#Preview {
    guide2()
}
