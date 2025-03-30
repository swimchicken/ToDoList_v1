import Foundation
import AuthenticationServices
import SwiftUI
import CloudKit

class AppleSignInManager: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    static let shared = AppleSignInManager()

    func performSignIn() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
    
    
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow })
        else {
            fatalError("No active window found.")
        }
        return window
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            let userId = appleIDCredential.user
            // 儲存 Apple 用戶的唯一 ID
            UserDefaults.standard.set(userId, forKey: "appleAuthorizedUserId")
            let email = appleIDCredential.email
            let fullName = appleIDCredential.fullName

            // 根據 ThirdPartyLogin 資料表處理
            handleUserRecord(userId: userId, email: email, fullName: fullName) { destination in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .didLogin, object: nil, userInfo: ["destination": destination])
                }
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Apple 登入失敗: \(error.localizedDescription)")
    }

    private func handleUserRecord(userId: String, email: String?, fullName: PersonNameComponents?, completion: @escaping (_ destination: String) -> Void) {
        let privateDatabase = CKContainer(identifier: "iCloud.com.fcu.ToDolist1").privateCloudDatabase
        // 利用 providerUserID 與 provider 作為查詢條件
        let predicate = NSPredicate(format: "providerUserID == %@ AND provider == %@", userId, "Apple")
        let query = CKQuery(recordType: "ApiUser", predicate: predicate)

        privateDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
            switch result {
            case .success(let queryResult):
                let records = queryResult.matchResults.compactMap { try? $0.1.get() }
                if let record = records.first {
                    // 若已存在記錄，檢查是否完成引導式基本資料輸入
                    let guidedInputCompleted = record["guidedInputCompleted"] as? Bool ?? false
                    if !guidedInputCompleted {
                        print("使用者尚未完成引導式輸入，導向 onboarding")
                        completion("onboarding")
                    } else {
                        // 判斷 lastLoginDate 是否為今天（代表曾進入過 Home）
                        let lastLogin = record["lastLoginDate"] as? Date
                        let now = Date()
                        let calendar = Calendar.current
                        if let lastLogin = lastLogin, calendar.isDate(lastLogin, inSameDayAs: now) {
                            print("今天已進入 Home，導向 home")
                            completion("home")
                        } else {
                            print("使用者已登入但尚未進入 Home，本次導向 login")
                            completion("login")
                        }
                    }
                } else {
                    // 尚無記錄，建立新記錄。guidedInputCompleted 預設 false，且不更新 lastLoginDate
                    print("首次使用第三方登入，創建新記錄並導向 onboarding")
                    let record = CKRecord(recordType: "ApiUser")
                    record["provider"] = "Apple" as CKRecordValue
                    record["providerUserID"] = userId as CKRecordValue
                    record["email"] = email as CKRecordValue?
                    if let fullName = fullName {
                        let formatter = PersonNameComponentsFormatter()
                        let nameString = formatter.string(from: fullName)
                        record["name"] = nameString as CKRecordValue
                    }
                    record["guidedInputCompleted"] = false as CKRecordValue
                    // lastLoginDate 不在此更新，待使用者進入 Home 後更新
                    privateDatabase.save(record) { _, error in
                        if let error = error {
                            print("創建新使用者錯誤: \(error.localizedDescription)")
                        }
                        completion("onboarding")
                    }
                }
            case .failure(let error):
                print("查詢失敗: \(error.localizedDescription)")
                completion("login")
            }
        }
    }
}

extension Notification.Name {
    static let didLogin = Notification.Name("didLogin")
}
