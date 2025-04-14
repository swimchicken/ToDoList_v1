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

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            HStack(spacing: 12) {
                // 1. 圓圈按鈕：永遠靠左
                Button {
                    withAnimation {
                        item.status = (item.status == .completed ? .toBeStarted : .completed)
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
                    .frame(maxWidth: .infinity, alignment: .leading) // <--- 修改點：移除 Spacer() 並在此處設定 frame

                // 3. 星星區：固定寬度，靠左對齊內部星星
                HStack(spacing: 2) {
                    // 使用 item.priority 來決定顯示多少星星
                    // 確保 priority 不會是負數或過大 (如果需要)
                    ForEach(0..<max(0, item.priority), id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .resizable()
                            .frame(width: 16, height: 16)
                            .foregroundColor(item.status == .completed ? doneColor : .white)
                    }
                    Spacer() // 讓星星靠左在 starAreaWidth 內
                }
                .frame(width: starAreaWidth, alignment: .leading) // 固定此 HStack 的寬度

                // 4. 時間：固定大小，最右
                Text("\(item.taskDate, formatter: ItemRow.timeFormatter)")
                    .font(.subheadline)
                    .fixedSize(horizontal: true, vertical: false) // 確保時間寬度固定
                    .foregroundColor(item.status == .completed ? doneColor : .white)
            }
            .padding(.vertical, 13) // 增加垂直內距使內容更舒適
            .padding(.horizontal, 2) // 微調水平內距

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

// --- Preview 程式碼保持不變 ---
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
        title: "短標題", priority: 3, isPinned: false,
        taskDate: Date().addingTimeInterval(7200), note: "", status: .toBeStarted,
        createdAt: Date(), updatedAt: Date(), correspondingImageID: ""
    )


    static var previews: some View {
        VStack(spacing: 0) { // 使用 VStack 顯示多個預覽
            ItemRow(item: $todo1)
            Rectangle().fill(Color.white.opacity(0.2)).frame(height: 2) // 模擬分隔線
            ItemRow(item: $todo3)
            Rectangle().fill(Color.white.opacity(0.2)).frame(height: 2) // 模擬分隔線
            ItemRow(item: $todo2)
        }
        .padding() // 給 VStack 一點邊距
        .background(Color.black) // 設定背景色
        .previewLayout(.sizeThatFits)
        .preferredColorScheme(.dark)
    }
}


