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
                        .padding(.leading, 20)
                    
                    // 自定義滑動區域，讓兩邊可以看到一部分下一個/上一個區塊
                    ScrollCalendarView()
//                        .padding(.top, 10)
                    
                    Image("Vector 81")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(.horizontal, 24)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "text.bubble")
                                .foregroundColor(.white.opacity(0.7))
                            
                            TextField("點此輸入備註...", text: $note)
                                .foregroundColor(.white)
                                .toolbar{
                                    ToolbarItemGroup(placement: .keyboard){
                                        ZStack {
                                            Rectangle()
                                                .foregroundColor(Color(red: 0.09, green: 0.09, blue: 0.09))
                                                .frame(height: 46.5)
                                                .edgesIgnoringSafeArea(.horizontal) // 忽略水平安全區域
                                            
                                            ScrollView(.horizontal, showsIndicators: false) {
                                                HStack(spacing: 9) {
                                                    Button(action: {}) {
                                                        HStack(alignment: .center, spacing: 2) {
                                                            Image("Star 1 (3)")
                                                                .opacity(0.65)
                                                            Image("Star 1 (3)")
                                                                .opacity(0.65)
                                                            Image("Star 1 (3)")
                                                                .opacity(0.65)
                                                        }
                                                        .frame(width: 109, height: 33.7)
                                                        .background(Color.white.opacity(0.15))
                                                        .cornerRadius(12)
                                                    }
                                                    
                                                    Button(action: {}) {
                                                        HStack {
                                                            Image("Pin")
                                                                .opacity(0.25)
                                                        }
                                                        .frame(width: 51.7, height: 33.7)
                                                        .background(Color.white.opacity(0.15))
                                                        .cornerRadius(12)
                                                    }
                                                    
                                                    Button(action: {}) {
                                                        Text("time")
                                                            .foregroundColor(.white.opacity(0.65))
                                                            .font(.system(size: 18))
                                                            .frame(width: 110, height: 33.7)
                                                            .background(Color.white.opacity(0.15))
                                                            .cornerRadius(12)
                                                    }
                                                    
                                                    Button(action: {}) {
                                                        Text("note")
                                                            .foregroundColor(.white.opacity(0.65))
                                                            .font(.system(size: 18))
                                                            .frame(width: 110, height: 33.7)
                                                            .background(Color.white.opacity(0.15))
                                                            .cornerRadius(12)
                                                    }
                                                }
                                                .padding(.vertical, 7)
                                                .padding(.horizontal, 8)
                                            }
                                            // 這裡不再給 ScrollView 加背景色，因為已經有外層的 Rectangle
                                        }
                                        .frame(maxWidth: .infinity) // 確保整個工具列最大寬度
                                        
                                    }
                                }
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
