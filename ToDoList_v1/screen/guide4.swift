//
//  guide04.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/3/26.
//

import SwiftUI

struct guide4: View {
    // 假設使用者只能選 7, 8, 9 歲
    @State private var selectedAge = 7
    
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
                            // 前面 4 塊綠色
                            Rectangle()
                                .fill(Color.green)
                                .frame(height: 10)
                                .cornerRadius(10)
                            Rectangle()
                                .fill(Color.green)
                                .frame(height: 10)
                                .cornerRadius(10)
                            Rectangle()
                                .fill(Color.green)
                                .frame(height: 10)
                                .cornerRadius(10)
                            RRectangle()
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
                            
                            // 最後一塊可能是 checkmark
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 10)
                    
                    // 標題
                    Text("Whats your age?")
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
                            .frame(width: 354, height: 240)
                        
                        VStack(spacing: 20) {
                            // Picker for Age
                            Picker("Select Age", selection: $selectedAge) {
                                Text("7").tag(7)
                                Text("8").tag(8)
                                Text("9").tag(9)
                            }
                            .pickerStyle(.wheel)           // 轉盤風格
                            .frame(height: 100)            // 可視需要調整高度
                            .labelsHidden()                // 隱藏預設標籤
                            .foregroundColor(.white)       // 讓選項文字呈現白色
                            
                            // Start 按鈕
                            Button(action: {
                                // 按下 Start 後的行為
                            }) {
                                Text("Start")
                                    .font(Font.custom("Inter", size: 16).weight(.semibold))
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity, minHeight: 56)
                            }
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(44)
                            .frame(width: 300)
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
    guide04()
}
