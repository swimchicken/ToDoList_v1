import Foundation
import SwiftUI
import CloudKit
import GoogleSignIn

class GoogleSignInManager: NSObject {
    static let shared = GoogleSignInManager()
    
    func performSignIn() {
        // 暫時在開發模式也使用真正的 Google Sign-In 進行測試
        performRealGoogleSignIn()
        
        // 如果需要回到模擬模式，取消上面註解並使用下面的條件編譯：
        /*
        #if DEBUG
        // 開發模式：使用模擬登入
        performMockSignIn()
        #else
        // 正式版：使用真正的 Google Sign-In
        performRealGoogleSignIn()
        #endif
        */
    }
    
    // MARK: - 模擬登入（開發用）
    private func performMockSignIn() {
        print("GoogleSignInManager: 使用模擬登入（開發模式）")
        
        // 模擬 Google 登入成功
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // 模擬 Google 用戶資料
            let userId = "google_user_\(Int.random(in: 1000...9999))"
            let email = "user@gmail.com"
            let name = "Google User"
            
            self.handleSignInSuccess(userId: userId, email: email, name: name)
        }
    }
    
    // MARK: - 真正的 Google Sign-In
    private func performRealGoogleSignIn() {
        print("GoogleSignInManager: 開始真正的 Google 登入流程")
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("GoogleSignInManager: 無法找到 root view controller")
            return
        }
        
        guard let clientID = getGoogleClientID() else {
            print("GoogleSignInManager: 無法獲取 Google Client ID")
            return
        }
        
        // 配置 Google Sign-In
        let configuration = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = configuration
        
        // 執行登入
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("GoogleSignInManager: Google 登入失敗: \(error.localizedDescription)")
                    return
                }
                
                guard let result = result else {
                    print("GoogleSignInManager: 無法獲取登入結果")
                    return
                }
                
                let user = result.user
                guard let profile = user.profile else {
                    print("GoogleSignInManager: 無法獲取用戶資料")
                    return
                }
                
                let userId = user.userID ?? "unknown_user"
                let email = profile.email
                let name = profile.name
                
                print("GoogleSignInManager: Google 登入成功！用戶: \(name ?? "Unknown"), Email: \(email)")
                self?.handleSignInSuccess(userId: userId, email: email, name: name)
            }
        }
    }
    
    // MARK: - 通用登入成功處理
    private func handleSignInSuccess(userId: String, email: String?, name: String?) {
        // Google登入成功後立即設置持久化狀態
        UserDefaults.standard.set(userId, forKey: "googleAuthorizedUserId")
        UserDefaults.standard.set(true, forKey: "hasPersistedLogin")
        print("GoogleSignInManager: Google登入成功，已設置持久化登入狀態")
        
        // 登入後立即查詢或建立使用者記錄
        self.handleUserRecord(userId: userId, email: email, name: name) { destination in
            DispatchQueue.main.async {
                // 利用通知傳送結果給 Login 頁面進行導向
                NotificationCenter.default.post(name: .didLogin, object: nil, userInfo: ["destination": destination])
            }
        }
    }
    
    // MARK: - Google 配置
    private func getGoogleClientID() -> String? {
        // 從 Google 配置文件讀取 CLIENT_ID
        if let path = Bundle.main.path(forResource: "client_221079984807-jac1p2o47ol60ba3mkngdnbktkqmhu2n.apps.googleusercontent.com", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let clientID = plist["CLIENT_ID"] as? String {
            print("GoogleSignInManager: 成功讀取 CLIENT_ID: \(clientID)")
            return clientID
        }
        
        // 備用方案：直接返回硬編碼的 CLIENT_ID
        let clientID = "221079984807-jac1p2o47ol60ba3mkngdnbktkqmhu2n.apps.googleusercontent.com"
        print("GoogleSignInManager: 使用硬編碼 CLIENT_ID: \(clientID)")
        return clientID
    }
    
    /// 登入後根據使用者記錄判斷：
    /// - 帳號存在：檢查 guidedInputCompleted 狀態（true → home，false → onboarding）
    /// - 帳號不存在：建立新記錄（預設 guidedInputCompleted 為 false）並導向 onboarding
    private func handleUserRecord(userId: String, email: String?, name: String?, completion: @escaping (_ destination: String) -> Void) {
        // 先確保 CloudKit 認證狀態正常
        let cloudKitService = CloudKitService.shared
        
        // 直接執行查詢，如果失敗就使用預設流程
        performUserRecordQuery(userId: userId, email: email, name: name, completion: completion)
    }
    
    /// 執行實際的用戶記錄查詢
    private func performUserRecordQuery(userId: String, email: String?, name: String?, completion: @escaping (_ destination: String) -> Void) {
        let privateDatabase = CKContainer(identifier: "iCloud.com.fcu.ToDolist1").privateCloudDatabase
        let predicate = NSPredicate(format: "providerUserID == %@ AND provider == %@", userId, "Google")
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
                    print("首次使用Google登入，創建新記錄並導向 onboarding")
                    self.createNewUserRecord(userId: userId, email: email, name: name, completion: completion)
                }
            case .failure(let error):
                print("查詢使用者記錄失敗: \(error.localizedDescription)")
                
                // 檢查是否是認證問題或帳戶不存在
                let nsError = error as NSError
                if nsError.domain == CKErrorDomain && nsError.code == CKError.notAuthenticated.rawValue ||
                   error.localizedDescription.contains("bad or missing auth token") {
                    print("GoogleSignInManager: CloudKit 認證問題，但Google登入成功，創建新帳戶")
                    // CloudKit認證問題時，直接創建新用戶記錄
                    self.createNewUserRecord(userId: userId, email: email, name: name, completion: completion)
                } else {
                    print("GoogleSignInManager: 其他錯誤(\(error.localizedDescription))，導向 onboarding")
                    // 其他錯誤也進入onboarding流程
                    completion("onboarding")
                }
            }
        }
    }
    
    /// 創建新用戶記錄
    private func createNewUserRecord(userId: String, email: String?, name: String?, completion: @escaping (_ destination: String) -> Void) {
        let privateDatabase = CKContainer(identifier: "iCloud.com.fcu.ToDolist1").privateCloudDatabase
        let newRecord = CKRecord(recordType: "ApiUser")  // 建立至預設 zone
        newRecord["provider"] = "Google" as CKRecordValue
        newRecord["providerUserID"] = userId as CKRecordValue
        newRecord["email"] = email as CKRecordValue?
        newRecord["name"] = name as CKRecordValue?
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
                    print("GoogleSignInManager: 創建用戶時認證問題，但Google登入已成功，繼續onboarding流程")
                    // 即使CloudKit創建失敗，由於Google登入成功，還是可以進入onboarding
                }
                
                // 不管CloudKit是否成功，都進入onboarding（因為Google登入已成功）
                print("GoogleSignInManager: 新用戶進入onboarding流程")
                completion("onboarding")
            } else {
                print("GoogleSignInManager: 成功創建新用戶記錄，進入onboarding")
                completion("onboarding")
            }
        }
        print("save done")
    }
}