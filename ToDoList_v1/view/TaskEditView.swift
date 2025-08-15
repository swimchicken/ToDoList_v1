import SwiftUI

// MARK: - Task Edit View (Refactored for TodoItem)
struct TaskEditView: View {
    // MARK: - Properties
    
    @Binding var task: TodoItem // <-- 已改為 TodoItem
    @Environment(\.presentationMode) var presentationMode
    
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
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.1, green: 0.1, blue: 0.1).ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 0) {
                    // ... 佈局與之前相同 ...
                    Text("Edit task")
                        .font(.system(size: 16)).foregroundColor(.white)
                        .padding(.top, 16).padding(.leading, 20)
                    
                    ScrollCalendarView(currentDisplayingIndex: $currentBlockIndex)
                        .padding(.top, 9).padding(.leading, 16).disabled(true)
                    
                    Image("Vector 81")
                        .resizable().aspectRatio(contentMode: .fit)
                        .padding(.horizontal, 24).padding(.top, 24)
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image("Check_Rec_Group 1000004070")
                            TextField("Task Title", text: $displayText).foregroundColor(.white).focused($isTextFieldFocused)
                        }
                        Image("Vector 80")
                    }.padding(.horizontal, 24)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 9) {
                            Button(action: { priorityLevel = (priorityLevel + 1) % 4 }) {
                                HStack(alignment: .center, spacing: 2) {
                                    ForEach(0..<3) { index in
                                        Image("Star 1 (3)").renderingMode(.template)
                                            .foregroundColor(index < priorityLevel ? Color.yellow : .white.opacity(0.65))
                                    }
                                }.frame(width: 109, height: 33.7)
                                .background(Color.white.opacity(0.15)).cornerRadius(12)
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
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { presentationMode.wrappedValue.dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { saveChanges() }.disabled(displayText.isEmpty) }
            }
            .onAppear(perform: setupInitialState) // 載入時用 task 資料初始化 UI
            .sheet(isPresented: $showAddTimeView) {
                SimpleTimeSelector(isDateEnabled: $isDateEnabled, isTimeEnabled: $isTimeEnabled, selectedDate: $selectedDate)
            }
            .sheet(isPresented: $showAddNoteView) {
                SimpleNoteEditor(noteText: $note)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func setupInitialState() {
        // 使用傳入的 task 資料來設定 UI 狀態
        displayText = task.title
        note = task.note
        priorityLevel = task.priority
        
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
        
        presentationMode.wrappedValue.dismiss()
    }
    
    private var timeButtonText: String {
        if !isDateEnabled { return "Time" }
        let formatter = DateFormatter()
        formatter.dateFormat = isTimeEnabled ? "MMM d, h:mm a" : "MMM d"
        return formatter.string(from: selectedDate)
    }

    // --- Helper Views (Placeholders) ---
    struct ScrollCalendarView: View { @Binding var currentDisplayingIndex: Int; var body: some View { Text("Date Selector Placeholder").foregroundColor(.gray) } }
    struct SimpleTimeSelector: View { @Binding var isDateEnabled: Bool; @Binding var isTimeEnabled: Bool; @Binding var selectedDate: Date; @Environment(\.presentationMode) var presentationMode; var body: some View { NavigationView { VStack { DatePicker("Select Date", selection: $selectedDate, displayedComponents: isTimeEnabled ? [.date, .hourAndMinute] : .date).datePickerStyle(GraphicalDatePickerStyle()).padding(); Toggle("Enable Date", isOn: $isDateEnabled); Toggle("Enable Time", isOn: $isTimeEnabled); Button("Save") { presentationMode.wrappedValue.dismiss() }.padding() }.padding().navigationTitle("Select Time") } } }
    struct SimpleNoteEditor: View { @Binding var noteText: String; @Environment(\.presentationMode) var presentationMode; var body: some View { NavigationView { TextEditor(text: $noteText).padding().navigationTitle("Note").navigationBarItems(trailing: Button("Done") { presentationMode.wrappedValue.dismiss() }) } } }
}
