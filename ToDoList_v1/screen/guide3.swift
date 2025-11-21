import SwiftUI

struct guide3: View {
    @State private var userName: String = "SHIRO"
    private let apiDataManager = APIDataManager.shared
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 15) {
                // 進度條
                ZStack(alignment: .leading) {
                    HStack {
                        Rectangle()
                            .fill(Color.green)
                            .frame(height: 10)
                            .cornerRadius(10)
                        
                        Rectangle()
                            .fill(Color.green)
                            .frame(height: 10)
                            .cornerRadius(10)
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 10)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.green, lineWidth: 2)
                            )
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 10)
                            .cornerRadius(10)
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 10)
                            .cornerRadius(10)
                        
                        Image("Gride01")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 10)
                
                Text("What's your name?")
                    .font(Font.custom("Inria Sans", size: 25.45489)
                            .weight(.bold)
                            .italic())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(0.9)
                
                Spacer()
                
                ZStack {
                    Rectangle()
                        .foregroundColor(.clear)
                        .background(.white.opacity(0.08))
                        .cornerRadius(36)
                        .frame(width: 354, height: 180)
                    
                    VStack(spacing: 20) {
                        TextField("", text: $userName)
                            .font(Font.custom("Inter", size: 20).weight(.medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .frame(height: 44)
                            .padding(.horizontal, 40)
                        
                        NavigationLink(destination: guide4().navigationBarBackButtonHidden(true)) {
                            Text("Next")
                                .font(Font.custom("Inter", size: 16).weight(.semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity, minHeight: 56)
                                .background(Color(red: 0.94, green: 0.94, blue: 0.94))
                                .cornerRadius(44)
                                .padding(.vertical, 17)
                                .frame(width: 329, height: 56, alignment: .center)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 60)
            .onDisappear {
                updateUserName(userName: userName)
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // 使用API更新用戶名稱
    private func updateUserName(userName: String) {
        guard !userName.isEmpty else {
            print("guide3: 用戶名稱為空，跳過更新")
            return
        }

        print("guide3: 開始更新用戶名稱: \(userName)")

        Task {
            do {
                let updatedUser = try await apiDataManager.updateUserProfile(name: userName)
                await MainActor.run {
                    print("guide3: 成功更新用戶名稱: \(updatedUser.name ?? "Unknown")")
                }
            } catch {
                await MainActor.run {
                    print("guide3: 更新用戶名稱失敗: \(error.localizedDescription)")
                }
            }
        }
    }
}

#Preview {
    guide3()
}
