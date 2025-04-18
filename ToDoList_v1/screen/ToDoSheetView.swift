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
            // 背景 - 深灰色半透明背景
            Color(red: 0.15, green: 0.15, blue: 0.15, opacity: 0.95)
            
            // 頂部拖曳條
            VStack(spacing: 0) {
                // 頂部灰色指示條
                Rectangle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 40, height: 4)
                    .cornerRadius(2)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                
                // 標題欄
                HStack {
                    Text("待辦事項佇列")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "ellipsis")
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                
                // 分類按鈕列
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        categoryButton(.all, title: "全部")
                        categoryButton(.memo, title: "備忘錄")
                        categoryButton(.incomplete, title: "未完成")
                        Button {
                            // 新增分類按鈕的功能
                        } label: {
                            Image(systemName: "plus")
                                .foregroundColor(Color(red: 0.53, green: 0.53, blue: 0.53))
                                .frame(width: 16, height: 16)
                                .padding(10)
                                .frame(width: 40, height: 38, alignment: .center)
                                .background(.white.opacity(0.06))
                                .cornerRadius(28)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 28)
                                        .inset(by: 0)
                                        .stroke(Color(red: 0.53, green: 0.53, blue: 0.53), lineWidth: 0)
                                )
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 16)
                
                // 待辦事項列表 - 使用新的TodoSheetItemRow
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(filteredItems.indices, id: \.self) { index in
                            let item = filteredItems[index]
                            if let originalIndex = toDoItems.firstIndex(where: { $0.id == item.id }) {
                                TodoSheetItemRow(item: Binding(
                                    get: { toDoItems[originalIndex] },
                                    set: { _ in }
                                ))
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                    .padding(.leading, 60)
                            }
                        }
                    }
                }
                .padding(.bottom, 20)
            }
        }
        // 圓角和尺寸
        .frame(width: UIScreen.main.bounds.width - 40, height: 530)
        .cornerRadius(30)
        // 动画和偏移 - 默认位置不设置，由容器控制
        .offset(y: (animateSheetUp ? 0 : 800) + currentDragOffset)
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
                .padding(10)
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
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            ToDoSheetView(
                toDoItems: [
                    TodoItem(
                        id: UUID(),
                        userID: "user123",
                        title: "回覆所有未讀郵件",
                        priority: 2,
                        isPinned: false,
                        taskDate: Date(),
                        note: "清空收件箱",
                        status: .toBeStarted,
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
                    ),
                    TodoItem(
                        id: UUID(),
                        userID: "user123",
                        title: "回覆所有未讀郵件",
                        priority: 3,
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
        }
        .preferredColorScheme(.dark)
    }
}
