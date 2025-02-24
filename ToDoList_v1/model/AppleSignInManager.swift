import Foundation
import AuthenticationServices
import SwiftUI
import CloudKit

class AppleSignInManager: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    static let shared = AppleSignInManager()
    
    // 發起 Apple 登入流程
    func performSignIn() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
    
    // MARK: - ASAuthorizationControllerPresentationContextProviding
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow })
        else {
            fatalError("No active window found.")
        }
        return window
    }
    
    // MARK: - ASAuthorizationControllerDelegate
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            let userId = appleIDCredential.user
            let email = appleIDCredential.email
            let fullName = appleIDCredential.fullName
            
            print("Apple 登入成功: \(userId)")
            
            // 將 CloudKit 操作改到私人資料庫
            handleUserRecord(userId: userId, email: email, fullName: fullName) { isFirstLogin in
                DispatchQueue.main.async {
                    let destination = isFirstLogin ? "onboarding" : "home"
                    
                    // 在這裡加上日誌，檢查最終要跳轉的頁面
                    print("準備送出通知：destination = \(destination)")
                    
                    NotificationCenter.default.post(name: .didLogin, object: nil, userInfo: ["destination": destination])
                }
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Apple 登入失敗: \(error.localizedDescription)")
    }
    
    // MARK: - CloudKit 使用者記錄處理（改為私人資料庫）
    private func handleUserRecord(userId: String, email: String?, fullName: PersonNameComponents?, completion: @escaping (Bool) -> Void) {
        // 改成使用 privateCloudDatabase
        let privateDatabase = CKContainer.default().privateCloudDatabase
        
        let predicate = NSPredicate(format: "userId == %@", userId)
        let query = CKQuery(recordType: "User", predicate: predicate)
        
        print("即將查詢 userId = \(userId) 在私人資料庫...")
        
        privateDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
            switch result {
            case .success(let queryResult):
                print("查詢成功，開始處理紀錄...")
                let records = queryResult.matchResults.compactMap { try? $0.1.get() }
                let now = Date()
                let calendar = Calendar.current
                
                if let record = records.first {
                    print("找到現有紀錄: \(record)")
                    if let lastLogin = record["lastLogin"] as? Date, calendar.isDate(lastLogin, inSameDayAs: now) {
                        print("今日已登入過，更新 lastLogin...")
                        record["lastLogin"] = now as CKRecordValue
                        privateDatabase.save(record) { _, error in
                            if let error = error {
                                print("更新使用者記錄錯誤: \(error.localizedDescription)")
                            } else {
                                print("更新使用者記錄成功，判定為非首次登入")
                            }
                            completion(false)
                        }
                    } else {
                        print("今日尚未登入，更新 lastLogin 為今日，判定為首次登入")
                        record["lastLogin"] = now as CKRecordValue
                        privateDatabase.save(record) { _, error in
                            if let error = error {
                                print("更新使用者記錄錯誤: \(error.localizedDescription)")
                            } else {
                                print("更新使用者記錄成功")
                            }
                            completion(true)
                        }
                    }
                } else {
                    print("沒有找到任何紀錄，建立新紀錄...")
                    let record = CKRecord(recordType: "User")
                    record["userId"] = userId as CKRecordValue
                    if let email = email {
                        record["email"] = email as CKRecordValue
                    }
                    if let fullName = fullName {
                        let formatter = PersonNameComponentsFormatter()
                        let nameString = formatter.string(from: fullName)
                        record["name"] = nameString as CKRecordValue
                    }
                    record["lastLogin"] = now as CKRecordValue
                    record["age"] = 0 as CKRecordValue
                    record["sleepTime"] = 0 as CKRecordValue
                    
                    privateDatabase.save(record) { _, error in
                        if let error = error {
                            print("建立使用者記錄錯誤: \(error.localizedDescription)")
                        } else {
                            print("建立使用者記錄成功，判定為首次登入")
                        }
                        completion(true)
                    }
                }
            case .failure(let error):
                print("查詢使用者記錄錯誤: \(error.localizedDescription)")
                completion(false)
            }
        }
    }
}

extension Notification.Name {
    static let didLogin = Notification.Name("didLogin")
}
