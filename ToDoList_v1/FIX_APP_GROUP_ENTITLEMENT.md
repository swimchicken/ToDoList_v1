# 修復 App Group Entitlement 錯誤

錯誤信息：`container_create_or_lookup_app_group_path_by_app_group_identifier: client is not entitled`

這表示 Widget Extension 沒有正確的 App Groups 權限。

## 解決步驟：

### 1. 檢查 Widget Extension 的 Capabilities

1. **選擇 `ToDoListWidgetExtension` target**
2. **進入 "Signing & Capabilities" 標籤**
3. **確認有 "App Groups" capability**
4. **如果沒有，點擊 "+ Capability" 添加**
5. **確保勾選了 `group.com.fcu.ToDolist`**

### 2. 檢查 Entitlements 文件

確保 Widget Extension 有對應的 entitlements 文件，並包含：

```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.fcu.ToDolist</string>
</array>
```

### 3. 檢查 Build Settings

1. 選擇 `ToDoListWidgetExtension` target
2. 進入 "Build Settings"
3. 搜索 "entitlements"
4. 確認 "Code Signing Entitlements" 指向正確的文件：
   - Debug: 應該有對應的 entitlements 文件
   - Release: `ToDoListWidgetExtensionRelease.entitlements`

### 4. 確認開發團隊一致

1. 主應用和 Widget Extension 必須使用相同的開發團隊
2. 在 "Signing & Capabilities" 中檢查 Team 設置

### 5. 如果還是不行

1. 刪除 Widget Extension target
2. 重新添加 Widget Extension
3. 立即配置 App Groups
4. 確保 Bundle ID 格式正確：
   - 主應用: `com.fcu.ToDolist`
   - Widget: `com.fcu.ToDolist.ToDoListWidget`

### 6. 清理並重建

```bash
# 1. 關閉 Xcode
# 2. 清理 DerivedData
rm -rf ~/Library/Developer/Xcode/DerivedData/*
# 3. 重新打開項目
# 4. Clean Build Folder
# 5. 重新編譯
```

### 7. 驗證 App Groups 在開發者賬號中存在

如果使用付費開發者賬號：
1. 登錄 Apple Developer Portal
2. 進入 Identifiers → App Groups
3. 確認 `group.com.fcu.ToDolist` 存在
4. 確認應用的 App ID 已關聯此 App Group