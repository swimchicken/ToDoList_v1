//
//  WheelPicker.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/3/26.
//

import SwiftUI

/// 一個自製的「輪子選擇器」，用 ScrollView 實作
struct WheelPicker: View {
    /// 可選資料，這裡用 Int 做範例；也可以是 String、或自訂 struct
    let data: [Int]
    
    /// 外部傳進來的選擇值
    @Binding var selection: Int
    
    /// 每個項目的高度
    private let rowHeight: CGFloat = 40
    
    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { scrollProxy in
                ScrollView(.vertical, showsIndicators: false) {
                    // 用空白 Spacer 讓中間對齊
                    // 確保中間對齊區塊能對準視窗正中
                    Spacer().frame(height: geo.size.height / 2 - rowHeight / 2)
                    
                    ForEach(data, id: \.self) { item in
                        Text("\(item)")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(.white)
                            .frame(height: rowHeight)
                            .frame(maxWidth: .infinity)
                            // 簡單示範：若當前項目是 selection，就加個淡灰背景
                            .background(
                                Color.white.opacity(selection == item ? 0.15 : 0.0)
                            )
                            // 用 .id(item) 讓 ScrollViewReader 能滾動到此位置
                            .id(item)
                            // 點擊切換選擇，並自動滾動至該項目
                            .onTapGesture {
                                withAnimation {
                                    selection = item
                                    scrollProxy.scrollTo(item, anchor: .center)
                                }
                            }
                    }
                    
                    Spacer().frame(height: geo.size.height / 2 - rowHeight / 2)
                }
                .overlay(
                    // 中間的「選取區域」高亮方塊
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: rowHeight)
                        .allowsHitTesting(false),
                    alignment: .center
                )
                .onAppear {
                    // 螢幕出現時，自動滾動到預設的 selection
                    scrollProxy.scrollTo(selection, anchor: .center)
                }
            }
        }
    }
}

