// MARK: - TodoSheetItemRow.swift
import SwiftUI
import Foundation

struct TodoSheetItemRow: View {
    @Binding var item: TodoItem
    private let doneColor = Color(red: 0, green: 0.72, blue: 0.41)
    private let iconSize: CGFloat = 16

    // 新增：處理將項目添加到首頁的回調
    var onAddToHome: ((TodoItem) -> Void)? = nil

    // 新增：立即關閉彈窗的回調
    var onDismissSheet: (() -> Void)? = nil

    // 新增：樂觀更新回調，立即在 UI 中顯示新任務
    var onOptimisticUpdate: ((TodoItem) -> Void)? = nil

    // 新增：替換樂觀更新項目的回調
    var onReplaceOptimisticItem: ((UUID, TodoItem) -> Void)? = nil

    // 新增：刷新待辦佇列的回調（當備忘錄狀態改變時）
    var onRefreshQueue: (() -> Void)? = nil

    // 新增：當前選擇的日期（從 Home 傳遞過來）
    var selectedDate: Date = Date()
    
    var body: some View {
        ZStack {
            // 完成狀態下的橫跨整行的刪除線
            if item.status == .completed {
                Rectangle()
                    .fill(doneColor)
                    .frame(height: 2)
                    .offset(y: 0)
            }
            
            HStack(spacing: 12) {
                // 矩形按鈕 (點擊前灰色，點擊後綠色)
                Button {
                    toggleTaskStatus()
                } label: {
                    Rectangle()
                        .foregroundColor(.clear)
                        .frame(width: 28, height: 28)
                        .background(item.status == .completed ? doneColor : .white.opacity(0.15))
                        .cornerRadius(40.5)
                }
                .buttonStyle(PlainButtonStyle())
                
                // 任務標題 (不再需要單獨的刪除線)
                Text(item.title)
                    .font(.system(size: 16))
                    .foregroundColor(item.status == .completed ? doneColor : .white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Spacer()
                
                // 星標（如果優先度>=1）
                if item.priority >= 1 {
                    HStack(spacing: 2) {
                        ForEach(0..<item.priority, id: \.self) { _ in
                            Image("Star")
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: iconSize, height: iconSize)
                                .foregroundColor(item.status == .completed ? doneColor : .white.opacity(0.7))
                        }
                    }
                    .padding(.trailing, 8)
                }
                
                // 右側箭頭按鈕 - 添加到首頁並賦予選擇的日期
                Button {
                    // 創建一個新的副本用於添加到日程
                    var homeItem = item

                    // 賦予選擇的日期而非當前時間
                    homeItem.taskDate = selectedDate

                    // 更新任務類型和狀態
                    homeItem.taskType = .scheduled
                    homeItem.completionStatus = .pending
                    homeItem.status = .toBeStarted

                    // 生成新的 ID，避免與原始備忘錄 ID 衝突
                    homeItem.id = UUID()

                    // 立即樂觀更新：在 Home.swift 中顯示新任務
                    onOptimisticUpdate?(homeItem)

                    // 立即關閉彈窗，提供即時反饋
                    onDismissSheet?()

                    // 使用 API 添加到首頁事件
                    Task {
                        do {
                            // 第一步：添加到日程
                            let addedItem = try await APIDataManager.shared.addTodoItem(homeItem)
                            print("🚀 成功添加到日程: \(homeItem.title)")

                            // 第二步：更新原始備忘錄狀態 - 使用備忘錄的服務器 ID
                            var updatedMemo = item
                            updatedMemo.completionStatus = .completed
                            updatedMemo.status = .completed

                            // 💡 關鍵：確保備忘錄項目有有效的服務器 ID 才進行更新
                            // 如果備忘錄是通過 Add.swift 創建的，它應該已經有服務器 ID
                            let _ = try await APIDataManager.shared.updateTodoItem(updatedMemo)
                            print("✅ 成功更新原始備忘錄狀態: \(item.title)")

                            await MainActor.run {
                                // 更新本地狀態
                                print("🔍 [TodoSheetItemRow] 更新前 - \(item.title): completionStatus=\(item.completionStatus), status=\(item.status)")

                                item.completionStatus = .completed
                                item.status = .completed

                                print("🔍 [TodoSheetItemRow] 更新後 - \(item.title): completionStatus=\(item.completionStatus), status=\(item.status)")

                                // 🔧 直接替換樂觀更新項目，不使用通知機制
                                // 這樣可以避免通知時序問題和重複更新
                                onReplaceOptimisticItem?(homeItem.id, addedItem)
                                print("✅ 直接替換樂觀更新項目為真實項目: \(addedItem.title)")

                                // 🆕 刷新待辦佇列，讓已完成的備忘錄從列表中消失
                                print("🔍 [TodoSheetItemRow] 準備調用 onRefreshQueue")
                                onRefreshQueue?()
                                print("🔄 刷新待辦佇列 - 移除已完成的備忘錄: \(item.title)")

                                // 🔧 移除 onAddToHome 調用，避免重複操作
                                // onAddToHome 可能會導致額外的 UI 更新
                            }
                        } catch {
                            // 🔍 詳細錯誤分析
                            print("❌ 操作失敗: \(error.localizedDescription)")

                            if let urlError = error as? URLError, urlError.code == .badURL {
                                print("🔍 可能是 URL 格式問題")
                            } else if error.localizedDescription.contains("404") {
                                print("🔍 備忘錄項目可能未同步到服務器，ID: \(item.id)")
                                print("🔍 這可能是因為該備忘錄項目還沒有完成 API 同步")
                            }

                            await MainActor.run {
                                // 🔧 直接通過回調移除失敗的樂觀更新項目
                                // 簡單的做法：用 nil 替換表示移除
                                if let onReplaceOptimisticItem = onReplaceOptimisticItem {
                                    // 傳遞一個特殊的空項目表示移除
                                    let emptyItem = TodoItem(
                                        id: UUID(),
                                        userID: "",
                                        title: "",
                                        priority: -1,
                                        isPinned: false,
                                        taskDate: nil,
                                        note: "",
                                        taskType: .memo,
                                        completionStatus: .pending,
                                        status: .toBeStarted,
                                        createdAt: Date(),
                                        updatedAt: Date(),
                                        correspondingImageID: "REMOVE"
                                    )
                                    onReplaceOptimisticItem(homeItem.id, emptyItem)
                                }
                                print("🔄 回滾失敗的樂觀更新項目")
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.turn.right.up")
                        .font(.system(size: 14))
                        .foregroundColor(item.status == .completed ? doneColor : .white.opacity(0.5))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .background(Color.clear)
    }

    // 🔄 防重複更新的狀態
    @State private var isUpdating = false

    // 切換任務狀態 - 在TodoSheet中使用直接API調用
    private func toggleTaskStatus() {
        // 🛡️ 防止重複點擊
        guard !isUpdating else {
            print("⚠️ TodoSheetItemRow 任務更新中，忽略重複操作: \(item.title)")
            return
        }

        let originalStatus = item.status
        let originalCompletionStatus = item.completionStatus
        let newStatus: TodoStatus = (item.status == .completed ? .toBeStarted : .completed)
        let newCompletionStatus: CompletionStatus = (item.completionStatus == .completed ? .pending : .completed) // 🆕 更新新字段

        // 🔒 設定更新中狀態
        isUpdating = true

        // 立即更新本地狀態提供即時反饋
        withAnimation(.easeInOut(duration: 0.2)) {
            item.status = newStatus
            item.completionStatus = newCompletionStatus // 🆕 同時更新新字段
        }

        // 創建更新後的任務
        var updatedTask = item
        updatedTask.status = newStatus
        updatedTask.completionStatus = newCompletionStatus // 🆕 確保新字段也被更新

        // 直接調用API更新，不使用批次更新
        Task {
            do {
                let _ = try await APIDataManager.shared.updateTodoItem(updatedTask)
                print("✅ TodoSheetItemRow - 任務狀態更新成功: \(item.title)")

                // 發送狀態變更通知
                NotificationCenter.default.post(
                    name: Notification.Name("TodoItemStatusChanged"),
                    object: nil,
                    userInfo: ["itemId": item.id.uuidString]
                )
            } catch {
                await MainActor.run {
                    print("❌ TodoSheetItemRow - 任務狀態更新失敗: \(error.localizedDescription)")
                    // 回滾到原來的狀態
                    withAnimation(.easeInOut(duration: 0.2)) {
                        item.status = originalStatus
                        item.completionStatus = originalCompletionStatus // 🆕 同時回滾新字段
                    }
                }
            }

            // 🔓 無論成功或失敗都要解除更新中狀態
            await MainActor.run {
                isUpdating = false
            }
        }
    }
}

struct TodoSheetItemRow_Previews: PreviewProvider {
    @State static var todoItem1 = TodoItem(
        id: UUID(), userID: "user123",
        title: "回覆所有未讀郵件",
        priority: 2,
        isPinned: false,
        taskDate: Date(),
        note: "備註",
        taskType: .scheduled,
        completionStatus: .pending,
        status: TodoStatus.toBeStarted, // 明確指定枚舉類型
        createdAt: Date(),
        updatedAt: Date(),
        correspondingImageID: ""
    )
    
    @State static var todoItem2 = TodoItem(
        id: UUID(), userID: "user123",
        title: "完成任務",
        priority: 3,
        isPinned: false,
        taskDate: Date(),
        note: "備註",
        taskType: .scheduled,
        completionStatus: .completed,
        status: TodoStatus.completed, // 明確指定枚舉類型
        createdAt: Date(),
        updatedAt: Date(),
        correspondingImageID: ""
    )
    
    static var previews: some View {
        VStack(spacing: 0) {
            TodoSheetItemRow(item: $todoItem1)
            Divider().background(Color.white.opacity(0.1))
            TodoSheetItemRow(item: $todoItem2)
        }
        .background(Color(red: 0.15, green: 0.15, blue: 0.15))
        .previewLayout(.sizeThatFits)
    }
}
