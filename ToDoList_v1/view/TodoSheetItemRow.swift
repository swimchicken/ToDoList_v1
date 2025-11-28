// MARK: - TodoSheetItemRow.swift
import SwiftUI
import Foundation

struct TodoSheetItemRow: View {
    @Binding var item: TodoItem
    private let doneColor = Color(red: 0, green: 0.72, blue: 0.41)
    private let iconSize: CGFloat = 16

    // 新增：處理將項目添加到首頁的回調
    var onAddToHome: ((TodoItem) -> Void)? = nil

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
                    // 創建一個新的副本
                    var homeItem = item

                    // 賦予選擇的日期而非當前時間
                    homeItem.taskDate = selectedDate
                    
                    // 如果之前是備忘錄（待辦佇列），更改狀態為 toBeStarted
                    if homeItem.status == .toDoList {
                        homeItem.status = .toBeStarted
                    }
                    
                    // 使用 API 添加到首頁事件
                    Task {
                        do {
                            let addedItem = try await APIDataManager.shared.addTodoItem(homeItem)
                            await MainActor.run {
                                // 發送通知以刷新首頁
                                NotificationCenter.default.post(
                                    name: Notification.Name("TodoItemsDataRefreshed"),
                                    object: nil
                                )

                                // 如果有回調，傳遞新項目
                                if let onAddToHome = onAddToHome {
                                    onAddToHome(homeItem)
                                }
                            }
                        } catch {
                            // 錯誤記錄到控制台
                            print("添加失敗: \(error.localizedDescription)")
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

    // 切換任務狀態 - 在TodoSheet中使用直接API調用
    private func toggleTaskStatus() {
        let originalStatus = item.status
        let newStatus: TodoStatus = (item.status == .completed ? .toBeStarted : .completed)

        // 立即更新本地狀態提供即時反饋
        withAnimation(.easeInOut(duration: 0.2)) {
            item.status = newStatus
        }

        // 創建更新後的任務
        var updatedTask = item
        updatedTask.status = newStatus

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
                    }
                }
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
