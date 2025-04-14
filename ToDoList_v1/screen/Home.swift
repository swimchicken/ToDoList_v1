import SwiftUI

struct Home: View {
    @State private var updateStatus: String = ""
    @State private var showToDoSheet: Bool = false

    // 建立三個事件，其中兩個狀態為 .toBeStarted，另一個為 .toDoList
    @State private var toDoItems: [TodoItem] = [
        TodoItem(
            id: UUID(), userID: "user123", title: "市場研究", priority: 1, isPinned: true,
            taskDate: Date(), note: "備註 1", status: .toBeStarted,
            createdAt: Date(), updatedAt: Date(), correspondingImageID: ""
        ),
        TodoItem(
            id: UUID(), userID: "user123", title: "Prepare tomorrow’s ", priority: 2, isPinned: false,
            taskDate: Date().addingTimeInterval(3600), note: "備註 2", status: .toBeStarted,
            createdAt: Date(), updatedAt: Date(), correspondingImageID: ""
        ),
        TodoItem(
            id: UUID(), userID: "user123", title: "回覆所有未讀郵件", priority: 3, isPinned: false,
            taskDate: Date().addingTimeInterval(7200), note: "備註 3", status: .toDoList,
            createdAt: Date(), updatedAt: Date(), correspondingImageID: ""
        )
    ]

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

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
                    // 按鈕列：靠左對齊
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
                                    .frame(maxWidth: .infinity, minHeight: 2, maxHeight: 2)
                            }
                            .listRowInsets(.init())
                            .listRowBackground(Color.black)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 24)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 60)

            // 浮層
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
        }
        .animation(.easeOut, value: showToDoSheet)
    }
}

#Preview {
    Home()
}
