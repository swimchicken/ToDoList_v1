import SwiftUI

struct TobestartedView: View {
    @Binding var items: [TodoItem]
    @Binding var selectedFilter: String
    let collapseAction: () -> Void // 新增：收合動作的閉包

    let filters: [String] = ["全部", "備忘錄", "未完成"]

    private var filteredItems: [TodoItem] {
        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("待辦事項佇列")
                    .font(Font.custom("Inter", size: 16))
                    .foregroundColor(.white)
                Spacer()
                HStack(spacing: 10) {
                    ForEach(filters, id: \.self) { filter in
                        Button(action: {
                            selectedFilter = filter
                        }) {
                            Text(filter)
                                .font(Font.custom("Inter", size: 12).weight(.semibold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(
                                    selectedFilter == filter ?
                                    Color(red: 0, green: 0.72, blue: 0.41) :
                                    Color.white.opacity(0.15)
                                )
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top)
            .padding(.bottom, 15)

            VStack(spacing: 0) {
                ForEach(filteredItems.indices, id: \.self) { index in
                    let item = filteredItems[index]
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Rectangle()
                                .foregroundColor(.clear)
                                .frame(width: 28, height: 28)
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(40.5)
                            
                            Text(item.title)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up")
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 12)

                        if index < filteredItems.count - 1 {
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(Color(red: 0.34, green: 0.34, blue: 0.34))
                        }
                    }
                }
            }
            .padding(.horizontal)

            // MARK: - "more" 按鈕修改為收合按鈕
            Button(action: {
                collapseAction() // 觸發收合動作
            }) {
                HStack {
                    Spacer()
                    Text("收合") // 可以考慮更改文字，或只用圖示
                        .font(Font.custom("Inter", size: 12).weight(.medium)) // 調整字體
                        .foregroundColor(.gray)
                    Image(systemName: "chevron.up") // 圖示改為向上，表示收合
                        .foregroundColor(.gray)
                        .font(.caption)
                    Spacer()
                }
            }
            .padding(.vertical) // 增加點擊區域
            .padding(.horizontal)
        }
        .background(Color(white: 0.12, opacity: 1.0))
        .cornerRadius(12)
    }
}

// Preview for TobestartedView
struct TobestartedView_Previews: PreviewProvider {
    @State static var previewItems: [TodoItem] = [
        TodoItem(id: UUID(), userID: "user1", title: "回覆所有未讀郵件", priority: 1, isPinned: false, taskDate: nil, note: "", taskType: .memo, completionStatus: .pending, status: .toDoList, createdAt: Date(), updatedAt: Date(), correspondingImageID: ""),
        TodoItem(id: UUID(), userID: "user1", title: "整理桌面和文件夾", priority: 1, isPinned: false, taskDate: nil, note: "", taskType: .memo, completionStatus: .pending, status: .toDoList, createdAt: Date(), updatedAt: Date(), correspondingImageID: "")
    ]
    @State static var previewFilter: String = "全部"

    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                // 在 Preview 中，我們需要提供一個空的 collapseAction
                TobestartedView(items: $previewItems, selectedFilter: $previewFilter, collapseAction: {
                    print("Preview collapse action triggered")
                })
            }
            .padding()
        }
    }
}
