import SwiftUI

struct ItemRow: View {
    @Binding var item: TodoItem  // 綁定，才能修改

    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX") // 使用固定格式，避免受地區影響
        f.dateFormat = "HH:mm"
        return f
    }()

    private let doneColor = Color.green
    private let starAreaWidth: CGFloat = 50 // 星星區固定寬度
    private let iconSize: CGFloat = 16      // 統一圖標大小

    var body: some View {
        ZStack {
            Color.clear

            HStack(spacing: 12) {
                // 1. 圓圈按鈕：永遠靠左
                Button {
                    withAnimation {
                        // 更新狀態
                        item.status = (item.status == .completed ? .toBeStarted : .completed)
                        
                        // 使用 DataSyncManager 更新項目 - 它會先更新本地然後同步到雲端
                        DataSyncManager.shared.updateTodoItem(item) { result in
                            switch result {
                            case .success(_):
                                print("ItemRow - 成功更新待辦事項到本地和雲端")
                            case .failure(let error):
                                print("ItemRow - 更新待辦事項失敗: \(error.localizedDescription)")
                            }
                        }
                        
                        // 發送狀態變更通知，附帶項目ID
                        NotificationCenter.default.post(
                            name: Notification.Name("TodoItemStatusChanged"),
                            object: nil,
                            userInfo: ["itemId": item.id.uuidString]
                        )
                        
                        print("ItemRow - 項目狀態已變更: ID=\(item.id), 標題=\(item.title), 新狀態=\(item.status.rawValue)")
                    }
                } label: {
                    Circle()
                        .fill(item.status == .completed ? doneColor : Color.white.opacity(0.15))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(PlainButtonStyle())

                // 2. 標題：設定最大寬度為無限大，使其填滿可用空間，並靠左對齊
                Text(item.title)
                    .font(.body)
                    .lineLimit(1)             // 最多顯示一行
                    .truncationMode(.tail)    // 過長時結尾顯示 ...
                    .foregroundColor(item.status == .completed ? doneColor : .white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 3. 置頂圖標或星星：嚴格控制位置和大小
                HStack(spacing: 0) {
                    // 完全統一處理Pin圖標和星星圖標
                    if item.isPinned {
                        // Pin圖標固定位置
                        Image("Pin")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: iconSize, height: iconSize)
                            .foregroundColor(item.status == .completed ? doneColor : .white)
                    } else if item.priority > 0 {
                        // 星星圖標 - 固定從左側開始
                        ForEach(0..<max(0, item.priority), id: \.self) { index in
                            Image("Star")
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: iconSize, height: iconSize)
                                .foregroundColor(item.status == .completed ? doneColor : .white)
                                .padding(.leading, index > 0 ? 2 : 0) // 星星之間的間距
                        }
                    }
                    Spacer() // 確保圖標都靠左對齊
                }
                .frame(width: starAreaWidth, alignment: .leading)
                .background(Color.clear) // 用於調試布局的顏色，可以移除

                // 4. 時間：固定大小，最右
                if let taskDate = item.taskDate {
                    Text("\(taskDate, formatter: ItemRow.timeFormatter)")
                        .font(.subheadline)
                        .fixedSize(horizontal: true, vertical: false) // 確保時間寬度固定
                        .foregroundColor(item.status == .completed ? doneColor : .white)
                } else {
                    // 如果沒有時間（nil），顯示空白占位符
                    Text("--:--")
                        .font(.subheadline)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundColor(.gray.opacity(0.7))
                }
            }
            .padding(.vertical, 13) // 增加垂直內距使內容更舒適
            .padding(.horizontal, 2) // 微調水平內距
            .frame(height: 52)
            .background(item.isPinned ? Color(red: 0.09, green: 0, blue: 0) : Color.clear)
            .cornerRadius(item.isPinned ? 15 : 0)

            // 刪除線：整列覆蓋 (如果需要)
            .overlay(
                Group {
                    if item.status == .completed {
                        Rectangle()
                            .fill(doneColor) // 使用完成顏色
                            .frame(height: 1.5) // 調整線條粗細
                            .padding(.horizontal, 2) // 微調線條左右邊距
                    }
                },
                alignment: .center
            )
        }
        .frame(height: 52) // 固定行高
    }
}

// --- Preview 程式碼，保持不變 ---
struct ItemRow_Previews: PreviewProvider {
    @State static var todo1 = TodoItem(
        id: UUID(), userID: "u",
        title: "未完成事件，這是一個比較長的標題來測試對齊", priority: 2, isPinned: false,
        taskDate: Date(), note: "", status: .toBeStarted,
        createdAt: Date(), updatedAt: Date(), correspondingImageID: ""
    )
    @State static var todo2 = TodoItem(
        id: UUID(), userID: "u",
        title: "已完成範例", priority: 1, isPinned: false,
        taskDate: Date().addingTimeInterval(3600), note: "", status: .completed,
        createdAt: Date(), updatedAt: Date(), correspondingImageID: ""
    )
    @State static var todo3 = TodoItem(
        id: UUID(), userID: "u",
        title: "置頂項目示例", priority: 3, isPinned: true,
        taskDate: Date().addingTimeInterval(7200), note: "", status: .toBeStarted,
        createdAt: Date(), updatedAt: Date(), correspondingImageID: ""
    )
    @State static var todo4 = TodoItem(
        id: UUID(), userID: "u",
        title: "已完成的置頂項目", priority: 2, isPinned: true,
        taskDate: Date().addingTimeInterval(10800), note: "", status: .completed,
        createdAt: Date(), updatedAt: Date(), correspondingImageID: ""
    )
    // 新增一個無時間的項目
    @State static var todo5 = TodoItem(
        id: UUID(), userID: "u",
        title: "備忘錄項目（無時間）", priority: 0, isPinned: false,
        taskDate: nil, note: "測試無時間項目的顯示方式", status: .toBeStarted,
        createdAt: Date(), updatedAt: Date(), correspondingImageID: ""
    )

    static var previews: some View {
        VStack(spacing: 0) { // 使用 VStack 顯示多個預覽
            ItemRow(item: $todo1)
            Rectangle().fill(Color.white.opacity(0.2)).frame(height: 2) // 模擬分隔線
            ItemRow(item: $todo3)
            Rectangle().fill(Color.white.opacity(0.2)).frame(height: 2) // 模擬分隔線
            ItemRow(item: $todo2)
            Rectangle().fill(Color.white.opacity(0.2)).frame(height: 2) // 模擬分隔線
            ItemRow(item: $todo4)
            Rectangle().fill(Color.white.opacity(0.2)).frame(height: 2) // 模擬分隔線
            ItemRow(item: $todo5) // 新增無時間項目預覽
        }
        .padding() // 給 VStack 一點邊距
        .background(Color.black) // 設定背景色
        .previewLayout(.sizeThatFits)
        .preferredColorScheme(.dark)
    }
}
