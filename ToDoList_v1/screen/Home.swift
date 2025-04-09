import Foundation
import SwiftUI

struct Home: View {
    // 若需要在畫面上呈現更新狀態可以加上此狀態變數，否則僅透過 Console 輸出訊息
    @State private var updateStatus: String = ""
    
    // 假設先用 @State 變數暫存代辦事項清單
    // 實際情況由後端抓取或使用 EnvironmentObject
    @State private var toDoItems: [ToDoItem] = [
        ToDoItem(title: "市場研究", priority: 1, time: Date(), isCompleted: false),
        ToDoItem(title: "Prepare tomorrow's meeting", priority: 2, time: Date(), isCompleted: false),
        ToDoItem(title: "回覆所有未讀郵件", priority: 1, time: Date().addingTimeInterval(3600), isCompleted: true),
        ToDoItem(title: "練習日語聽力", priority: 3, time: Date().addingTimeInterval(7200), isCompleted: false)
    ]
    
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
                                avatarImageName: "who", // User img
                                dateText: "Jan 11 ",
                                dateText2: "Wednesday",
                                statusText: "9:02 awake",
                                temperatureText: "26°C"
                            )
//                            .padding(.horizontal, 16)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: 54)
//                    .background(Color.gray.opacity(0.2))    //改色 檢查圖層範圍
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        VStack {
                            HStack(alignment: .center) {
                                ZStack(){
                                    Text("待辦事項佇列")
                                        .font(
                                            Font.custom("Inter", size: 14)
                                                .weight(.semibold)
                                        )
                                        .foregroundColor(.white)
                                }
                                .frame(width: 84, height: 18)
                                .padding(10)
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(8)
                                
                                Spacer()
                                
                                Image(systemName: "ellipsis")
                                    .frame(width: 32, height: 32)
                                    .foregroundColor(.white)
                            }
                            
                            VStack(spacing: 0) {
                                Divider()
                                    .frame(height: 1)
                                    .background(Color.white)
                                
                                HStack(spacing: 16) {
                                    Image(systemName: "calendar")
                                    Text("Shiro birthday")
                                        .font(.headline)
                                    Spacer()
                                    Text("10:00")
                                        .font(.subheadline)
                                }
                                .frame(width: 354, height: 59)
                                .cornerRadius(12)
                                
                                Divider()
                                    .frame(height: 1)
                                    .background(Color.white)
                            }
                            .foregroundColor(.white)
                            
                            //分隔線
//                            Divider()
//                                .frame(height: 1)
//                                .background(Color.white)
                            
                            // Start list all todo item.
                            List {
                                // 直接在 List 裏面使用 ForEach
                                ForEach(toDoItems) { item in
                                    VStack{
                                        ItemRow(item: item)
                                    }
                                    .padding(.vertical, 8)
                                    .listRowInsets(EdgeInsets())
                                    .listRowBackground(Color.black)
                                }
                            }
//                            .scrollContentBackground(.hidden)
                            .listStyle(.plain)
                        }
                        
//                        Divider()
//                            .frame(height: 1)
//                            .background(Color.white)
                        
                        //Next term...
                        
                    }
//                    .frame(width: 353, height: 368, alignment: .topLeading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 24)
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
