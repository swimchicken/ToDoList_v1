import SwiftUI

enum ToDoCategory: Int {
    case all
    case memo
    case incomplete
}

struct ToDoSheetView: View {
    let toDoItems: [TodoItem]
    let onDismiss: () -> Void  // 用來從外部關閉此視圖

    @State private var selectedCategory: ToDoCategory = .all
    @State private var animateSheetUp: Bool = false
    @State private var currentDragOffset: CGFloat = 0  // 拖曳時累計的垂直偏移量

    // 根據選取條件過濾待辦事項
    private var filteredItems: [TodoItem] {
        switch selectedCategory {
        case .all:
            return toDoItems
        case .memo:
            // 這裡以 priority == 2 作為篩選「備忘錄」的條件，可依需求修改
            return toDoItems.filter { $0.priority == 2 }
        case .incomplete:
            // 過濾出狀態不是 .completed 的待辦事項
            return toDoItems.filter { $0.status != .completed }
        }
    }

    var body: some View {
        ZStack {
            // 背景模糊視圖：只在此形狀內產生模糊效果
            VisualEffectBlur(style: .systemChromeMaterialDark)

            // 前景內容：保持清晰
            VStack(alignment: .center, spacing: 20) {
                // 小橫槓作為拖曳指示器
                Capsule()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 40, height: 6)
                    .padding(.top, 8)
                    .gesture(
                        DragGesture().onEnded { value in
                            if value.translation.height > 50 {
                                closeSheet()
                            }
                        }
                    )
                
                // ─── 標題列 ───
                HStack {
                    Text("待辦事項佇列")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "ellipsis")
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                
                // ─── 篩選標籤列 ───
                HStack(spacing: 12) {
                    categoryButton(.all, title: "全部")
                    categoryButton(.memo, title: "備忘錄")
                    categoryButton(.incomplete, title: "未完成")
                }
                .frame(maxWidth: .infinity, alignment: .leading)  // 使按鈕向左對齊
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // ─── 待辦事項清單 ───
                List {
                    ForEach(filteredItems) { item in
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.white)
                            Text(item.title)
                                .foregroundColor(.white)
                            Spacer()
                            if item.priority >= 2 {
                                Text("★")
                                    .foregroundColor(.yellow)
                            }
                            Image(systemName: "chevron.right")
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 8)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(height: 300)
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        // 固定浮層尺寸與圓角
        .frame(width: 369, height: 566, alignment: .top)
        .clipShape(RoundedRectangle(cornerRadius: 36))
        .overlay(
            RoundedRectangle(cornerRadius: 36)
                .inset(by: 0.5)
                .stroke(Color(red: 0.28, green: 0.28, blue: 0.28), lineWidth: 1)
        )
        // 更新 offset：基於初始位置與當前拖曳偏移
        .offset(y: (animateSheetUp ? 50 : 650) + currentDragOffset)
        // 整體拖曳手勢處理
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        currentDragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 50 {
                        closeSheet()
                    } else {
                        withAnimation(.spring()) {
                            currentDragOffset = 0
                        }
                    }
                }
        )
        .animation(.interpolatingSpring(stiffness: 300, damping: 30), value: animateSheetUp)
        .onAppear {
            animateSheetUp = true
        }
    }

    // MARK: - 關閉浮層 (包含動畫)
    private func closeSheet() {
        withAnimation {
            animateSheetUp = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }

    // MARK: - 篩選按鈕元件
    @ViewBuilder
    private func categoryButton(_ category: ToDoCategory, title: String) -> some View {
        Button {
            selectedCategory = category
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    selectedCategory == category
                    ? Color(red: 0, green: 0.72, blue: 0.41)
                    : Color.white.opacity(0.08)
                )
                .cornerRadius(8)
        }
    }
}

struct ToDoSheetView_Previews: PreviewProvider {
    static var previews: some View {
        ToDoSheetView(
            toDoItems: [
                TodoItem(
                    id: UUID(),
                    userID: "user123",
                    title: "市場研究",
                    priority: 1,
                    isPinned: false,
                    taskDate: Date(),
                    note: "研究產品市場趨勢",
                    status: .toBeStarted,
                    createdAt: Date(),
                    updatedAt: Date(),
                    correspondingImageID: ""
                ),
                TodoItem(
                    id: UUID(),
                    userID: "user123",
                    title: "備忘錄：市場研究",
                    priority: 2,
                    isPinned: false,
                    taskDate: Date(),
                    note: "記得撰寫備忘錄",
                    status: .toBeStarted,
                    createdAt: Date(),
                    updatedAt: Date(),
                    correspondingImageID: ""
                ),
                TodoItem(
                    id: UUID(),
                    userID: "user123",
                    title: "Draft meeting notes",
                    priority: 3,
                    isPinned: false,
                    taskDate: Date(),
                    note: "會議記錄初稿",
                    status: .completed,
                    createdAt: Date(),
                    updatedAt: Date(),
                    correspondingImageID: ""
                ),
                TodoItem(
                    id: UUID(),
                    userID: "user123",
                    title: "回覆所有未讀郵件",
                    priority: 1,
                    isPinned: false,
                    taskDate: Date(),
                    note: "清空收件箱",
                    status: .toBeStarted,
                    createdAt: Date(),
                    updatedAt: Date(),
                    correspondingImageID: ""
                )
            ],
            onDismiss: {}
        )
        .preferredColorScheme(.dark)
    }
}
