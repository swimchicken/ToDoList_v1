# Widget 調試步驟

## 問題：Widget 顯示「請在應用中添加今日任務」

### 1. 確認兩邊的 App Group ID 完全一致

主應用使用：`group.com.fcu.ToDolist`
Widget 也必須使用：`group.com.fcu.ToDolist`

注意大小寫必須完全一致！

### 2. 完整的配置檢查清單

#### 主應用 (ToDoList_v1):
- [ ] Signing & Capabilities 中有 App Groups
- [ ] App Group ID: `group.com.fcu.ToDolist`
- [ ] 已勾選該 App Group

#### Widget Extension (ToDoListWidgetExtension):
- [ ] Signing & Capabilities 中有 App Groups
- [ ] App Group ID: `group.com.fcu.ToDolist`
- [ ] 已勾選該 App Group
- [ ] Bundle ID: `com.fcu.ToDolist.ToDoListWidget`

### 3. 清理並重建

1. 關閉 Xcode
2. 刪除 DerivedData:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/ToDoList_v1-*
   ```
3. 重新打開 Xcode
4. Clean Build Folder (Shift + Command + K)
5. 重新編譯

### 4. 測試步驟

1. 運行主應用
2. 確認控制台顯示數據已保存
3. 切換到 Widget scheme
4. 運行 Widget Extension
5. 查看 Widget 的控制台輸出

### 5. 常見錯誤

- App Group ID 大小寫不一致
- Widget Extension 沒有添加 App Groups capability
- 使用了錯誤的 Bundle ID
- 開發團隊不一致