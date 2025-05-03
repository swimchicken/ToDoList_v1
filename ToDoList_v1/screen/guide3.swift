import SwiftUI
import CloudKit

struct guide3: View {
    @State private var userName: String = "SHIRO"
    
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
                saveUserNameToCloudKit(userName: userName)
                updateApiUserName(userName: userName)
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
    
    // 儲存用戶名稱到 CloudKit 的 PersonalData 資料表 (public)
    private func saveUserNameToCloudKit(userName: String) {
        guard let userID = UserDefaults.standard.string(forKey: "appleAuthorizedUserId") else {
            print("沒有找到 Apple 用戶 ID")
            return
        }
        
        let data: [String: CKRecordValue] = [
            "name": userName as CKRecordValue
        ]
        
        CloudKitManager.shared.saveOrUpdateUserData(recordType: "PersonalData", userID: userID, data: data) { success, error in
            if success {
                print("PersonalData: User name saved/updated successfully!")
            } else if let error = error {
                print("PersonalData: Error saving user name: \(error.localizedDescription)")
            }
        }
        
        updateApiUserName(userName: userName)
    }
    
    // 更新 apiUser (private) 資料表中的 name 欄位 (僅針對 API 登入的使用者)
    private func updateApiUserName(userName: String) {
        guard let userId = UserDefaults.standard.string(forKey: "appleAuthorizedUserId") else {
            return
        }
        
        let container = CKContainer(identifier: "iCloud.com.fcu.ToDolist1")
        let privateDatabase = container.privateCloudDatabase
        let zoneID = CKRecordZone.default().zoneID
        let predicate = NSPredicate(format: "providerUserID == %@ AND provider == %@", userId, "Apple")
        let query = CKQuery(recordType: "ApiUser", predicate: predicate)
        
        privateDatabase.fetch(withQuery: query, inZoneWith: zoneID, desiredKeys: nil, resultsLimit: 1) { result in
            switch result {
            case .success(let queryResult):
                guard let record = queryResult.matchResults.compactMap({ try? $0.1.get() }).first else {
                    print("No apiUser record found to update name.")
                    return
                }
                record["name"] = userName as CKRecordValue
                privateDatabase.save(record) { savedRecord, error in
                    if let error = error {
                        print("Error updating apiUser name: \(error.localizedDescription)")
                    } else {
                        print("apiUser name updated successfully.")
                    }
                }
            case .failure(let error):
                print("Error fetching apiUser record: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    guide3()
}
