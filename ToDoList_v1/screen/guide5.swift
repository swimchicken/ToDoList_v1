//
//  guide5.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/3/26.
//

import SwiftUI

struct guide5: View {
    // 三個 Picker 的狀態
    @State private var hour = 8       // 預設 8
    @State private var minute = 20    // 預設 20
    @State private var ampm = 1       // 0=>AM, 1=>PM(預設PM)
    
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 15) {
                    
                    // 進度條 (與前幾頁類似)
                    ZStack(alignment: .leading) {
                        HStack {
                            // 4 塊綠色
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
                            
                            // 最後可能是 checkmark 或留白
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 10)
                    
                    // 標題
                    Text("你通常幾點入睡？")
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
                            // 三個 Picker 放在 HStack
                            MultiComponentPicker(hour: $hour,minute: $minute,ampm: $ampm)
                                .frame(height: 120)
                            
                            // 按鈕
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
    guide5()
}
