//
//  guide3.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/3/26.
//

import SwiftUI

struct guide3: View {
    //資料庫預設
    @State private var userName: String = "SHIRO"
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 15) {
                    
                    // 進度條
                    ZStack(alignment: .leading) {
                        HStack {
                            // 假設前 3 塊綠色，後面一塊是灰色帶邊框，最後是 checkmark
                            Rectangle()
                                .fill(Color.green)
                                .frame(height: 10)
                                .cornerRadius(10)
                            
                            Rectangle()
                                .fill(Color.green)
                                .frame(height: 10)
                                .cornerRadius(10)
                            
                          
                            
                            // 第四塊，白底半透明 + 綠色邊框
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
                            
                            // 第五塊，可能是打勾符號
                            Image("Gride01")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 10)
                    
                    // 標題
                    Text("What's your name?")
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
                        Rectangle()
                            .foregroundColor(.clear)
                            .background(.white.opacity(0.08))
                            .cornerRadius(36)
                            .frame(width: 354, height: 180)
                        
                        VStack(spacing: 20) {
                            // 輸入名字
                            TextField("", text: $userName)
                                .font(Font.custom("Inter", size: 20).weight(.medium))
                                .foregroundColor(.white)
                                // 將 center 改為 leading
                                .multilineTextAlignment(.leading)
                                .frame(height: 44)
//                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                                // 如果想讓文字更貼左邊，可以減少或移除 horizontal padding
                                .padding(.horizontal, 40)
                            
                            Button(action: {
                                // 驗證行為
                            }) {
                                Text("Next")
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
                    
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 60)
            }
        }
    }
}

#Preview {
    guide3()
}
