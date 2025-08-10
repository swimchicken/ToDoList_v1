# 修復 Code Signing Certificate 錯誤

錯誤信息：`Embedded binary is not signed with the same certificate as the parent app`

這表示 Widget Extension 和主應用使用了不同的簽名證書。

## 解決步驟：

### 1. 檢查並統一開發團隊

1. **選擇主應用 Target (ToDoList_v1)**
   - 進入 "Signing & Capabilities" 標籤
   - 記下 "Team" 欄位的值

2. **選擇 Widget Extension Target (ToDoListWidgetExtension)**
   - 進入 "Signing & Capabilities" 標籤
   - 確保 "Team" 欄位與主應用相同
   - 如果不同，從下拉選單中選擇相同的團隊

### 2. 檢查 Bundle Identifier

確保 Widget Extension 的 Bundle ID 是主應用的子集：
- 主應用: `com.fcu.ToDolist`
- Widget Extension: `com.fcu.ToDolist.ToDoListWidget`

### 3. 檢查 Provisioning Profile

1. **自動管理（推薦）**
   - 兩個 targets 都勾選 "Automatically manage signing"
   - Xcode 會自動處理 provisioning profiles

2. **手動管理**
   - 確保兩個 targets 使用相同開發者賬號的 profiles

### 4. 清理並重建

```bash
# 1. 清理構建
Command + Shift + K

# 2. 清理構建文件夾
Command + Option + Shift + K

# 3. 重啟 Xcode

# 4. 重新構建
Command + B
```

### 5. 如果還是不行

1. **刪除舊的 Provisioning Profiles**
   ```bash
   cd ~/Library/MobileDevice/Provisioning\ Profiles/
   rm -rf *
   ```

2. **在 Xcode 中重新下載**
   - Xcode → Preferences → Accounts
   - 選擇你的 Apple ID
   - 點擊 "Download Manual Profiles"

3. **檢查 Keychain**
   - 打開 Keychain Access
   - 搜索你的開發者證書
   - 確保沒有重複或過期的證書

### 6. 驗證設置

在兩個 targets 的 Build Settings 中搜索並檢查：
- `CODE_SIGN_IDENTITY`: 應該相同或都設為 "Apple Development"
- `DEVELOPMENT_TEAM`: 必須相同
- `PROVISIONING_PROFILE_SPECIFIER`: 如果手動管理，確保兼容

### 7. 常見問題

**問題：使用個人免費開發者賬號**
- 免費賬號可能無法使用某些功能
- 建議使用付費開發者賬號

**問題：多個開發者證書**
- 在 Keychain 中刪除重複或過期的證書
- 只保留最新的有效證書