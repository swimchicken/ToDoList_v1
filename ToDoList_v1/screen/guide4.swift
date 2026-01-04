import SwiftUI
import CloudKit

struct guide4: View {
    @State private var selectedAge = 7
    @Environment(\.dismiss) private var dismiss  // 添加環境變數以支援返回功能

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
                        
                        Image("Gride01")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 10)
                
                Text("What's your age?")
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
                        .frame(width: 354, height: 275)
                    
                    VStack(spacing: 20) {
                        Picker("Select Age", selection: $selectedAge) {
                            ForEach(0...130, id: \.self) { age in
                                Text("\(age)")
                                    .font(.system(size: 30).weight(.medium))
                                    .foregroundColor(.white)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                        .labelsHidden()
                        
                        NavigationLink(destination: guide5().navigationBarBackButtonHidden(true)) {
                            Text("Next")
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
            .onDisappear {
                saveAgeToCloudKit(age: selectedAge)
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
    
    // 儲存用戶年齡到 CloudKit 的 PersonalData 資料表
    private func saveAgeToCloudKit(age: Int) {
        let appleUserID = UserDefaults.standard.string(forKey: "appleAuthorizedUserId")
        let googleUserID = UserDefaults.standard.string(forKey: "googleAuthorizedUserId")

        guard let userID = appleUserID ?? googleUserID else {
            return
        }
        
        let data: [String: CKRecordValue] = [
            "age": age as CKRecordValue
        ]
        
        CloudKitManager.shared.saveOrUpdateUserData(recordType: "PersonalData",
                                                    userID: userID,
                                                    data: data) { success, error in
            if success {
                // User age saved/updated successfully
            } else if let error = error {
                // Error saving user age: \(error.localizedDescription)
            }
        }
    }
}

#Preview {
    guide4()
}
