//
//  UserInfo.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/3/29.
//

import SwiftUI

/// 可重複使用的使用者資訊 View
struct UserInfoView: View {
    
    // 範例中示範要顯示的資料，可根據需求自由增減
    let avatarImageName: String
    let dateText: String
    let statusText: String
    let temperatureText: String
    
    var body: some View {
        // 可使用 ZStack 或 HStack 做容器
        ZStack {
            // 背景（可改用其他顏色或透明度）
            Color.white.opacity(0.08)
                .cornerRadius(12)
            
            HStack(spacing: 12) {
                // 頭像
                Image(avatarImageName) //----------------> import picture  
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    // 日期
                    Text(dateText)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    // 狀態 + 溫度
                    Text("\(statusText) • \(temperatureText)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // 右側可加上您想要的圖示或按鈕（此處示範 calendar）
                Image(systemName: "calendar")
                    .foregroundColor(.white)
            }
            .padding()
        }
        .frame(maxWidth: .infinity) // 讓背景能自動延展
    }
}
