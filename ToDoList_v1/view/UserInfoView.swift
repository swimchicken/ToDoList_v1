import SwiftUI

/// 可重複使用的使用者資訊 View
struct UserInfoView: View {
    
    // 範例中示範要顯示的資料，可根據需求自由增減
    let avatarUrl: String?
    let dateText: String
    let dateText2: String
    let statusText: String
    let temperatureText: String
    @Binding var showCalendarView: Bool  // 添加綁定屬性來控制日曆視圖的顯示
    let onAvatarTapped: () -> Void  // 添加頭像點擊回調
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
//            Color.gray.opacity(0.2) //For check view
            
            HStack(spacing: 16) {
                // 頭像 - 添加點擊功能
                Button(action: onAvatarTapped) {
                    AsyncImage(url: URL(string: avatarUrl ?? "")) { phase in
                        switch phase {
                        case .empty:
                            // 正在加載時，顯示佔位符
                            Image("who")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 45, height: 45)
                                .clipShape(Circle())
                        case .success(let image):
                            // 加載成功，顯示網絡圖片
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 45, height: 45)
                                .clipShape(Circle())
                        case .failure:
                            // 加載失敗或 URL 無效，顯示預設圖片
                            Image("who")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 45, height: 45)
                                .clipShape(Circle())
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                
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
                
                // 日曆按鈕（右上角）
                Button {
                    withAnimation(.easeInOut) {
                        showCalendarView = true
                    }
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(8)
                }
            }
        }
//        .frame(maxWidth: .infinity) // 讓背景能自動延展
        .frame(height: 54)
    }
}
