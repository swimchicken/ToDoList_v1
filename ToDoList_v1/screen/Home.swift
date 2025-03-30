//
//  Home.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/2/23.
//

import Foundation
import SwiftUI

struct Home: View {
    // 若需要在畫面上呈現更新狀態可以加上此狀態變數，否則僅透過 Console 輸出訊息
    @State private var updateStatus: String = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 15) {
                    
//                    VStack() {
//                        // MARK: - 頂部資訊區域
//                        HStack(spacing: 12) {
//                            // 頭像 (請在專案中新增 "avatar" 圖片)
//                            Image("avatar")
//                                .resizable()
//                                .scaledToFill()
//                                .frame(width: 44, height: 44)
//                                .clipShape(Circle())
//
//                            VStack(alignment: .leading, spacing: 4) {
//
//                                // 日期
//                                Text("Jan 11 Wednesday")
//                                    .font(
//                                        Font.custom("Inria Sans", size: 20)
//                                            .weight(.bold)
//                                    )
//                                    .foregroundColor(.white)
//
//                                // 狀態與溫度
//                                Text("9:02 awake • 26°C")
//                                    .font(
//                                        Font.custom("Inria Sans", size: 14)
//                                            .weight(.regular)
//                                    )
//                                    .foregroundColor(.white.opacity(0.7))
//                            }
//
//                            Spacer()
//
//                            // 右上角可放置設定按鈕或其他圖示
//                            Image(systemName: "gearshape")
//                                .foregroundColor(.white)
//                                .font(.system(size: 20))
//                        }
//                        .padding(.horizontal, 12)
//
//                        // 分隔線
//                        Rectangle()
//                            .fill(Color.white.opacity(0.2))
//                            .frame(height: 1)
//                            .padding(.horizontal, 12)
//                    }
                    // 使用者頭像、日期資料、日曆 icon
                    ZStack {
                        // 預設背景
                        VStack(spacing: 20) {
                            // 呼叫自訂的 UserInfoView
                            UserInfoView(
                                avatarImageName: "avatar",  // 請將 "avatar" 替換成你專案中的圖片名稱
                                dateText: "Jan 11 Wednesday",
                                statusText: "9:02 awake",
                                temperatureText: "26°C"
                            )
                            .padding(.horizontal, 16)
                            
                            // 其餘內容 ...
                            
                            Spacer()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        VStack {
                            HStack(alignment: .center, spacing: 10) {
                                Text("待辦事項佇列")
                                    .font(
                                        Font.custom("Inter", size: 14)
                                            .weight(.semibold)
                                    )
                                    .foregroundColor(.white)
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(8)
                            
                            HStack(alignment: .center, spacing: 0) {
                                Image(systemName: "ellipsis")
                                    .frame(width: 32, height: 32)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 0)
                            .frame(width: 32, height: 32, alignment: .center)
                            
                            // MARK: - 待辦事項列表 (這裡示意部分，根據需求調整)
//                            List {
//                                ForEach(tasks) { task in
//                                    HStack(spacing: 12) {
//                                        if let icon = task.iconName {
//                                            Image(systemName: icon)
//                                                .font(.system(size: 20))
//                                                .foregroundColor(task.isHighlighted ? .yellow : .gray)
//                                        } else {
//                                            Circle()
//                                                .fill(Color.gray)
//                                                .frame(width: 18, height: 18)
//                                        }
//                                        Text(task.title)
//                                            .foregroundColor(.white)
//                                        Spacer()
//                                        Text(task.time)
//                                            .foregroundColor(.white.opacity(0.7))
//                                    }
//                                    .listRowBackground(Color.black)
//                                }
//                            }
//                            .scrollContentBackground(.hidden)
//                            .listStyle(PlainListStyle())
                        }
                    }
                    .padding(0)
                    .frame(width: 353, height: 368, alignment: .topLeading)
                }
            }
            // 畫面出現時更新最近登入時間
            .onAppear {
                guard let userId = UserDefaults.standard.string(forKey: "appleAuthorizedUserId") else {
                    print("找不到 Apple 用戶 ID")
                    updateStatus = "找不到 Apple 用戶 ID"
                    return
                }
                SaveLast.updateLastLoginDate(forUserId: userId) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success:
                            print("登入時間已更新")
                            updateStatus = "登入時間已更新"
                        case .failure(let error):
                            print("更新登入時間失敗: \(error.localizedDescription)")
                            updateStatus = "更新登入時間失敗: \(error.localizedDescription)"
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    Home()
}
