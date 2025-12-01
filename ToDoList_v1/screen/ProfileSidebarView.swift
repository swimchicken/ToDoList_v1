import SwiftUI
import CloudKit

struct ProfileSidebarView: View {
    @Binding var isPresented: Bool
    @State private var dragOffset: CGFloat = 0
    @StateObject private var userInfoManager = UserInfoManager.shared

    // For editing name
    @State private var isShowingEditNameAlert = false
    @State private var newName = ""

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background Mask
                if isPresented {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isPresented = false
                            }
                        }
                        .transition(.opacity)
                }
                
                // Sidebar Content
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        // User Info Area
                        userInfoView
                        
                        // Menu Items
                        menuItemsView
                        
                        Spacer()
                        
                        // Upgrade to PRO Card
                        upgradeCard
                    }
                    .frame(width: min(geometry.size.width * 0.75, 320))
                    .background(Color(hex: "1C1C1E"))
                    .offset(x: isPresented ? 0 : -min(geometry.size.width * 0.75, 320))
                    .offset(x: dragOffset)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPresented) // ✅ 新增
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if value.translation.width < 0 {
                                    dragOffset = value.translation.width
                                }
                            }
                            .onEnded { value in
                                if value.translation.width < -100 {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        isPresented = false
                                    }
                                }
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    dragOffset = 0
                                }
                            }
                    )
                    
                    Spacer()
                }
            }
            .alert("Edit Name", isPresented: $isShowingEditNameAlert) {
                TextField("Enter new name", text: $newName)
                Button("Save", action: updateUserName)
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("profile.enter_new_name")
            }
        }
        .transition(.move(edge: .leading))
        .onAppear {
            // 當側邊欄出現時，刷新用戶信息
            userInfoManager.refreshUserInfo()
        }
    }
    
    private var userInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: userInfoManager.userInfo.avatarUrl ?? "")) { phase in
                    switch phase {
                    case .empty:
                        Image("who")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 48, height: 48)
                            .clipShape(Circle())
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 48, height: 48)
                            .clipShape(Circle())
                    case .failure:
                        Image("who")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 48, height: 48)
                            .clipShape(Circle())
                    @unknown default:
                        EmptyView()
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(userInfoManager.userInfo.name)
                            .font(.custom("Inter", size: 20).weight(.bold))
                            .foregroundColor(.white)

                        Button(action: {
                            self.newName = userInfoManager.userInfo.name
                            self.isShowingEditNameAlert = true
                        }) {
                            Image("EditName")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                    }

                    Text(userInfoManager.userInfo.email)
                        .font(.custom("Inter", size: 13))
                        .foregroundColor(.gray)
                    
                    Text("profile.full_access")
                        .font(.custom("Inter", size: 12))
                        .foregroundColor(.gray.opacity(0.7))
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .padding(.bottom, 24)
        }
    }
    
    private var menuItemsView: some View {
        VStack(spacing: 0) {
            
            NavigationLink(destination: SettingView()) {
                // 我們仍然使用 MenuItemView 來保持外觀
                MenuItemView(icon: "rectangle.stack", title: "History")
            }
            .simultaneousGesture(TapGesture().onEnded {
                // 點擊時關閉側邊欄
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isPresented = false
                }
            })
            Divider().background(Color.white.opacity(0.1)).padding(.horizontal, 20)
            NavigationLink(destination: SettingView()) {
                // 我們仍然使用 MenuItemView 來保持外觀
                MenuItemView(icon: "gearshape", title: "Setting")
            }
            .simultaneousGesture(TapGesture().onEnded {
                // 點擊時關閉側邊欄
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isPresented = false
                }
            })
            Divider().background(Color.white.opacity(0.1)).padding(.horizontal, 20)
            NavigationLink(destination: AboutUsView()) {
                // 我們仍然使用 MenuItemView 來保持外觀
                MenuItemView(icon: "info.circle", title: "About & Help")
            }
            .simultaneousGesture(TapGesture().onEnded {
                // 點擊時關閉側邊欄
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isPresented = false
                }
            })
            
        }
        .padding(.top, 12)
    }
    
    private var upgradeCard: some View {
        Button(action: {
            print("Upgrade to PRO tapped")
            // Future action for upgrading to PRO
        }) {
            Image("Upgrade2PRO")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }
    
    
    private func updateUserName() {
        guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else {
            print("[ProfileSidebarView] Update Name: Name cannot be empty.")
            return
        }

        print("[ProfileSidebarView] Update Name: Attempting to save new name '\(newName)'")

        userInfoManager.updateUserName(newName) { success in
            DispatchQueue.main.async {
                if success {
                    print("[ProfileSidebarView] Update Name: Successfully updated name.")
                } else {
                    print("[ProfileSidebarView] Update Name: Failed to update name.")
                }
            }
        }
    }
}

struct MenuItemView: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.gray)
                .frame(width: 24)
            
            Text(title)
                .font(.custom("Inter", size: 16))
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }
    
}

#if DEBUG
struct ProfileSidebarView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileSidebarView(isPresented: .constant(true))
    }
}
#endif
