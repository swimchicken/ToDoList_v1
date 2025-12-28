// MARK: - ToDoSheetView.swift
import SwiftUI

enum ToDoCategory: Int {
    case all
    case memo
    case incomplete
}

struct ToDoSheetView: View {
    @Binding var toDoItems: [TodoItem]            // 使用 Binding 讓更新可以傳遞回父視圖
    let onDismiss: () -> Void                     // 用來從外部關閉此視圖
    var onAddButtonPressed: () -> Void = {}       // 回調函數，通知 Home 顯示 Add 視圖

    // 新增：當前選擇的日期（從 Home 傳遞過來）
    var selectedDate: Date = Date()
    
    // 創建一個內部可修改的副本
    @State private var mutableItems: [TodoItem]
    
    // 構造器，初始化可變副本
    init(toDoItems: Binding<[TodoItem]>,
         onDismiss: @escaping () -> Void,
         onAddButtonPressed: @escaping () -> Void = {},
         selectedDate: Date = Date()) {
        self._toDoItems = toDoItems                 // 初始化繫結
        self.onDismiss = onDismiss
        self.onAddButtonPressed = onAddButtonPressed
        self.selectedDate = selectedDate
        // 初始化內部副本
        _mutableItems = State(initialValue: toDoItems.wrappedValue)
    }

    @State private var selectedCategory: ToDoCategory = .memo // 默認顯示備忘錄項目
    @State private var animateSheetUp: Bool = false
    @State private var currentDragOffset: CGFloat = 0  // 拖曳時累計的垂直偏移量

    // 根據選取條件過濾待辦事項
    private var filteredItems: [TodoItem] {
        switch selectedCategory {
        case .all:
            // 全部項目 - 包含備忘錄 + 未完成項目（排除已完成項目）
            return mutableItems.filter { $0.status != .completed }
        case .memo:
            // 備忘錄 - 篩選沒有時間且未完成的項目 (taskDate == nil && status != .completed)
            return mutableItems.filter { $0.taskDate == nil && $0.status != .completed }
        case .incomplete:
            // 未完成 - 過去日期且狀態為未完成（不包含今天和未來）
            let today = Calendar.current.startOfDay(for: Date())
            return mutableItems.filter {
                guard let taskDate = $0.taskDate else { return false }
                let taskDay = Calendar.current.startOfDay(for: taskDate)
                return taskDay < today &&
                       ($0.status == .undone || $0.status == .toBeStarted)
            }
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
                    Text("settlement.todo_queue_title")
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
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 16)
                
                // 待辦事項列表 - 使用TodoSheetItemRow
                ScrollView {
                    VStack(spacing: 0) {
                        if filteredItems.isEmpty && selectedCategory == .memo {
                            VStack(spacing: 8) {
                                Text("todo_sheet.no_memo_items")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.top, 30)
                                
                                Text("settlement.add_memo_prompt")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            ForEach(filteredItems.indices, id: \.self) { index in
                                let item = filteredItems[index]
                                if let originalIndex = mutableItems.firstIndex(where: { $0.id == item.id }) {
                                    TodoSheetItemRow(
                                        item: $mutableItems[originalIndex],
                                        onAddToHome: { homeItem in
                                            // 更新本地項目
                                            toDoItems = mutableItems

                                            // 關閉待辦事項佇列視窗
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                onDismiss()
                                            }
                                        },
                                        selectedDate: selectedDate
                                    )
                                    Divider()
                                        .background(Color.white.opacity(0.1))
                                        .padding(.leading, 60)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 20)
                
            }
        }
        // 修改尺寸，移除底部按鈕後調整高度
        .frame(width: UIScreen.main.bounds.width - 40, height: 400) // 移除按鈕後降低高度
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
    @State static var previewItems: [TodoItem] = [
        TodoItem(
            id: UUID(),
            userID: "user123",
            title: "回覆所有未讀郵件",
            priority: 2,
            isPinned: false,
            taskDate: Date(),
            note: "清空收件箱",
            status: TodoStatus.toBeStarted,
            createdAt: Date(),
            updatedAt: Date(),
            correspondingImageID: ""
        ),
        TodoItem(
            id: UUID(),
            userID: "user123",
            title: "準備會議資料",
            priority: 1,
            isPinned: false,
            taskDate: Date(),
            note: "準備PPT",
            status: TodoStatus.toBeStarted,
            createdAt: Date(),
            updatedAt: Date(),
            correspondingImageID: ""
        ),
        TodoItem(
            id: UUID(),
            userID: "user123",
            title: "提交週報",
            priority: 3,
            isPinned: false,
            taskDate: Date(),
            note: "整理本週工作內容",
            status: TodoStatus.toBeStarted,
            createdAt: Date(),
            updatedAt: Date(),
            correspondingImageID: ""
        )
    ]
    
    static var previews: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            ToDoSheetView(
                toDoItems: .constant(previewItems),
                onDismiss: {},
                selectedDate: Date()
            )
        }
        .preferredColorScheme(.dark)
    }
}
