import SwiftUI
import CloudKit

struct guide4: View {
    @State private var selectedAge = 7

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 15) {
                    // 進度條
                    ZStack(alignment: .leading) {
                        HStack {
                            // 前面 4 塊綠色
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
                            
                            // 最後一塊可能是 checkmark
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
                            .frame(width: 354, height: 240)
                        
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
                            
                            NavigationLink(destination: guide5()) {
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
                .onDisappear {
                    saveAgeToCloudKit(age: selectedAge)
                }
            }
        }
    }
    
    // 儲存用戶年齡到 CloudKit 的 PersonalData 資料表，使用 key "ageInt"
    private func saveAgeToCloudKit(age: Int) {
        guard let userID = UserDefaults.standard.string(forKey: "appleAuthorizedUserId") else {
            print("沒有找到 Apple 用戶 ID")
            return
        }
        
        let data: [String: CKRecordValue] = [
            "age": age as CKRecordValue
        ]
        
        CloudKitManager.shared.saveOrUpdateUserData(recordType: "PersonalData", userID: userID, data: data) { success, error in
            if success {
                print("User age saved/updated successfully!")
            } else if let error = error {
                print("Error saving user age: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    guide4()
}
