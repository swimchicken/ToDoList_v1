import SwiftUI
import CloudKit

struct ProfileSidebarView: View {
    @Binding var isPresented: Bool
    @State private var dragOffset: CGFloat = 0
    @State private var appUser: AppUser?
    
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
                Text("Please enter your new name.")
            }
        }
        .transition(.move(edge: .leading))
        .onAppear(perform: fetchCurrentUser)
    }
    
    private var userInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image("who")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(appUser?.name ?? "Loading...")
                            .font(.custom("Inter", size: 20).weight(.bold))
                            .foregroundColor(.white)
                        
                        Button(action: {
                            self.newName = self.appUser?.name ?? ""
                            self.isShowingEditNameAlert = true
                        }) {
                            Image("EditName")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Text(appUser?.email ?? "...")
                        .font(.custom("Inter", size: 13))
                        .foregroundColor(.gray)
                    
                    Text("Full access")
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
            MenuItemView(icon: "rectangle.stack", title: "History", action: { print("History tapped") })
            Divider().background(Color.white.opacity(0.1)).padding(.horizontal, 20)
            MenuItemView(icon: "gearshape", title: "Setting", action: { print("Setting tapped") })
            Divider().background(Color.white.opacity(0.1)).padding(.horizontal, 20)
            MenuItemView(icon: "info.circle", title: "About & Help", action: { print("About & Help tapped") })
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
    
    private func fetchCurrentUser() {
        let appleUserID = UserDefaults.standard.string(forKey: "appleAuthorizedUserId")
        let googleUserID = UserDefaults.standard.string(forKey: "googleAuthorizedUserId")
        
        guard let userID = appleUserID ?? googleUserID else {
            print("[ProfileSidebarView] Fetch User: User ID not found in UserDefaults.")
            return
        }
        print("[ProfileSidebarView] Fetch User: Found User ID \(userID)")

        // Corrected predicate to use "userID" to match the CloudKitManager
        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: "ApiUser", predicate: predicate)
        
        let privateDatabase = CKContainer(identifier: "iCloud.com.fcu.ToDolist1").privateCloudDatabase
        privateDatabase.perform(query, inZoneWith: nil) { records, error in
            if let error = error {
                print("[ProfileSidebarView] Fetch User: Error fetching user data: \(error.localizedDescription)")
                return
            }
            
            guard let record = records?.first else {
                print("[ProfileSidebarView] Fetch User: No record found for user ID with 'userID' field.")
                return
            }
            
            print("[ProfileSidebarView] Fetch User: Successfully fetched record: \(record)")
            let name = record["name"] as? String ?? "No Name"
            let email = record["email"] as? String ?? "No Email"
            
            DispatchQueue.main.async {
                print("[ProfileSidebarView] Fetch User: Updating UI with Name: \(name), Email: \(email)")
                self.appUser = AppUser(name: name, email: email)
            }
        }
    }
    
    private func updateUserName() {
        guard let userID = (UserDefaults.standard.string(forKey: "appleAuthorizedUserId") ?? UserDefaults.standard.string(forKey: "googleAuthorizedUserId")) else {
            print("[ProfileSidebarView] Update Name: User ID not found.")
            return
        }
        
        let dataToUpdate = ["name": newName] as [String: CKRecordValue]
        print("[ProfileSidebarView] Update Name: Attempting to save new name '\(newName)' for user ID \(userID)")

        CloudKitManager.shared.saveOrUpdateUserData(recordType: "ApiUser", userID: userID, data: dataToUpdate) { success, error in
            if success {
                print("[ProfileSidebarView] Update Name: Successfully updated name in CloudKit.")
                DispatchQueue.main.async {
                    self.appUser?.name = self.newName
                    print("[ProfileSidebarView] Update Name: UI updated with new name.")
                }
            } else {
                print("[ProfileSidebarView] Update Name: Failed to update name: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
}

struct MenuItemView: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
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
}

#if DEBUG
struct ProfileSidebarView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileSidebarView(isPresented: .constant(true))
    }
}
#endif
