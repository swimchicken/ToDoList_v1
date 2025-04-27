import SwiftUI
import CloudKit

struct guide5: View {
    @State private var hour = 8
    @State private var minute = 20
    @State private var ampm = 1  // 0 = AM, 1 = PM
    @State private var navigateToHome = false  // 控制跳轉到 Home 頁面的狀態
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 15) {
                    // 進度條區域
                    ZStack(alignment: .leading) {
                        HStack {
                            // 進度條的各個塊
                            Rectangle()
                                .fill(Color.green)
                                .frame(height: 10)
                                .cornerRadius(10)
                            Rectangle()
                                .fill(Color.green)
                                .frame(height: 10)
                                .cornerRadius(10)
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
                            
                            // 最後是打勾符號
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 10)
                    
                    Text("你通常幾點入睡?")
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
                            .frame(width: 354, height: 240)
                        
                        VStack(spacing: 20) {
                            MultiComponentPicker(hour: $hour, minute: $minute, ampm: $ampm)
                                .frame(height: 120)
                            
                            Button(action: {
                                // 儲存用戶睡眠時間並跳轉到 Home
                                saveSleepTimeToCloudKit(hour: hour, minute: minute, ampm: ampm)
                                navigateToHome = true  // 更新狀態以觸發跳轉
                            }) {
                                Text("Start")
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
            }
            
            // 當 navigateToHome 為 true 時，跳轉到 Home 頁面
            NavigationLink(destination: Home(), isActive: $navigateToHome) {
                EmptyView()
            }
        }
    }
    
    // 輔助函數：根據使用者選取的時間組件轉換為 Date
    private func dateFromTime(hour: Int, minute: Int, ampm: Int) -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        var hour24 = hour
        if ampm == 1 { // PM
            if hour != 12 {
                hour24 += 12
            }
        } else {
            if hour == 12 {
                hour24 = 0
            }
        }
        components.hour = hour24
        components.minute = minute
        components.second = 0
        return calendar.date(from: components)
    }
    
    // 儲存用戶睡眠時間到 CloudKit 的 PersonalData 資料表，key 使用 "sleeptime"
    private func saveSleepTimeToCloudKit(hour: Int, minute: Int, ampm: Int) {
        guard let sleepDate = dateFromTime(hour: hour, minute: minute, ampm: ampm) else {
            print("Failed to create sleep date")
            return
        }
        guard let userID = UserDefaults.standard.string(forKey: "appleAuthorizedUserId") else {
            print("沒有找到 Apple 用戶 ID")
            return
        }
        
        let data: [String: CKRecordValue] = [
            "sleeptime": sleepDate as CKRecordValue
        ]
        
        // 此處不需額外指定 zone，因為 CloudKitManager 已預設採用 CKRecordZone.default().zoneID
        CloudKitManager.shared.saveOrUpdateUserData(recordType: "PersonalData", userID: userID, data: data) { success, error in
            if success {
                print("Sleep time saved/updated successfully!")
            } else if let error = error {
                print("Error saving sleep time: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    guide5()
}
