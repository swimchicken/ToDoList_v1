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
    let dateText2: String
    let statusText: String
    let temperatureText: String
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
//            Color.gray.opacity(0.2) //For check view
            
            HStack(spacing: 16) {
                // 頭像
                Image(avatarImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 45, height: 45)
                    .clipShape(Circle())
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 2) {
                    // 日期
                    HStack(){
                        (
                            Text(dateText)
                                .foregroundColor(.white)
                                .font(.headline)
                            +
                            Text(dateText2)
                                .foregroundStyle(.white.opacity(0.3))
                                .font(.headline)
                        )
                        .font(Font.custom("Inter", size: 17.3))
                            .bold()
                    }
                    
                    HStack(){
                        Image(systemName: "eyes.inverse")
                                    .foregroundColor(.white)
                        
                        // 狀態 + 溫度
//                        Text("\(statusText) • \(temperatureText)")
//                            .font(.subheadline)
//                            .foregroundColor(.white.opacity(0.7))
                        
                        Text(statusText)
                            .font(Font.custom("Inter", size: 11.7))
                            .foregroundStyle(.white)
                        
                        Image(systemName: "sun.max.fill")
                            .foregroundColor(.yellow)
                        
                        Text(temperatureText)
                            .font(Font.custom("Inter", size: 11.7))
                            .foregroundStyle(.white)
                    }
                }
                
                Spacer()
                
                ZStack(){
                    Color.white.opacity(0.08)
                        .cornerRadius(8)
                    
                    // 圖示按鈕 calendar
                    Image(systemName: "calendar")
                        .foregroundColor(.white)
                }
                .frame(width: 54, height: 54)
            }
        }
//        .frame(maxWidth: .infinity) // 讓背景能自動延展
        .frame(height: 54)
    }
}
