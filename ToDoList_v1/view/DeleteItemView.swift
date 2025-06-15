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
            // 半透明的黑色背景，模擬彈出視窗的遮罩效果
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    // 點擊背景時取消
                    onCancel()
                }
            
            VStack(spacing: 8) {
                Spacer() // 將內容推至底部
                
                // 主要操作區塊 (標題, 編輯, 刪除)
                VStack(spacing: 0) {
                    // 項目名稱標題
                    Text(itemName)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding()
                    
                    Divider()
                    
                    // 編輯按鈕
                    Button(action: onEdit) {
                        Text("編輯")
                            .font(.system(size: 20))
                            .frame(maxWidth: .infinity, minHeight: 58)
                    }
                    
                    Divider()
                    
                    // 刪除按鈕
                    Button(action: onDelete) {
                        Text("刪除")
                            .font(.system(size: 20))
                            .foregroundColor(.red) // 紅色以示警告
                            .frame(maxWidth: .infinity, minHeight: 58)
                    }
                }
                .background(.regularMaterial) // 使用材質背景，更符合現代iOS風格
                .cornerRadius(14)
                .padding(.horizontal)
                
                // 取消按鈕
                Button(action: onCancel) {
                    Text("取消")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 58)
                }
                .background(.regularMaterial)
                .cornerRadius(14)
                .padding(.horizontal)
                
            }
            // 從底部滑入的過場動畫
            .transition(.move(edge: .bottom))
        }
        // 對整個視圖的出現和消失進行動畫處理
        .animation(.easeInOut, value: true)
    }
}
