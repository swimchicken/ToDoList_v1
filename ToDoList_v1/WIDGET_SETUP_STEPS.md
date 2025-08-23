# Widget 設置步驟

## 1. 創建 Widget Extension

在 Xcode 中：
1. 選擇項目文件 (ToDoList_v1.xcodeproj)
2. 點擊 "+" 按鈕添加新 Target
3. 選擇 "Widget Extension"
4. 設置如下：
   - Product Name: `ToDoListWidget`
   - Team: 選擇你的開發團隊
   - Bundle Identifier: `com.fcu.ToDolist.ToDoListWidget`
   - Include Configuration Intent: 取消勾選（我們不需要）
   - Project: ToDoList_v1
   - Embed in Application: ToDoList_v1

## 2. 配置 App Groups

### 主應用 (ToDoList_v1)：
1. 選擇 ToDoList_v1 target
2. 進入 "Signing & Capabilities"
3. 點擊 "+ Capability"
4. 添加 "App Groups"
5. 點擊 "+" 創建新的 App Group
6. 命名為: `group.com.fcu.ToDolist`

### Widget Extension (ToDoListWidget)：
1. 選擇 ToDoListWidget target
2. 進入 "Signing & Capabilities"
3. 點擊 "+ Capability"
4. 添加 "App Groups"
5. 勾選相同的 App Group: `group.com.fcu.ToDolist`

## 3. 添加必要文件到 Widget Target

需要將以下文件添加到 Widget Extension target：
- `model/TodoItem.swift`
- `model/TodoStatus.swift`

在文件檢查器中勾選 "ToDoListWidget" target。

## 4. 注意事項

- 確保 Bundle ID 正確：
  - 主應用: `com.fcu.ToDolist`
  - Widget: `com.fcu.ToDolist.ToDoListWidget`
- App Group ID 必須一致: `group.com.fcu.ToDolist`
- Widget 和主應用必須使用相同的開發團隊