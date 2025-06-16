//
//  DeleteItemView.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/6/16.
//

import SwiftUI

/// 一個彈出式視圖，提供編輯、刪除和取消選項。
struct DeleteItemView: View {
    
    // MARK: - Properties
    
    /// 要顯示的項目名稱
    let itemName: String
    
    /// 當用戶點擊「取消」時執行的閉包
    let onCancel: () -> Void
    
    /// 當用戶點擊「編輯」時執行的閉包
    let onEdit: () -> Void
    
    /// 當用戶點擊「刪除」時執行的閉包
    let onDelete: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // 完全透明的背景，但仍然能捕捉點擊
            Color.clear
                .contentShape(Rectangle()) // 讓整個區域可以被點擊
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    // 點擊背景時取消
                    onCancel()
                }
            
            VStack(spacing: 5) {
                Spacer() // 將內容推至底部
                
                // 主要操作區塊 (標題, 編輯, 刪除)
                VStack(spacing: 0) {
                    // 項目名稱標題
                    Text(itemName)
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.vertical, 4) // 降低事件名稱區域高度
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // 編輯按鈕
                    Button(action: onEdit) {
                        Text("編輯")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 45) // 增加編輯按鈕高度
                    }
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // 刪除按鈕
                    Button(action: onDelete) {
                        Text("刪除")
                            .font(.system(size: 18))
                            .foregroundColor(.red) // 紅色以示警告
                            .frame(maxWidth: .infinity, minHeight: 45) // 增加編輯按鈕高度
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(width: 347, alignment: .center)
                .background(Color(red: 0.09, green: 0.09, blue: 0.09))
                .cornerRadius(13)
                .overlay(
                    Rectangle()
                        .stroke(Color(red: 0.33, green: 0.33, blue: 0.35), lineWidth: 0.5)
                        .cornerRadius(13)
                )
                .padding(.horizontal, 16)
                
                // 取消按鈕
                Button(action: onCancel) {
                    Text("取消")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(minHeight: 38)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(width: 347, alignment: .center)
                .background(Color(red: 0.09, green: 0.09, blue: 0.09))
                .cornerRadius(13)
                .padding(.horizontal, 16)
                // 注意：blur效果会使按钮文字变模糊，通常不建议在实际按钮上使用
                // 如果需要模糊效果，可以取消下面这行的注释
                // .blur(radius: 40)
                
            }
            // 從底部滑入的過場動畫
            .transition(.move(edge: .bottom))
        }
        // 對整個視圖的出現和消失進行動畫處理
        .animation(.easeInOut, value: true)
    }
}