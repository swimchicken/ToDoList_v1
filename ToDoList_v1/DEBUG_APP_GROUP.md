# App Group 調試信息

## 問題診斷

Widget 能訪問 App Group，但只看到系統 keys，沒有我們的數據。

## 可能的原因

1. **App Group ID 不一致**
   - 主應用使用: `group.com.fcu.ToDolist`
   - Widget 可能使用了不同的 ID

2. **App Group 沒有正確創建**
   - 可能只是添加了 capability，但沒有實際創建 App Group

## 解決步驟

### 1. 檢查 Entitlements 文件

查看以下文件內容：
- `MyProject.entitlements`
- `ToDoListWidgetExtension.entitlements`

確保兩個文件都包含：
```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.fcu.ToDolist</string>
</array>
```

### 2. 在 Xcode 中重新配置

1. **刪除現有的 App Groups**
   - 選擇主應用 target
   - Signing & Capabilities
   - 點擊 App Groups 旁邊的 "x" 刪除
   - 對 Widget Extension 做同樣的操作

2. **重新添加 App Groups**
   - 選擇主應用 target
   - 點擊 "+ Capability"
   - 添加 "App Groups"
   - 點擊 "+" 創建新的 group
   - 輸入: `group.com.fcu.ToDolist`
   - 確保已勾選

3. **為 Widget Extension 添加相同的 App Group**
   - 選擇 Widget Extension target
   - 點擊 "+ Capability"
   - 添加 "App Groups"
   - 勾選已存在的: `group.com.fcu.ToDolist`

### 3. 清理並重建

```bash
# 關閉 Xcode
# 刪除 DerivedData
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# 刪除應用
# 在模擬器/設備上刪除應用

# 重新打開 Xcode
# Clean Build Folder (Shift + Command + K)
# 重新編譯運行
```

### 4. 驗證步驟

1. 運行主應用，確認數據保存成功
2. 運行 Widget Extension，查看是否能找到數據
3. 如果還是不行，可能需要檢查開發者賬號的 App Group 配置