# 檢查 App Groups 配置

## 1. 確認 App Groups 已正確配置

### 主應用 (ToDoList_v1):
1. 選擇 `ToDoList_v1` target
2. 進入 "Signing & Capabilities"
3. 檢查是否有 "App Groups" capability
4. 確認 App Group ID 是: `group.com.fcu.ToDolist`

### Widget Extension (ToDoListWidgetExtension):
1. 選擇 `ToDoListWidgetExtension` target
2. 進入 "Signing & Capabilities"
3. 檢查是否有 "App Groups" capability
4. 確認 App Group ID 是: `group.com.fcu.ToDolist`

## 2. 如果沒有 App Groups

如果還沒有添加 App Groups，請按照以下步驟：

1. 點擊 "+ Capability"
2. 搜索並選擇 "App Groups"
3. 點擊 "+" 按鈕創建新的 App Group
4. 輸入: `group.com.fcu.ToDolist`
5. 確保兩個 targets 都使用相同的 App Group ID

## 3. 測試 Widget 數據

1. 運行應用
2. 點擊「測試 Widget 數據」按鈕
3. 查看 Xcode 控制台輸出
4. 應該看到:
   - ✅ App Group 配置正確
   - ✅ Widget 數據已保存
   - ✅ 成功解碼 X 個任務

## 4. 常見問題

### 問題: "無法訪問 App Group"
- 確保 App Group ID 完全相同
- 確保已經正確配置 capabilities
- 嘗試清理構建文件夾 (Shift + Command + K)

### 問題: "沒有找到數據"
- 確保主應用已經保存了今日任務
- 使用測試按鈕創建測試數據
- 檢查日期過濾邏輯是否正確

### 問題: "解碼失敗"
- 確保 TodoItem 和 TodoStatus 文件在兩個 targets 中都有
- 確保編解碼策略一致（特別是日期格式）