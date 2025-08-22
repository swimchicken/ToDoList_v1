# 強制更新 Widget 的方法

由於 Widget 無法立即看到主應用保存的數據，請嘗試以下方法：

## 方法 1：手動刷新 Widget
1. 長按 Widget
2. 選擇「編輯小組件」
3. 點擊「完成」

## 方法 2：重新添加 Widget
1. 長按並刪除現有的 Widget
2. 重新添加 Widget
3. 選擇適合的大小

## 方法 3：重啟手機/模擬器
有時候 App Groups 的數據同步需要重啟才能正常工作

## 方法 4：使用 Widget 的 Intent Configuration
如果以上方法都不行，可能需要：
1. 為 Widget 添加 Configuration Intent
2. 讓用戶可以手動選擇要顯示的內容

## 臨時解決方案
目前 Widget 會顯示「請在主應用中添加今日任務」的提示信息，這表示 Widget 本身是正常運行的。

數據同步的問題可能與以下因素有關：
- iOS 版本
- 開發者賬號配置
- App Groups 的系統級緩存