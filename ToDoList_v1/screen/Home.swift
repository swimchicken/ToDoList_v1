import SwiftUI
import SpriteKit

struct Home: View {
    @State private var showCalendarView: Bool = false
    @State private var updateStatus: String = ""
    @State private var showToDoSheet: Bool = false
    @State private var showAddTaskSheet: Bool = false
    @State private var toDoItems: [TodoItem] = [
        // 置頂且待辦的項目
        TodoItem(
            id: UUID(), userID: "user123", title: "市場研究", priority: 1, isPinned: true,
            taskDate: Date(), note: "備註 1", status: .toBeStarted,
            createdAt: Date(), updatedAt: Date(), correspondingImageID: "333"
        ),
        // 一般優先級2的項目
        TodoItem(
            id: UUID(), userID: "user123", title: "Prepare tomorrow's", priority: 2, isPinned: false,
            taskDate: Date().addingTimeInterval(3600), note: "備註 2", status: .toBeStarted,
            createdAt: Date(), updatedAt: Date(), correspondingImageID: "22"
        ),
        // 已完成的項目
        TodoItem(
            id: UUID(), userID: "user123", title: "更新上週報告", priority: 2, isPinned: false,
            taskDate: Date().addingTimeInterval(7200), note: "已完成", status: .completed,
            createdAt: Date(), updatedAt: Date(), correspondingImageID: "completed1"
        ),
        // 一般優先級3的項目
        TodoItem(
            id: UUID(), userID: "user123", title: "回覆所有未讀郵件", priority: 3, isPinned: false,
            taskDate: Date().addingTimeInterval(7200), note: "備註 3", status: .toDoList,
            createdAt: Date(), updatedAt: Date(), correspondingImageID: "44"
        ),
        // 進行中但未完成的項目
        TodoItem(
            id: UUID(), userID: "user123", title: "製作簡報", priority: 3, isPinned: false,
            taskDate: Date().addingTimeInterval(7200), note: "進行中", status: .undone,
            createdAt: Date(), updatedAt: Date(), correspondingImageID: "55"
        ),
        // 置頂但已完成的項目
        TodoItem(
            id: UUID(), userID: "user123", title: "重要任務已完成", priority: 1, isPinned: true,
            taskDate: Date().addingTimeInterval(7200), note: "重要且已完成", status: .completed,
            createdAt: Date(), updatedAt: Date(), correspondingImageID: "66"
        ),
        // 待辦佇列項目
        TodoItem(
            id: UUID(), userID: "user123", title: "排程下週會議", priority: 2, isPinned: false,
            taskDate: Date().addingTimeInterval(7200), note: "備註", status: .toDoList,
            createdAt: Date(), updatedAt: Date(), correspondingImageID: "77"
        ),
        // 待開始項目
        TodoItem(
            id: UUID(), userID: "user123", title: "聯絡客戶", priority: 3, isPinned: false,
            taskDate: Date().addingTimeInterval(7200), note: "備註", status: .toBeStarted,
            createdAt: Date(), updatedAt: Date(), correspondingImageID: "88"
        ),
        // 另一個進行中項目
        TodoItem(
            id: UUID(), userID: "user123", title: "系統測試", priority: 3, isPinned: false,
            taskDate: Date().addingTimeInterval(7200), note: "進行中", status: .undone,
            createdAt: Date(), updatedAt: Date(), correspondingImageID: "99"
        )
    ]
    
    // 計算屬性：排序後的待辦事項
    private var sortedToDoItems: [TodoItem] {
        // 首先按置頂狀態排序，其次按任務日期排序
        return toDoItems.sorted { item1, item2 in
            // 置頂項目優先
            if item1.isPinned && !item2.isPinned {
                return true
            }
            if !item1.isPinned && item2.isPinned {
                return false
            }
                    
            // 如果置頂狀態相同，按任務日期排序（由早到晚）
            return item1.taskDate < item2.taskDate
        }
    }

    // 提供索引訪問方法，用於在ForEach中使用
    private func getBindingToSortedItem(at index: Int) -> Binding<TodoItem> {
        let sortedItem = sortedToDoItems[index]
        // 找到原始數組中的索引
        if let originalIndex = toDoItems.firstIndex(where: { $0.id == sortedItem.id }) {
            return $toDoItems[originalIndex]
        }
        // 這種情況理論上不應該發生，但提供一個後備選項
        return Binding<TodoItem>(
            get: { sortedItem },
            set: { _ in }
        )
    }

    private var physicsScene: PhysicsScene {
        PhysicsScene(
            size: CGSize(width: 369, height: 100),
            todoItems: sortedToDoItems // 使用排序後的待辦事項
        )
    }

    var body: some View {
        ZStack {
            // 1. 背景
            Color.black
                .ignoresSafeArea()

            // 2. 主介面內容
            VStack(spacing: 0) {
                // Header
                UserInfoView(
                    avatarImageName: "who",
                    dateText: "Jan 12",
                    dateText2: "Tuesday",
                    statusText: "9:02 awake",
                    temperatureText: "26°C",
                    showCalendarView: $showCalendarView  // 添加這一行
                )
                .frame(maxWidth: .infinity, maxHeight: 0)

                VStack(alignment: .leading, spacing: 8) {
                    // 待辦事項佇列按鈕
                    HStack {
                        Button {
                            withAnimation { showToDoSheet.toggle() }
                        } label: {
                            Text("待辦事項佇列")
                                .font(.custom("Inter", size: 14).weight(.semibold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(8)
                        }
                        .contentShape(Rectangle())

                        Spacer()

                        Image(systemName: "ellipsis")
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 60)

                    // 節日區塊
                    VStack(spacing: 0) {
                        Divider().background(Color.white)
                        HStack(spacing: 16) {
                            Image(systemName: "calendar")
                            Text("Shiro birthday").font(.headline)
                            Spacer()
                            Text("10:00").font(.subheadline)
                        }
                        .frame(width: 354, height: 59)
                        .cornerRadius(12)
                        Divider().background(Color.white)
                    }
                    .foregroundColor(.white)

                    List {
                        ForEach(0..<sortedToDoItems.count, id: \.self) { idx in
                            VStack(spacing: 0) {
                                ItemRow(item: getBindingToSortedItem(at: idx))
                                    .padding(.vertical, 8)
                                Rectangle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 2)
                                }
                                .listRowInsets(.init())
                                .listRowBackground(Color.black)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .padding(.bottom, 170)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 24)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 60)
            .zIndex(1) // 設置主界面内容的層級

            // 3. 底部灰色容器：只包 BumpyCircle & 按鈕
            VStack {
                Spacer()

                VStack(spacing: 10) {
                    // 1. 物理場景 (BumpyCircle 掉落動畫)
                    SpriteView(scene: physicsScene, options: [.allowsTransparency])
                        .frame(width: 369, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 32))
                        .background(Color.clear)

                    // 2. 底下兩個按鈕
                    HStack(spacing: 10) {
                        // end today 按鈕
                        Button("end today") {
                            // end today 功能
                        }
                        .font(.custom("Inria Sans", size: 20).weight(.bold))
                        .foregroundColor(.black)
                        .frame(width: 272, height: 60)
                        .background(Color.white)
                        .cornerRadius(40.5)

                        // plus 按鈕 - 新增任務
                        Button {
                            withAnimation(.easeInOut) {
                                showAddTaskSheet = true
                            }
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 77)
                                    .fill(Color(red: 0, green: 0.72, blue: 0.41))
                                    .frame(width: 71, height: 60)
                                Image(systemName: "plus")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 32)
                        .fill(Color.gray.opacity(0.2))
                )
                .padding(.bottom, 20)
            }
            .zIndex(2) // 設置底部容器的層級

            // 4. ToDoSheetView 彈窗 - 使用半透明背景覆盖整个屏幕
            if showToDoSheet {
                // 半透明背景
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut) { showToDoSheet = false }
                    }
                    .zIndex(9)
                
                // 弹出视图位置调整 - 进一步降低位置
                GeometryReader { geometry in
                    VStack {
                        // 调整上方空间，显示在更下方
                        Spacer().frame(height: geometry.size.height * 0.15)
                        
                        // 中央弹出视图
                        ToDoSheetView(toDoItems: toDoItems) {
                            withAnimation(.easeInOut) { showToDoSheet = false }
                        }
                        
                        // 预留更多空间给底部
                        Spacer()
                    }
                    .frame(width: geometry.size.width)
                }
                .zIndex(10) // 設置ToDoSheetView在最上層
            }
            
            // 5. 添加 Add.swift 彈出視圖
            if showAddTaskSheet {
                // 首先添加模糊層，覆蓋整個屏幕
                ZStack {
                    // 模糊背景效果
                    Rectangle()
                        .fill(.ultraThinMaterial)  // 使用系統模糊材質
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut) {
                                showAddTaskSheet = false
                            }
                        }
                    
                    // Add視圖，在模糊背景之上
                    Add(toDoItems: $toDoItems, onClose: {
                        withAnimation(.easeInOut) {
                            showAddTaskSheet = false
                        }
                    })
                    .transition(.move(edge: .bottom))
                }
                .animation(.easeInOut(duration: 0.3), value: showAddTaskSheet)
                .zIndex(100) // 確保在所有其他內容之上
            }
            
            // 6. 新增: CalendarView 全屏覆蓋
            if showCalendarView {
                ZStack {
                    // 模糊或半透明背景
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut) {
                                showCalendarView = false
                            }
                        }
                        
                    // 顯示 CalendarView，傳入 toDoItems 的綁定
                    CalendarView(toDoItems: $toDoItems)
                        .transition(.move(edge: .bottom))
                }
                .animation(.easeInOut(duration: 0.3), value: showCalendarView)
                .zIndex(200) // 確保顯示在最上層
            }
            
        }
        
        .animation(.easeOut, value: showToDoSheet)
        .animation(.easeOut, value: showAddTaskSheet)
        .animation(.easeOut, value: showCalendarView)
        .onAppear {
            if let appleUserID = UserDefaults.standard.string(forKey: "appleAuthorizedUserId") {
                SaveLast.updateLastLoginDate(forUserId: appleUserID) { result in
                    switch result {
                    case .success:
                        updateStatus = "更新成功"
                    case .failure(let error):
                        updateStatus = "更新失敗: \(error.localizedDescription)"
                    }
                }
            } else {
                updateStatus = "找不到 Apple 使用者 ID"
            }
        }
    }
}

// 用於設置圓角的擴展
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

#Preview {
    Home()
}
