import SwiftUI
import SpriteKit

struct Home: View {
    @State private var updateStatus: String = ""
    @State private var showToDoSheet: Bool = false
    @State private var toDoItems: [TodoItem] = [
        TodoItem(
            id: UUID(), userID: "user123", title: "市場研究", priority: 1, isPinned: true,
            taskDate: Date(), note: "備註 1", status: .toBeStarted,
            createdAt: Date(), updatedAt: Date(), correspondingImageID: ""
        ),
        TodoItem(
            id: UUID(), userID: "user123", title: "Prepare tomorrow’s", priority: 2, isPinned: false,
            taskDate: Date().addingTimeInterval(3600), note: "備註 2", status: .toBeStarted,
            createdAt: Date(), updatedAt: Date(), correspondingImageID: ""
        ),
        TodoItem(
            id: UUID(), userID: "user123", title: "回覆所有未讀郵件", priority: 3, isPinned: false,
            taskDate: Date().addingTimeInterval(7200), note: "備註 3", status: .toDoList,
            createdAt: Date(), updatedAt: Date(), correspondingImageID: ""
        ),
        TodoItem(
            id: UUID(), userID: "user123", title: "回覆所有未讀郵件", priority: 3, isPinned: false,
            taskDate: Date().addingTimeInterval(7200), note: "備註 3", status: .toDoList,
            createdAt: Date(), updatedAt: Date(), correspondingImageID: ""
        ),
        TodoItem(
            id: UUID(), userID: "user123", title: "回覆所有未讀郵件", priority: 3, isPinned: false,
            taskDate: Date().addingTimeInterval(7200), note: "備註 3", status: .toDoList,
            createdAt: Date(), updatedAt: Date(), correspondingImageID: ""
        ),
        TodoItem(
            id: UUID(), userID: "user123", title: "回覆所有未讀郵件", priority: 3, isPinned: false,
            taskDate: Date().addingTimeInterval(7200), note: "備註 3", status: .toDoList,
            createdAt: Date(), updatedAt: Date(), correspondingImageID: ""
        )
    ]

    private var physicsScene: PhysicsScene {
        PhysicsScene(
            size: CGSize(width: 369, height: 140),
            itemsCount: toDoItems.count
        )
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            // 主介面內容
            VStack(spacing: 0) {
                // Header
                UserInfoView(
                    avatarImageName: "who",
                    dateText: "Jan 12",
                    dateText2: "Tuesday",
                    statusText: "9:02 awake",
                    temperatureText: "26°C"
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

                    // 待辦清單
                    List {
                        ForEach(toDoItems.indices, id: \.self) { idx in
                            VStack(spacing: 0) {
                                ItemRow(item: $toDoItems[idx])
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

            // ToDoSheetView 彈窗
            if showToDoSheet {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut) { showToDoSheet = false }
                        }

                    ToDoSheetView(toDoItems: toDoItems) {
                        withAnimation(.easeInOut) { showToDoSheet = false }
                    }
                    .transition(.move(edge: .bottom))
                }
                .gesture(
                    DragGesture().onEnded { v in
                        if v.translation.height > 50 {
                            withAnimation(.easeInOut) { showToDoSheet = false }
                        }
                    }
                )
            }

            // 底部灰色容器：只包 BumpyCircle & 按鈕
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

                        // pencil 按鈕
                        Button {
                            // pencil 功能
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 77)
                                    .fill(Color(red: 0, green: 0.72, blue: 0.41))
                                    .frame(width: 71, height: 60)
                                Image(systemName: "square.and.pencil")
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
        }
        .animation(.easeOut, value: showToDoSheet)
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

#Preview {
    Home()
}
