//
//  TodoSheetItemRow.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/4/18.
//

import SwiftUI

struct TodoSheetItemRow: View {
    @Binding var item: TodoItem
    private let doneColor = Color(red: 0, green: 0.72, blue: 0.41)
    private let iconSize: CGFloat = 16
    
    var body: some View {
        HStack(spacing: 12) {
            // 矩形按鈕 (點擊前灰色，點擊後綠色)
            Button {
                withAnimation {
                    item.status = (item.status == .completed ? .toBeStarted : .completed)
                }
            } label: {
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: 28, height: 28)
                    .background(item.status == .completed ? doneColor : .white.opacity(0.15))
                    .cornerRadius(40.5)
            }
            .buttonStyle(PlainButtonStyle())
            
            // 任務標題 (帶刪除線)
            Text(item.title)
                .font(.system(size: 16))
                .foregroundColor(item.status == .completed ? doneColor : .white)
                .lineLimit(1)
                .truncationMode(.tail)
                .overlay(
                    Group {
                        if item.status == .completed {
                            Rectangle()
                                .fill(doneColor)
                                .frame(height: 1.5)
                        }
                    },
                    alignment: .center
                )
            
            Spacer()
            
            // 星標（如果優先度>=1）
            if item.priority >= 1 {
                HStack(spacing: 2) {
                    ForEach(0..<item.priority, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(item.status == .completed ? doneColor : .white.opacity(0.7))
                    }
                }
                .padding(.trailing, 8)
            }
            
            // 右側箭頭按鈕
            Button {
                // 這裡可以添加點擊箭頭的操作，例如查看詳情
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(item.status == .completed ? doneColor : .white.opacity(0.5))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .background(Color.clear)
    }
}

struct TodoSheetItemRow_Previews: PreviewProvider {
    @State static var todoItem1 = TodoItem(
        id: UUID(), userID: "user123",
        title: "回覆所有未讀郵件",
        priority: 2,
        isPinned: false,
        taskDate: Date(),
        note: "備註",
        status: .toBeStarted,
        createdAt: Date(),
        updatedAt: Date(),
        correspondingImageID: ""
    )
    
    @State static var todoItem2 = TodoItem(
        id: UUID(), userID: "user123",
        title: "完成任務",
        priority: 3,
        isPinned: false,
        taskDate: Date(),
        note: "備註",
        status: .completed,
        createdAt: Date(),
        updatedAt: Date(),
        correspondingImageID: ""
    )
    
    static var previews: some View {
        VStack(spacing: 0) {
            TodoSheetItemRow(item: $todoItem1)
            Divider().background(Color.white.opacity(0.1))
            TodoSheetItemRow(item: $todoItem2)
        }
        .background(Color(red: 0.15, green: 0.15, blue: 0.15))
        .previewLayout(.sizeThatFits)
    }
}
