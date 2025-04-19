import SwiftUI

struct Add: View {
    @Binding var toDoItems: [TodoItem]
    @State private var title: String = ""
    @State private var note: String = ""
    @State private var priority: Int = 2
    @State private var isPinned: Bool = false
    @State private var taskDate: Date = Date()
    @State private var showAddSuccess: Bool = false
    @State private var currentBlockIndex: Int = 0
    
    // 處理關閉此視圖的事件
    var onClose: (() -> Void)?
    
    // 區塊標題列表，模擬多個區塊
    let blockTitles = ["備忘錄", "重要事項", "會議記錄"]
    
    var body: some View {
        // 使用ZStack作為根視圖
        ZStack {
            // 背景使用透明色，不會阻擋Home.swift的模糊效果
            Color.clear
            
            VStack(alignment: .leading, spacing: 0) {
                
                // 主要內容區域
                VStack(alignment: .leading, spacing: 20) {
                    // "Add task to" 文本
                    Text("Add task to")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .padding(.top, 16)
                    
                    // 自定義滑動區域，讓兩邊可以看到一部分下一個/上一個區塊
                    VStack {
                        TabView(selection: $currentBlockIndex) {
                            ForEach(0..<blockTitles.count, id: \.self) { index in
                                // 區塊内容
                                ZStack {
                                    // 使用您提供的Rectangle尺寸
                                    Rectangle()
                                        .foregroundColor(.clear)
                                        .frame(width: 329, height: 51)
                                        .background(Color(red: 0.85, green: 0.85, blue: 0.85))
                                        .cornerRadius(8)
                                        .opacity(0.15)
                                    
                                    // 內容疊加在Rectangle上
                                    HStack {
                                        Text(blockTitles[index])
                                            .font(
                                                Font.custom("Instrument Sans", size: 31.79449)
                                                    .weight(.bold)
                                            )
                                            .foregroundColor(.white)
                                            .padding(.leading, 16)
                                        
                                        Spacer()
                                        
                                        Text("待辦事項佇列")
                                            .foregroundColor(.white)
                                            .font(
                                                Font.custom("Inter", size: 14)
                                                    .weight(.semibold)
                                            )
                                            .padding(.trailing, 40)
                                        
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(.white)
                                            .font(.system(size: 14))
                                            .padding(.trailing, 16)
                                    }
                                    .frame(width: 329)
                                }
                                .padding(.horizontal, 20) // 添加水平間距，使兩側有空間預覽下一個/上一個區塊
                                .tag(index)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .frame(height: 51)
                        .padding(.horizontal, -15) // 負值的外邊距，讓TabView能夠延伸到容器之外
                    }
                    .padding(.horizontal, -5) // 讓滑動區域能夠看到下一個區塊的一部分
                    .frame(maxWidth: .infinity)
                    .clipped(antialiased: true) // 裁剪越界部分
                    

                    
                    Rectangle()
                        .fill(Color(red: 0, green: 0.72, blue: 0.41))
                        .frame(height: 1)
                        .padding(.vertical, 8)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "text.bubble")
                                .foregroundColor(.white.opacity(0.7))
                            
                            TextField("點此輸入備註...", text: $note)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 16) {
                        HStack(spacing: 8) {
                            ToolbarButton(icon: "asterisk.circle", text: "")
                            ToolbarButton(icon: "bell", text: "")
                            ToolbarButton(icon: "clock", text: "time")
                            ToolbarButton(icon: "text.badge.plus", text: "note")
                        }
                        .padding(.horizontal, 8)
                        
                        HStack(spacing: 8) {
                            QuickSuggestionButton(text: "\"Design\"")
                            QuickSuggestionButton(text: "Designed")
                            QuickSuggestionButton(text: "Designer")
                        }
                        .padding(.horizontal, 4)
                    }
                    
                    HStack {
                        Button(action: {
                            if let onClose = onClose {
                                onClose()
                            }
                        }) {
                            Text("Back")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 80, height: 46)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(25)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            addNewTask()
                            if let onClose = onClose {
                                onClose()
                            }
                        }) {
                            Text("ADD")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                                .frame(width: 250, height: 46)
                                .background(Color.white)
                                .cornerRadius(25)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .padding(.horizontal, 16)
            }
        }
        // 使用clear的背景色，讓背景完全透明
        .background(Color.clear)
    }
    
    // 添加新任務
    func addNewTask() {
        guard !title.isEmpty else { return }
        
        let newTask = TodoItem(
            id: UUID(),
            userID: "user123",
            title: title,
            priority: priority,
            isPinned: isPinned,
            taskDate: taskDate,
            note: note,
            status: .toBeStarted,
            createdAt: Date(),
            updatedAt: Date(),
            correspondingImageID: "new_task"
        )
        
        toDoItems.append(newTask)
    }
}

// MARK: - 輔助組件

// 工具欄按鈕
struct ToolbarButton: View {
    var icon: String
    var text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
            if !text.isEmpty {
                Text(text)
                    .font(.system(size: 14))
            }
        }
        .foregroundColor(.white.opacity(0.8))
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.15))
        .cornerRadius(8)
    }
}

// 快速建議按鈕
struct QuickSuggestionButton: View {
    var text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(.white.opacity(0.8))
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.white.opacity(0.15))
            .cornerRadius(8)
    }
}

// 虛擬鍵盤按鍵
struct KeyboardKey: View {
    var text: String
    var isWide: Bool = false
    var isExtraWide: Bool = false
    
    var body: some View {
        Text(text)
            .font(.system(size: isWide ? 14 : 16))
            .foregroundColor(.white)
            .frame(width: isExtraWide ? 180 : (isWide ? 60 : 36), height: 36)
            .background(Color.white.opacity(0.25))
            .cornerRadius(6)
    }
}

// 預覽
struct Add_Previews: PreviewProvider {
    @State static var mockItems: [TodoItem] = []
    
    static var previews: some View {
        Add(toDoItems: $mockItems)
            .background(Color.black)
            .edgesIgnoringSafeArea(.all)
    }
}
