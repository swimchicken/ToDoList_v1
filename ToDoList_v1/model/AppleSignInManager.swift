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
            
            // Apple登入成功後立即設置持久化狀態
            UserDefaults.standard.set(true, forKey: "hasPersistedLogin")
            print("AppleSignInManager: Apple登入成功，已設置持久化登入狀態")
            
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
        // 先確保 CloudKit 認證狀態正常
        let cloudKitService = CloudKitService.shared

        // 直接執行查詢，如果失敗就使用預設流程
        performUserRecordQuery(userId: userId, email: email, fullName: fullName) { destination in
            // 在返回導向結果前，觸發CloudKit資料同步
            print("Apple登入成功，準備觸發CloudKit資料同步")

            // 延遲2秒後觸發同步，確保CloudKit認證狀態穩定
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                DataSyncManager.shared.performSync { result in
                    switch result {
                    case .success(let count):
                        print("Apple登入後成功同步 \(count) 個待辦事項")
                        // 發送資料更新通知
                        NotificationCenter.default.post(
                            name: Notification.Name("TodoItemsDataRefreshed"),
                            object: nil
                        )
                    case .failure(let error):
                        print("Apple登入後同步失敗: \(error.localizedDescription)")
                    }
                }
            }

            completion(destination)
        }
    }
    
    /// 執行實際的用戶記錄查詢
    private func performUserRecordQuery(userId: String, email: String?, fullName: PersonNameComponents?, completion: @escaping (_ destination: String) -> Void) {
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
                    self.createNewUserRecord(userId: userId, email: email, fullName: fullName, completion: completion)
                }
            case .failure(let error):
                print("查詢使用者記錄失敗: \(error.localizedDescription)")
                
                // 檢查是否是認證問題或帳戶不存在
                let nsError = error as NSError
                if nsError.domain == CKErrorDomain && nsError.code == CKError.notAuthenticated.rawValue ||
                   error.localizedDescription.contains("bad or missing auth token") {
                    print("AppleSignInManager: CloudKit 認證問題，但Apple登入成功，創建新帳戶")
                    // CloudKit認證問題時，直接創建新用戶記錄
                    self.createNewUserRecord(userId: userId, email: email, fullName: fullName, completion: completion)
                } else {
                    print("AppleSignInManager: 其他錯誤(\(error.localizedDescription))，導向 onboarding")
                    // 其他錯誤也進入onboarding流程
                    completion("onboarding")
                }
            }
        }
    }
    
    /// 創建新用戶記錄
    private func createNewUserRecord(userId: String, email: String?, fullName: PersonNameComponents?, completion: @escaping (_ destination: String) -> Void) {
        let privateDatabase = CKContainer(identifier: "iCloud.com.fcu.ToDolist1").privateCloudDatabase
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
                
                // 檢查是否是認證問題
                let nsError = error as NSError
                if nsError.domain == CKErrorDomain && nsError.code == CKError.notAuthenticated.rawValue {
                    print("AppleSignInManager: 創建用戶時認證問題，但Apple登入已成功，繼續onboarding流程")
                    // 即使CloudKit創建失敗，由於Apple登入成功，還是可以進入onboarding
                }
                
                // 不管CloudKit是否成功，都進入onboarding（因為Apple登入已成功）
                print("AppleSignInManager: 新用戶進入onboarding流程")
                completion("onboarding")
            } else {
                print("AppleSignInManager: 成功創建新用戶記錄，進入onboarding")
                completion("onboarding")
            }
        }
        print("save done")
    }
}

extension Notification.Name {
    static let didLogin = Notification.Name("didLogin")
}
