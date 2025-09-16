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
    
    /// 當用戶點擊「放入代辦佇列」時執行的閉包
    let onMoveToQueue: () -> Void
    
    // 獲取屏幕寬度，減去邊距以貼近屏幕邊緣
    private var containerWidth: CGFloat {
        UIScreen.main.bounds.width - 32
    }
    
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
                        .font(Font.custom("SF Pro Text", size: 13))
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color(red: 0.92, green: 0.92, blue: 0.96).opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 6) // 調整事件名稱區域高度
                        .padding(.bottom, 4) // 增加與下邊線的間距
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // 編輯按鈕
                    Button(action: onEdit) {
                        Text("編輯")
                            .font(Font.custom("SF Pro Display", size: 20))
                            .kerning(0.38)
                            .multilineTextAlignment(.center)
                            .foregroundColor(Color(red: 0.04, green: 0.52, blue: 1))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .frame(minHeight: 45) // 保持按鈕高度
                    }
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // 放入代辦佇列按鈕
                    Button(action: onMoveToQueue) {
                        Text("放入代辦佇列")
                            .font(Font.custom("SF Pro Display", size: 20))
                            .kerning(0.38)
                            .multilineTextAlignment(.center)
                            .foregroundColor(Color(red: 0.04, green: 0.52, blue: 1))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .frame(minHeight: 45) // 保持按鈕高度
                    }
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // 刪除按鈕
                    Button(action: onDelete) {
                        Text("刪除")
                            .font(Font.custom("SF Pro Display", size: 20))
                            .kerning(0.38)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.red) // 保持紅色以示警告
                            .frame(maxWidth: .infinity, alignment: .center)
                            .frame(minHeight: 45) // 保持按鈕高度
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(width: containerWidth, alignment: .center)
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
                        .font(Font.custom("SF Pro Display", size: 20))
                        .kerning(0.38)
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color(red: 0.04, green: 0.52, blue: 1))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(minHeight: 38)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(width: containerWidth, alignment: .center)
                .background(Color(red: 0.09, green: 0.09, blue: 0.09))
                .cornerRadius(13)
                .padding(.horizontal, 16)
                
            }
            // 從底部滑入的過場動畫
            .transition(.move(edge: .bottom))
        }
        // 對整個視圖的出現和消失進行動畫處理
        .animation(.easeInOut, value: true)
    }
}