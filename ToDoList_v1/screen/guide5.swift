import SwiftUI
import CloudKit

struct guide5: View {
    @State private var hour = 8
    @State private var minute = 20
    @State private var ampm = 1  // 0 = AM, 1 = PM
    @Environment(\.dismiss) private var dismiss  // 添加環境變數以支援返回功能
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 15) {
                // 進度條區域
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
                        .frame(width: 354, height: 285)
                    
                    VStack(spacing: 20) {
                        MultiComponentPicker(hour: $hour, minute: $minute, ampm: $ampm)
                            .frame(height: 120)
                        
                        Button(action: {
                            saveSleepTimeToCloudKit(hour: hour, minute: minute, ampm: ampm)
                            completeOnboarding()
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
                        
                        // 添加 Back 按鈕
                        Button(action: {
                            dismiss()  // 關閉當前頁面
                        }) {
                            Text("Back")
                                .font(Font.custom("Inter", size: 16))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 329, height: 20)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 60)
            
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // 完成引導流程
    private func completeOnboarding() {
        // 發送引導完成通知
        NotificationCenter.default.post(
            name: .didLogin,
            object: nil,
            userInfo: ["destination": "home"]
        )
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
            return
        }
        let appleUserID = UserDefaults.standard.string(forKey: "appleAuthorizedUserId")
        let googleUserID = UserDefaults.standard.string(forKey: "googleAuthorizedUserId")

        guard let userID = appleUserID ?? googleUserID else {
            return
        }
        
        let data: [String: CKRecordValue] = [
            "sleeptime": sleepDate as CKRecordValue
        ]
        
        CloudKitManager.shared.saveOrUpdateUserData(recordType: "PersonalData", userID: userID, data: data) { success, error in
            if success {
                // Sleep time saved/updated successfully
            } else if let error = error {
                // Error saving sleep time
            }
        }
    }
}

#Preview {
    guide5()
}
