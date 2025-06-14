import Foundation
import AuthenticationServices
import SwiftUI
import CloudKit

class AppleSignInManager: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    static let shared = AppleSignInManager()
    
    // 使用預設 zone時，不再需要自訂 zone 的設定
    
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
            
            // 登入後立即查詢或建立使用者記錄，採用預設 zone（inZoneWith 設為 nil）
            handleUserRecord(userId: userId, email: email, fullName: fullName) { destination in
                DispatchQueue.main.async {
                    // 利用通知傳送結果給 Login 頁面進行導向
                    NotificationCenter.default.post(name: .didLogin, object: nil, userInfo: ["destination": destination])
                }
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Apple 登入失敗: \(error.localizedDescription)")
    }
    
    /// 登入後根據使用者記錄判斷：
    /// - 帳號存在：檢查 guidedInputCompleted 狀態（true → home，false → onboarding）
    /// - 帳號不存在：建立新記錄（預設 guidedInputCompleted 為 false）並導向 onboarding
    private func handleUserRecord(userId: String, email: String?, fullName: PersonNameComponents?, completion: @escaping (_ destination: String) -> Void) {
        let privateDatabase = CKContainer(identifier: "iCloud.com.fcu.ToDolist1").privateCloudDatabase
        let predicate = NSPredicate(format: "providerUserID == %@ AND provider == %@", userId, "Apple")
        let query = CKQuery(recordType: "ApiUser", predicate: predicate)
        let defaultZoneID = CKRecordZone.default().zoneID
        
        
        
        // 採用預設 zone，故 inZoneWith 傳入 nil
        privateDatabase.fetch(withQuery: query, inZoneWith: defaultZoneID, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
            switch result {
            case .success(let queryResult):
                let records = queryResult.matchResults.compactMap { try? $0.1.get() }
                print("查詢到的記錄數量：\(records.count)")
                if let record = records.first {
                    
                    // 若帳號存在，檢查 guidedInputCompleted 狀態
                    let guidedInputCompleted = record["guidedInputCompleted"] as? Bool ?? false
                    if guidedInputCompleted {
                        print("使用者已完成引導式輸入，導向 home")
                        completion("home")
                    } else {
                        print("使用者尚未完成引導式輸入，導向 onboarding")
                        completion("onboarding")
                    }
                } else {
                    // 帳號不存在，建立新記錄，預設 guidedInputCompleted 為 false
                    print("首次使用第三方登入，創建新記錄並導向 onboarding")
                    let newRecord = CKRecord(recordType: "ApiUser")  // 建立至預設 zone
                    newRecord["provider"] = "Apple" as CKRecordValue
                    newRecord["providerUserID"] = userId as CKRecordValue
                    newRecord["email"] = email as CKRecordValue?
                    if let fullName = fullName {
                        let formatter = PersonNameComponentsFormatter()
                        let nameString = formatter.string(from: fullName)
                        newRecord["name"] = nameString as CKRecordValue
                    }
                    newRecord["guidedInputCompleted"] = false as CKRecordValue
                    let now = Date()
                    newRecord["createdAt"] = now as CKRecordValue
                    newRecord["updatedAt"] = now as CKRecordValue
                    
                    privateDatabase.save(newRecord) { _, error in
                        if let error = error {
                            print("創建新使用者錯誤: \(error.localizedDescription)")
                        }
                        completion("onboarding")
                    }
                    print("save done")
                }
            case .failure(let error):
                print("查詢使用者記錄失敗: \(error.localizedDescription)")
                completion("login")
            }
        }
    }
}

extension Notification.Name {
    static let didLogin = Notification.Name("didLogin")
}
