import SwiftUI

// MARK: - Task Edit View (Refactored for TodoItem)
struct TaskEditView: View {
    // MARK: - Properties
    
    @Binding var task: TodoItem // <-- 已改為 TodoItem
    let onClose: () -> Void // <-- 新增的關閉閉包
    
    // --- UI 狀態變數 ---
    // 直接綁定到 task 的屬性可以簡化，但為了複用 Add.swift 的複雜 UI 邏輯，
    // 我們在 onAppear 時初始化這些狀態變數。
    @State private var displayText: String = ""
    @State private var note: String = ""
    @State private var priorityLevel: Int = 0
    
    @State private var isDateEnabled: Bool = false
    @State private var isTimeEnabled: Bool = false
    @State private var selectedDate: Date = Date()
    
    // 複製自 Add.swift 的 UI 相關狀態
    @State private var currentBlockIndex: Int = 0
    @State private var showAddTimeView: Bool = false
    @State private var showAddNoteView: Bool = false
    @FocusState private var isTextFieldFocused: Bool
    @State private var isPinned: Bool = false
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // 1. 全螢幕半透明背景 (與 TaskSelectionOverlay 相同)
            Color(red: 0.22, green: 0.22, blue: 0.22).opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    onClose() // 點擊背景也可關閉
                }
            
            // 2. 移除卡片樣式，改為 VStack 垂直佈局
            VStack(alignment: .leading, spacing: 0) {
                
                // --- 頂部內容 ---
                Text("Edit task")
                    .font(.system(size: 16)).foregroundColor(.white)
                    .padding(.top, 16).padding(.leading, 20)
                
                ScrollCalendarView(currentDisplayingIndex: $currentBlockIndex)
                    .padding(.top, 9).padding(.leading, 16)
                
                Image("Vector 81")
                    .resizable().aspectRatio(contentMode: .fit)
                    .padding(.horizontal, 24).padding(.top, 24)
                
                // --- Spacer 會將下方內容推至底部 ---
                Spacer()
                
                // --- 底部編輯控制項 ---
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image("Check_Rec_Group 1000004070")
                        TextField("Task Title", text: $displayText).foregroundColor(.white).focused($isTextFieldFocused)
                    }
                    Image("Vector 80")
                }.padding(.horizontal, 24)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        Button(action: {
                            // 點擊星星時，如果旗子是點亮的，就先把它關掉
                                if isPinned {
                                    isPinned = false
                                }
                                // 然後再更新星星的數量
                                priorityLevel = (priorityLevel + 1) % 4
                        }) {
                            HStack(alignment: .center, spacing: 2) {
                                ForEach(0..<3) { index in
                                    Image("Star 1 (3)").renderingMode(.template)
                                        .foregroundColor(index < priorityLevel ? Color.yellow : .white.opacity(0.65))
                                }
                            }.frame(width: 109, height: 33.7)
                            .background(Color.white.opacity(0.15)).cornerRadius(12)
                        }
                        
                        Button(action: {
                            isPinned.toggle()
                            // 如果開啟 pin，將優先級設為 0
                            if isPinned {
                                priorityLevel = 0
                            }
                        }) {
                            HStack {
                                Image("Pin") // 假設您有這個圖片資源
                                    .renderingMode(.template)
                                    .foregroundColor(isPinned ? .green : .white)
                                    .opacity(isPinned ? 1.0 : 0.25)
                            }
                            .frame(width: 51.7, height: 33.7)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(12)
                        }
                        
                        Button(action: { showAddTimeView = true }) {
                            Text(timeButtonText).lineLimit(1).minimumScaleFactor(0.7)
                                .foregroundColor(isDateEnabled || isTimeEnabled ? .green : .white.opacity(0.65))
                                .font(.system(size: 18)).frame(width: 110, height: 33.7)
                                .background(Color.white.opacity(0.15)).cornerRadius(12)
                        }
                        Button(action: { showAddNoteView = true }) {
                            Text("note").foregroundColor(!note.isEmpty ? .green : .white.opacity(0.65))
                                .font(.system(size: 18)).frame(width: 110, height: 33.7)
                                .background(Color.white.opacity(0.15)).cornerRadius(12)
                        }
                    }.padding(.vertical, 7).padding(.horizontal, 8)
                }.padding(.horizontal, 16)
                
                Spacer().frame(height: 20)
                
                // --- Back/Save 按鈕 ---
                HStack {
                    Button(action: { onClose() }) {
                        Text("Back")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .padding()
                    }
                    Spacer()
                    Button(action: { saveChanges() }) {
                        Text("Save")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 260, height: 60)
                            .background(displayText.isEmpty ? Color.gray : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    }
                    .disabled(displayText.isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .onChange(of: currentBlockIndex) {
            // 當使用者滑動日曆時，更新 selectedDate 的值
            updateDateFromBlockIndex()
        }
        .onAppear(perform: setupInitialState)
        .sheet(isPresented: $showAddTimeView) {
            SimpleTimeSelector(isDateEnabled: $isDateEnabled, isTimeEnabled: $isTimeEnabled, selectedDate: $selectedDate)
        }
        .sheet(isPresented: $showAddNoteView) {
            SimpleNoteEditor(noteText: $note)
        }
    }
    
    // MARK: - Helper Functions
    
    private func setupInitialState() {
        // 使用傳入的 task 資料來設定 UI 狀態
        displayText = task.title
        note = task.note
        priorityLevel = task.priority
        isPinned = task.isPinned
        
        if let taskDate = task.taskDate {
            isDateEnabled = true
            selectedDate = taskDate
            
            // 檢查時間是否為午夜，如果不是，則啟用時間選擇器
            let calendar = Calendar.current
            if calendar.component(.hour, from: taskDate) != 0 || calendar.component(.minute, from: taskDate) != 0 {
                isTimeEnabled = true
            } else {
                isTimeEnabled = false
            }
            
        } else {
            isDateEnabled = false
            isTimeEnabled = false
            selectedDate = Date()
        }
    }
    
    private func saveChanges() {
        // 將 UI 上的修改儲存回 @Binding task
        task.title = displayText
        task.note = note
        task.priority = priorityLevel
        task.isPinned = isPinned
        task.updatedAt = Date() // 更新修改時間
        
        if isDateEnabled {
            // 如果只選了日期，需要將時間設為午夜
            if !isTimeEnabled {
                let calendar = Calendar.current
                selectedDate = calendar.startOfDay(for: selectedDate)
            }
            task.taskDate = selectedDate
        } else {
            task.taskDate = nil
        }
        
        onClose()
    }
    
    
    private func updateDateFromBlockIndex() {
        if currentBlockIndex == 0 {
            // 切換到備忘錄模式，清除日期
            isDateEnabled = false
            isTimeEnabled = false
        } else {
            // 其他模式，根據索引計算日期
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())

            // 索引 1 是今天 (偏移 0 天)，索引 2 是明天 (偏移 1 天)...
            if let targetDate = calendar.date(byAdding: .day, value: currentBlockIndex - 1, to: today) {
                // 如果之前沒有啟用時間，將時間設為午夜
                if !isTimeEnabled {
                    self.selectedDate = calendar.startOfDay(for: targetDate)
                } else {
                    // 如果已啟用時間，則保留時間部分，只更新日期部分
                    let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: self.selectedDate)
                    self.selectedDate = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                                      minute: timeComponents.minute ?? 0,
                                                      second: timeComponents.second ?? 0,
                                                      of: targetDate) ?? targetDate
                }
            }
            // 啟用日期
            isDateEnabled = true
        }
    }
    
    
    private var timeButtonText: String {
        if !isDateEnabled { return "Time" }
        let formatter = DateFormatter()
        formatter.dateFormat = isTimeEnabled ? "MMM d, h:mm a" : "MMM d"
        return formatter.string(from: selectedDate)
    }

    // --- Helper Views (Placeholders) ---
    
    struct SimpleTimeSelector: View { @Binding var isDateEnabled: Bool; @Binding var isTimeEnabled: Bool; @Binding var selectedDate: Date; @Environment(\.presentationMode) var presentationMode; var body: some View { NavigationView { VStack { DatePicker("Select Date", selection: $selectedDate, displayedComponents: isTimeEnabled ? [.date, .hourAndMinute] : .date).datePickerStyle(GraphicalDatePickerStyle()).padding(); Toggle("Enable Date", isOn: $isDateEnabled); Toggle("Enable Time", isOn: $isTimeEnabled); Button("Save") { presentationMode.wrappedValue.dismiss() }.padding() }.padding().navigationTitle("Select Time") } } }
    struct SimpleNoteEditor: View { @Binding var noteText: String; @Environment(\.presentationMode) var presentationMode; var body: some View { NavigationView { TextEditor(text: $noteText).padding().navigationTitle("Note").navigationBarItems(trailing: Button("Done") { presentationMode.wrappedValue.dismiss() }) } } }
}
