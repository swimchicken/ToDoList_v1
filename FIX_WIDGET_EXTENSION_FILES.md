# 修復 Widget Extension 編譯錯誤

## 需要添加到 Widget Extension Target 的文件

在 Xcode 中，你需要將以下文件添加到 `ToDoListWidgetExtension` target：

### 必須添加的文件：

1. **TodoStatus.swift** ✅ (已經添加)
2. **TodoItem.swift** ✅ (已經添加)
3. **LocalDataManager.swift** ❌ (需要添加)
4. **WidgetDataManager.swift** ❌ (需要添加)

### 如何添加文件到 Widget Extension：

1. 在 Xcode 的項目導航器中找到需要的文件
2. 選中文件
3. 在右側的文件檢查器中，找到 "Target Membership" 部分
4. 勾選 "ToDoListWidgetExtension" 旁邊的複選框

### 添加順序建議：

1. 先添加 `WidgetDataManager.swift`
2. 再添加 `LocalDataManager.swift`

### 注意事項：

- 如果 `LocalDataManager.swift` 依賴其他文件（如 CloudKit 相關），你可能需要：
  - 將這些依賴也添加到 Widget Extension，或
  - 在 `LocalDataManager.swift` 中使用條件編譯來排除 Widget 不需要的功能

### 條件編譯示例（如果需要）：

```swift
#if !WIDGET_EXTENSION
// CloudKit 相關代碼
#endif
```

### 驗證步驟：

1. 添加所有必要文件後
2. 清理構建文件夾（Cmd+Shift+K）
3. 重新構建項目（Cmd+B）
4. 確認沒有編譯錯誤

### 如果還有其他依賴錯誤：

查看錯誤信息，並將相關的模型文件也添加到 Widget Extension target。