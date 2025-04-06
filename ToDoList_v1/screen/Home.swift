import Foundation
import SwiftUI

struct Home: View {
    // 若需要在畫面上呈現更新狀態可以加上此狀態變數，否則僅透過 Console 輸出訊息
    @State private var updateStatus: String = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    // 使用者頭像、日期資料、日曆 icon
                    ZStack {
//                        Rectangle()
//                            .foregroundColor(.clear)
//                            .frame(width: 354, height: 54)
//                            .background(.white.opacity(0.08))
                        
                        // 預設背景
                        VStack() {
                            // 呼叫自訂的 UserInfoView
                            UserInfoView(
                                avatarImageName: "who",  // 請將 "avatar" 替換成你專案中的圖片名稱
                                dateText: "Jan 11 ",
                                dateText2: "Wednesday",
                                statusText: "9:02 awake",
                                temperatureText: "26°C"
                            )
//                            .padding(.horizontal, 16)
                            
//                            Spacer()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: 54)
//                    .frame(width: 365, height: 54)
//                    .padding(.top, 0)
//                    .ignoresSafeArea(edges: .top)
                    .background(Color.gray.opacity(0.2))
                    
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
//                    .frame(width: 353, height: 368, alignment: .topLeading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 60)
            }
            
            // 畫面出現時更新最近登入時間
            .onAppear {
                guard let userId = UserDefaults.standard.string(forKey: "appleAuthorizedUserId") else {
                    print("找不到 Apple 用戶 ID")
                    updateStatus = "找不到 Apple 用戶 ID"
                    return
                }
                // 呼叫 SaveLast 更新登入時間並將 guidedInputCompleted 設為 1
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
