# Google Sign-In 設定指南

## 1. 添加 Google Sign-In SDK

### 使用 Swift Package Manager：
1. 在 Xcode 中打開專案
2. 選擇 **File** → **Add Package Dependencies**
3. 輸入 URL: `https://github.com/google/GoogleSignIn-iOS`
4. 選擇最新版本並添加到專案

### 或者使用 CocoaPods：
在 `Podfile` 中添加：
```ruby
pod 'GoogleSignIn'
```
然後執行 `pod install`

## 2. 設定 Google Cloud Console

1. 前往 [Google Cloud Console](https://console.cloud.google.com/)
2. 創建新專案或選擇現有專案
3. 啟用 **Google Sign-In API**
4. 前往 **APIs & Services** → **Credentials**
5. 點擊 **Create Credentials** → **OAuth 2.0 Client IDs**
6. 選擇 **iOS** 應用程式類型
7. 輸入你的 Bundle ID: `com.fcu.ToDolist`
8. 下載 `GoogleService-Info.plist` 文件

## 3. 添加配置文件

1. 將下載的 `GoogleService-Info.plist` 文件拖拽到 Xcode 專案中
2. 確保文件被添加到 **ToDoList_v1** target
3. 確保 **Copy items if needed** 被勾選

## 4. 更新 Info.plist

在 `ToDoList-v1-Info.plist` 中添加 URL Scheme：

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.fcu.ToDolist</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <!-- 替換為你的 REVERSED_CLIENT_ID -->
            <string>com.googleusercontent.apps.YOUR_REVERSED_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

## 5. 更新代碼

### 在 `ToDoList_v1App.swift` 中：
取消註解以下行：
```swift
import GoogleSignIn
```

在 `handleURL` 函數中取消註解：
```swift
if GIDSignIn.sharedInstance.handle(url) {
    return
}
```

### 在 `GoogleSignInManager.swift` 中：
取消註解以下行：
```swift
import GoogleSignIn
```

在 `performRealGoogleSignIn()` 函數中取消註解真正的 Google Sign-In 代碼。

## 6. 測試

1. 確保專案可以編譯
2. 在模擬器或真機上測試 Google 登入
3. 檢查控制台輸出確認登入流程

## 7. 常見問題

### 錯誤：「No such module 'GoogleSignIn'」
- 確保 Swift Package Manager 依賴已正確添加
- 清理專案並重新編譯

### 錯誤：「The operation couldn't be completed」
- 檢查 Bundle ID 是否與 Google Cloud Console 中設定的一致
- 確保 `GoogleService-Info.plist` 文件已正確添加到專案

### 登入後沒有反應
- 檢查 URL Scheme 是否正確設定
- 確保 `onOpenURL` 處理器已正確實作

## 8. 安全提醒

- 不要將 `GoogleService-Info.plist` 提交到公開的版本控制系統
- 在 `.gitignore` 中添加：
```
GoogleService-Info.plist
```

## 完成後

當所有設定完成後，Google 登入按鈕將會顯示真正的 Google 登入界面，而不是直接跳到輸入名字的頁面。