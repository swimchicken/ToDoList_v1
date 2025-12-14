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
    var onOptimisticAdd: ((TodoItem) -> Void)?    // 樂觀更新回調
    var onReplaceOptimistic: ((UUID, TodoItem) -> Void)?  // 替換樂觀項目回調

    // 新增：當前選擇的日期（從 Home 傳遞過來）
    var selectedDate: Date = Date()
    
    // 創建一個內部可修改的副本
    @State private var mutableItems: [TodoItem]
    
    // 構造器，初始化可變副本
    init(toDoItems: Binding<[TodoItem]>,
         onDismiss: @escaping () -> Void,
         onAddButtonPressed: @escaping () -> Void = {},
         onOptimisticAdd: ((TodoItem) -> Void)? = nil,
         onReplaceOptimistic: ((UUID, TodoItem) -> Void)? = nil,
         selectedDate: Date = Date()) {
        self._toDoItems = toDoItems                 // 初始化繫結
        self.onDismiss = onDismiss
        self.onAddButtonPressed = onAddButtonPressed
        self.onOptimisticAdd = onOptimisticAdd
        self.onReplaceOptimistic = onReplaceOptimistic
        self.selectedDate = selectedDate
        // 初始化內部副本
        _mutableItems = State(initialValue: toDoItems.wrappedValue)
    }

    @State private var selectedCategory: ToDoCategory = .memo // 默認顯示備忘錄項目
    @State private var animateSheetUp: Bool = false
    @State private var currentDragOffset: CGFloat = 0  // 拖曳時累計的垂直偏移量
    @State private var refreshTrigger: UUID = UUID()  // 強制重新計算過濾項目

    // 根據選取條件過濾待辦事項
    private var filteredItems: [TodoItem] {
        // 觀察 refreshTrigger 以強制重新計算
        _ = refreshTrigger


        let result: [TodoItem]
        switch selectedCategory {
        case .all:
            // 🔧 使用 toDoItems 而不是 mutableItems，確保看到最新狀態
            result = toDoItems.filter { item in
                // 排除已完成的項目
                guard item.completionStatus != .completed else {
                    return false
                }

                // 🆕 使用新的邏輯：佇列項目 = 備忘錄 + 未完成任務
                let isQueueItem = item.taskType == .memo || item.taskType == .uncompleted
                return isQueueItem
            }
        case .memo:
            // 🔧 使用 toDoItems 而不是 mutableItems，確保看到最新狀態
            result = toDoItems.filter {
                let isMemoAndNotCompleted = $0.taskType == .memo && $0.completionStatus != .completed
                return isMemoAndNotCompleted
            }
        case .incomplete:
            // 🔧 使用 toDoItems 而不是 mutableItems，確保看到最新狀態
            result = toDoItems.filter {
                let isUncompletedAndNotCompleted = $0.taskType == .uncompleted && $0.completionStatus != .completed
                return isUncompletedAndNotCompleted
            }
        }


        return result
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
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 16)
                
                // 待辦事項列表 - 使用TodoSheetItemRow
                ScrollView {
                    VStack(spacing: 0) {
                        if filteredItems.isEmpty && selectedCategory == .memo {
                            VStack(spacing: 8) {
                                Text("還沒有備忘錄項目")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.top, 30)
                                
                                Text("點擊加號來添加一個沒有時間的備忘錄項目")
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
                                if let originalIndex = toDoItems.firstIndex(where: { $0.id == item.id }) {
                                    TodoSheetItemRow(
                                        item: $toDoItems[originalIndex],
                                        onAddToHome: { homeItem in
                                            // 🔧 不再需要同步 mutableItems，因為我們直接使用 toDoItems
                                            // toDoItems 的更新會自動反映到 UI
                                        },
                                        onDismissSheet: {
                                            // 立即關閉彈窗
                                            closeSheet()
                                        },
                                        onOptimisticUpdate: { newItem in
                                            // 立即在 Home.swift 中添加新項目
                                            onOptimisticAdd?(newItem)
                                        },
                                        onReplaceOptimisticItem: { tempId, realItem in
                                            // 替換樂觀添加的項目為真實項目
                                            onReplaceOptimistic?(tempId, realItem)
                                        },
                                        onRefreshQueue: {
                                            // 刷新待辦佇列，觸發重新計算過濾項目
                                            refreshTrigger = UUID()
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
        // 🔧 暫時禁用數據刷新監聽器，避免干擾樂觀更新
        // .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TodoItemsDataRefreshed"))) { _ in
        //     // 當收到數據刷新通知時，同步 mutableItems 與最新的 toDoItems
        //     mutableItems = toDoItems
        // }
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
            taskType: .scheduled,
            completionStatus: .pending,
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
            taskType: .scheduled,
            completionStatus: .pending,
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
            taskType: .scheduled,
            completionStatus: .pending,
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
