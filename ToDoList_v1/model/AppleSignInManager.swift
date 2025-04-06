import Foundation
import AuthenticationServices
import SwiftUI
import CloudKit

class AppleSignInManager: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    static let shared = AppleSignInManager()
    
    // 定義自定義的 zone，請確認 "new_zone" 為你在 CloudKit 中所建立的 zone 名稱
    private let customZoneID = CKRecordZone.ID(zoneName: "new_zone", ownerName: CKCurrentUserDefaultName)

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

            // 登入後立即檢查使用者記錄，決定導向頁面
            handleUserRecord(userId: userId, email: email, fullName: fullName) { destination in
                DispatchQueue.main.async {
                    // 透過通知將目的地傳送給 Login 頁面進行導航
                    NotificationCenter.default.post(name: .didLogin, object: nil, userInfo: ["destination": destination])
                }
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Apple 登入失敗: \(error.localizedDescription)")
    }

    /// 登入後根據使用者記錄判斷：
    /// 若帳號存在則檢查 guidedInputCompleted：
    ///   - 為 true 則導向 Home，
    ///   - 為 false 則導向 onboarding（引導頁面）；
    /// 若帳號不存在則建立新記錄並導向 onboarding (guide3~5)。
    private func handleUserRecord(userId: String, email: String?, fullName: PersonNameComponents?, completion: @escaping (_ destination: String) -> Void) {
        let privateDatabase = CKContainer(identifier: "iCloud.com.fcu.ToDolist1").privateCloudDatabase
        let predicate = NSPredicate(format: "providerUserID == %@ AND provider == %@", userId, "Apple")
        let query = CKQuery(recordType: "ApiUser", predicate: predicate)

        // 指定自定義的 zone
        privateDatabase.fetch(withQuery: query, inZoneWith: customZoneID, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
            switch result {
            case .success(let queryResult):
                let records = queryResult.matchResults.compactMap { try? $0.1.get() }
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
                    // 帳號不存在，建立新記錄，預設 guidedInputCompleted 為 false，然後導向 onboarding (guide3~5)
                    print("首次使用第三方登入，創建新記錄並導向 onboarding")
                    // 建立一個指定 custom zone 的 recordID
                    let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: self.customZoneID)
                    let newRecord = CKRecord(recordType: "ApiUser", recordID: recordID)
                    newRecord["provider"] = "Apple" as CKRecordValue
                    newRecord["providerUserID"] = userId as CKRecordValue
                    newRecord["email"] = email as CKRecordValue?
                    if let fullName = fullName {
                        let formatter = PersonNameComponentsFormatter()
                        let nameString = formatter.string(from: fullName)
                        newRecord["name"] = nameString as CKRecordValue
                    }
                    newRecord["guidedInputCompleted"] = false as CKRecordValue
                    // 新增 createdAt 與 updatedAt 資料，皆以當前時間填入
                    let now = Date()
                    newRecord["createdAt"] = now as CKRecordValue
                    newRecord["updatedAt"] = now as CKRecordValue
                    
                    // 創建新使用者後導向 onboarding (引導頁面)
                    privateDatabase.save(newRecord) { _, error in
                        if let error = error {
                            print("創建新使用者錯誤: \(error.localizedDescription)")
                        }
                        completion("onboarding")
                    }
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
