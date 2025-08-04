# 啟用 Widget 互動功能

Widget 現在支援點擊圓圈來完成/取消完成任務！

## 需要在 Xcode 中完成的步驟：

### 1. 將必要的文件添加到 Widget Extension Target

在 Xcode 中，將以下文件添加到 `ToDoListWidgetExtension` target：

1. **LocalDataManager.swift**
   - 在導航器中找到此文件
   - 在右側檢查器中勾選 "ToDoListWidgetExtension"

2. **WidgetDataManager.swift**
   - 同樣勾選 "ToDoListWidgetExtension"

### 2. 確認 iOS 版本要求

確保 Widget Extension 的最低部署版本設為 iOS 17.0 或更高：
- 選擇 ToDoListWidgetExtension target
- 在 General 標籤中，將 Minimum Deployments 設為 iOS 17.0

### 3. 測試互動功能

1. 清理並重新構建項目（Cmd+Shift+K，然後 Cmd+B）
2. 在模擬器或真機上運行
3. 添加大型 Widget 到主畫面
4. 點擊任務旁邊的圓圈來切換完成狀態

## 功能說明

- **只有大型 Widget** 支援互動功能（小型和中型太小，不適合互動）
- 點擊圓圈會：
  - 切換任務的完成狀態
  - 自動保存到本地數據
  - 刷新 Widget 顯示
  - 同步到主應用

## 可選：為中型 Widget 也添加互動

如果你也想讓中型 Widget 支援互動，可以修改 `MediumTaskRowView` 中的圓圈部分，使用相同的 Button 包裝方式。

## 故障排除

如果互動功能不工作：

1. 確認 iOS 版本是 17.0 或更高
2. 確認所有必要文件都已添加到 Widget Extension target
3. 重新安裝應用和 Widget
4. 檢查控制台日誌是否有錯誤信息