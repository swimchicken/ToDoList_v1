import Foundation
import AuthenticationServices
import SwiftUI

class AppleSignInManager: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    static let shared = AppleSignInManager()
    private let apiDataManager = APIDataManager.shared
    
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
            guard let identityToken = appleIDCredential.identityToken,
                  let identityTokenString = String(data: identityToken, encoding: .utf8) else {
                print("AppleSignInManager: 無法獲取 identity token")
                return
            }

            let email = appleIDCredential.email
            let fullName = appleIDCredential.fullName
            let name = formatFullName(fullName)

            print("AppleSignInManager: 開始API登入流程")

            // 使用API進行Apple登入
            Task {
                do {
                    let authResponse = try await apiDataManager.loginWithApple(
                        identityToken: identityTokenString,
                        name: name
                    )

                    await MainActor.run {
                        print("AppleSignInManager: API登入成功，用戶: \(authResponse.user.name ?? "Unknown")")

                        // 儲存用戶信息
                        UserDefaults.standard.set(appleIDCredential.user, forKey: "appleAuthorizedUserId")
                        UserDefaults.standard.set(true, forKey: "hasPersistedLogin")

                        // 判斷導向位置：新用戶進入引導，舊用戶進入主頁
                        let destination = authResponse.user.isNewUser == true ? "onboarding" : "home"

                        // 發送登入成功通知
                        NotificationCenter.default.post(
                            name: .didLogin,
                            object: nil,
                            userInfo: ["destination": destination]
                        )
                    }
                } catch {
                    await MainActor.run {
                        print("AppleSignInManager: API登入失敗: \(error.localizedDescription)")
                        // 登入失敗時可以顯示錯誤訊息給用戶
                    }
                }
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Apple 登入失敗: \(error.localizedDescription)")
    }

    // MARK: - Helper Methods

    private func formatFullName(_ fullName: PersonNameComponents?) -> String? {
        guard let fullName = fullName else { return nil }
        let formatter = PersonNameComponentsFormatter()
        return formatter.string(from: fullName)
    }
}

