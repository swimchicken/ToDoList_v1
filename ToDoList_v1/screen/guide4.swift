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
                            
                            // 最後一塊可能是 checkmark
                            Image("Gride01")
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
                                ForEach(0...130, id: \.self) { age in
                                    Text("\(age)")
                                    .font(.system(size: 30).weight(.medium))
                                    .foregroundColor(.white)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 120)
                            .labelsHidden() // 隱藏標籤
                            // Start 按鈕
                            Button(action: {
                                // 驗證行為
                            }) {
                                Text("Start")
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
    guide4()
}
