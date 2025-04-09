//
//  ItemRow.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/4/9.
//

import SwiftUI

struct ItemRow: View {
    let item: ToDoItem        // 接收單筆資料
    
    // 時間格式，例如顯示為 "10:00"
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            HStack(spacing: 12) {
                //圓圈：顯示完成狀態
//                Circle()
//                //                .fill(item.isCompleted ? Color.gray : Color.secondary.opacity(0.8))
//                    .fill(item.isCompleted ? Color.white : Color.gray)
//                    .frame(width: 24, height: 24)
                
                ZStack {
                    Circle()
                        .fill(item.isCompleted ? Color.white : Color.gray)
                        .frame(width: 24, height: 24)
                    
                    // 如果 isCompleted 為 true，則顯示打勾圖示
                    if item.isCompleted {
                        Image(systemName: "checkmark")
                            .foregroundColor(.black)  // 可以根據需求調整顏色
                            .font(.system(size: 12, weight: .bold))
                    }
                }

                
                //事項標題
                Text(item.title)
                    .font(.body)
                    .lineLimit(1)   // 顯示一行，多餘部分省略
                    .frame(minWidth: 209, alignment: .leading)
//                    .frame(width: 209, height: 26)
                
//                Spacer(minLength: 11.76)
                Spacer()
                
                //重要程度 (星星數量) // priority 代表顯示幾顆星星
                HStack(spacing: 2) {
                    ForEach(0..<item.priority, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .resizable()
                            .frame(width: 16, height: 16)
                            .foregroundColor(.white)
                    }
                }
                
//                Spacer()
                
                //排定時間 (24小時制)
                Text("\(item.time, formatter: ItemRow.timeFormatter)")
                    .font(.subheadline)
            }
            .padding(.vertical, 13)    // 上下留白
            .padding(.horizontal, 2)
            .background(Color.black)  // 整體背景色，可依需求調整
            .foregroundColor(.white)  // 文字顏色
            
//            Divider()
//                .frame(height: 1)
//                .background(Color.white)
        }
        .frame(height: 52)
    }
}

struct ToDoRow_Previews: PreviewProvider {
    static var previews: some View {
        ItemRow(
            item: ToDoItem(
                title: "Prepare tomorrow's meeting",
                priority: 3,
                time: Date(),
                isCompleted: true
            )
        )
        .previewLayout(.sizeThatFits)
    }
}
