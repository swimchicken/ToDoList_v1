import SwiftUI
import CloudKit

struct Add: View {
    @Binding var toDoItems: [TodoItem]
    @State private var title: String = ""
    @State private var displayText: String = "" // 用於顯示在輸入框
    @State private var note: String = "" // 用於儲存 AddNote 的內容，不顯示在輸入框
    @State private var priority: Int = 0  // 預設為0
    @State private var isPinned: Bool = false
    @State private var taskDate: Date = Date()
    @State private var showAddSuccess: Bool = false
    @State private var currentBlockIndex: Int = 0
    @State private var priorityLevel: Int = 0  // 預設為0，新增：追踪優先級 (0-3)
    
    // Add state for time selection
    @State private var isDateEnabled: Bool = false
    @State private var isTimeEnabled: Bool = false
    @State private var selectedDate: Date = Date()
    @State private var showAddTimeView: Bool = false
    
    // Add state to track keyboard visibility
    @State private var isKeyboardVisible = false
    // Add focus state for the text field
    @FocusState private var isTextFieldFocused: Bool
    // Add state to track if we should refocus after returning from AddTimeView
    @State private var shouldRefocusAfterReturn = false
    
    // Add state for AddNote view
    @State private var showAddNoteView: Bool = false
    @State private var hasNote: Bool = false // 用於追踪是否有筆記內容
    
    // 新增：用於處理 CloudKit 保存狀態
    @State private var isSaving: Bool = false
    @State private var saveError: String? = nil
    @State private var showSaveAlert: Bool = false
    
    // 處理關閉此視圖的事件
    var onClose: (() -> Void)?
    
    // 區塊標題列表，模擬多個區塊
    let blockTitles = ["備忘錄", "重要事項", "會議記錄"]
    
    // Format the time button text based on selected date/time
    var timeButtonText: String {
        if !isDateEnabled && !isTimeEnabled {
            return "time"
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let selectedDay = calendar.startOfDay(for: selectedDate)
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let timeString = timeFormatter.string(from: selectedDate)
        
        // Date part
        var dateText = ""
        if calendar.isDate(selectedDay, inSameDayAs: today) {
            dateText = "Today"
        } else if calendar.isDate(selectedDay, inSameDayAs: tomorrow) {
            dateText = "Tomorrow"
        } else if calendar.isDate(selectedDay, inSameDayAs: yesterday) {
            dateText = "Yesterday"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d"
            dateText = dateFormatter.string(from: selectedDate)
        }
        
        // Combine date and time if both are enabled
        if isDateEnabled && isTimeEnabled {
            return "\(dateText) \(timeString)"
        } else if isDateEnabled {
            return dateText
        } else if isTimeEnabled {
            return timeString
        }
        
        return "time"
    }
    
    // Determine if we should use green text color based on selection
    var shouldUseGreenColor: Bool {
        return isDateEnabled || isTimeEnabled
    }
    
    // Determine if note button should use green color
    var shouldUseGreenColorForNote: Bool {
        return hasNote
    }
    
    var body: some View {
        // 使用ZStack作為根視圖
        ZStack {
            // Background that dismisses keyboard when tapped
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    // Dismiss keyboard when tapping outside the text field
                    isTextFieldFocused = false
                }
            
            VStack(alignment: .leading, spacing: 0) {
                
                // 主要內容區域
                VStack(alignment: .leading, spacing: 0) { // spacing: 20

                    Text("Add task to")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .padding(.top, 16)
                        .padding(.leading, 20)
                    
                    // 自定義滑動區域，讓兩邊可以看到一部分下一個/上一個區塊
                    ScrollCalendarView()
                        .padding(.top, 9)
                        .padding(.leading, 16)
                    
                    Image("Vector 81")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 6){
                        HStack{
                            Image("Check_Rec_Group 1000004070")
                            
                            TextField("", text: $displayText)
                                .foregroundColor(.white)
                                .keyboardType(.default)
                                .colorScheme(.dark)
                                .focused($isTextFieldFocused)
                                .onChange(of: isTextFieldFocused) { newValue in
                                    // Update keyboard visibility state when focus changes
                                    // This is in addition to the notification center observers
                                    // for better reliability
                                    isKeyboardVisible = newValue
                                }
                                .onAppear {
                                    // Set up keyboard notification observers
                                    NotificationCenter.default.addObserver(
                                        forName: UIResponder.keyboardWillShowNotification,
                                        object: nil,
                                        queue: .main
                                    ) { _ in
                                        isKeyboardVisible = true
                                    }
                                    
                                    NotificationCenter.default.addObserver(
                                        forName: UIResponder.keyboardWillHideNotification,
                                        object: nil,
                                        queue: .main
                                    ) { _ in
                                        isKeyboardVisible = false
                                    }
                                }
                                .onDisappear {
                                    // Remove keyboard notification observers
                                    NotificationCenter.default.removeObserver(
                                        self,
                                        name: UIResponder.keyboardWillShowNotification,
                                        object: nil
                                    )
                                    
                                    NotificationCenter.default.removeObserver(
                                        self,
                                        name: UIResponder.keyboardWillHideNotification,
                                        object: nil
                                    )
                                }
                                .toolbar{
                                    ToolbarItemGroup(placement: .keyboard){
                                        ZStack {
                                            ScrollView(.horizontal, showsIndicators: false) {
                                                HStack(spacing: 9) {
                                                    // 修改後的優先級按鈕
                                                    Button(action: {
                                                        // 如果目前有pin，先取消pin
                                                        if isPinned {
                                                            isPinned = false
                                                        }
                                                        
                                                        priorityLevel = (priorityLevel + 1) % 4  // 0,1,2,3循環
                                                        priority = priorityLevel  // 更新 priority 值
                                                    }) {
                                                        HStack(alignment: .center, spacing: 2) {
                                                            ForEach(0..<3) { index in
                                                                Image("Star 1 (3)")
                                                                    .renderingMode(.template)  // 將圖片設為模板，允許著色
                                                                    .foregroundColor(index < priorityLevel ? .green : .white.opacity(0.65))
                                                                    .opacity(index < priorityLevel ? 1.0 : 0.65)
                                                            }
                                                        }
                                                        .frame(width: 109, height: 33.7)
                                                        .background(Color.white.opacity(0.15))
                                                        .cornerRadius(12)
                                                    }
                                                    
                                                    // 修改後的Pin按鈕
                                                    Button(action: {
                                                        isPinned.toggle()
                                                        
                                                        // 如果開啟pin，將優先級設為0
                                                        if isPinned {
                                                            priorityLevel = 0
                                                            priority = 0
                                                        }
                                                    }) {
                                                        HStack {
                                                            Image("Pin")
                                                                .renderingMode(.template)  // 允許著色
                                                                .foregroundColor(isPinned ? .green : .white)
                                                                .opacity(isPinned ? 1.0 : 0.25)
                                                        }
                                                        .frame(width: 51.7, height: 33.7)
                                                        .background(Color.white.opacity(0.15))
                                                        .cornerRadius(12)
                                                    }
                                                    
                                                    // 修改後的Time按鈕 - 顯示選擇的時間
                                                    Button(action: {
                                                        // Set flag to restore focus when returning from AddTimeView
                                                        shouldRefocusAfterReturn = true
                                                        
                                                        // Hide keyboard first
                                                        isTextFieldFocused = false
                                                        
                                                        // Show the AddTimeView when time button is clicked
                                                        showAddTimeView = true
                                                    }) {
                                                        // Use GeometryReader to get available width
                                                        GeometryReader { geometry in
                                                            Text(timeButtonText)
                                                                .lineLimit(1)
                                                                .minimumScaleFactor(0.7)
                                                                .foregroundColor(shouldUseGreenColor ? .green : .white.opacity(0.65))
                                                                .font(.system(size: 18))
                                                                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
                                                        }
                                                        .frame(width: 110, height: 33.7)
                                                        .background(Color.white.opacity(0.15))
                                                        .cornerRadius(12)
                                                    }
                                                    
                                                    // Modified Note button to navigate to AddNote
                                                    Button(action: {
                                                        // Hide keyboard first
                                                        isTextFieldFocused = false
                                                        
                                                        // Show AddNote view
                                                        showAddNoteView = true
                                                    }) {
                                                        Text("note")
                                                            .foregroundColor(shouldUseGreenColorForNote ? .green : .white.opacity(0.65))
                                                            .font(.system(size: 18))
                                                            .frame(width: 110, height: 33.7)
                                                            .background(Color.white.opacity(0.15))
                                                            .cornerRadius(12)
                                                    }
                                                }
                                                .padding(.vertical, 7)
                                                .padding(.horizontal, 8)
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                }
                        }
                        Image("Vector 80")
                    }
                    .padding(.horizontal, 24)
                    
                    // Only show the buttons when keyboard is not visible
                    if !isKeyboardVisible {
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
                            
                            // 修改ADD按鈕，加入保存到CloudKit的邏輯
                            Button(action: {
                                saveToCloudKit()
                            }) {
                                // 根據保存狀態顯示不同文字
                                if isSaving {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                        .frame(width: 250, height: 46)
                                        .background(Color.white)
                                        .cornerRadius(25)
                                } else {
                                    Text("ADD")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.black)
                                        .frame(width: 250, height: 46)
                                        .background(Color.white)
                                        .cornerRadius(25)
                                }
                            }
                            .disabled(displayText.isEmpty || isSaving)
                        }
                        .padding(.top, 16)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                        .transition(.opacity) // Add a transition for smooth appearance/disappearance
                    } else {
                        // Add some bottom padding when keyboard is visible
                        Spacer()
                            .frame(height: 16)
                    }
                }
                .padding(.horizontal, 16)
            }
            .animation(.easeInOut(duration: 0.2), value: isKeyboardVisible) // Animate changes based on keyboard visibility
            .improvedKeyboardAdaptive()
            .alert(isPresented: $showSaveAlert) {
                Alert(
                    title: Text("儲存失敗"),
                    message: Text(saveError ?? "未知錯誤"),
                    dismissButton: .default(Text("OK"))
                )
            }
            
            // Add full-screen cover for AddTimeView
            .fullScreenCover(isPresented: $showAddTimeView) {
                AddTimeView(
                    isDateEnabled: $isDateEnabled,
                    isTimeEnabled: $isTimeEnabled,
                    selectedDate: $selectedDate,
                    onSave: {
                        // This will be called when Save is tapped in AddTimeView
                        showAddTimeView = false
                        // Update the task date with the selected date/time
                        taskDate = selectedDate
                        
                        // Refocus the text field after a short delay if needed
                        if shouldRefocusAfterReturn {
                            // Use a slight delay to ensure the view is fully visible
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                isTextFieldFocused = true
                                shouldRefocusAfterReturn = false
                            }
                        }
                    },
                    onBack: {
                        // This will be called when Back is tapped in AddTimeView
                        showAddTimeView = false
                        
                        // Refocus the text field after a short delay if needed
                        if shouldRefocusAfterReturn {
                            // Use a slight delay to ensure the view is fully visible
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                isTextFieldFocused = true
                                shouldRefocusAfterReturn = false
                            }
                        }
                    }
                )
            }
            
            // Add full-screen cover for AddNote view
            // We use fullScreenCover as a separate view, not inside the text field toolbar
            // This way it won't inherit the keyboard toolbar
        }
        .background(Color(red: 0.22, green: 0.22, blue: 0.22).opacity(0.7))
        // Move the fullScreenCover for AddNote outside the main view structure
        .fullScreenCover(isPresented: $showAddNoteView) {
            AddNote(noteText: note) { savedNote in
                // 只保存note資料，但不顯示在輸入框中
                note = savedNote
                
                // 更新筆記狀態標記
                hasNote = !note.isEmpty
                
                showAddNoteView = false
                
                // 調試信息
                if hasNote {
                    print("成功設置筆記內容，資料長度: \(note.count)字")
                }
            }
        }
    }
    
    // 添加新任務並保存到 CloudKit
    func saveToCloudKit() {
        guard !displayText.isEmpty else { return }
        
        // 設置保存中狀態
        isSaving = true
        
        // 創建新的 TodoItem，將狀態設為 toDoList
        let newTask = TodoItem(
            id: UUID(),
            userID: "user123", // 這裡可以使用實際的使用者ID
            title: displayText,
            priority: priority,
            isPinned: isPinned,
            taskDate: isDateEnabled || isTimeEnabled ? selectedDate : taskDate,
            note: note,
            status: .toDoList, // 設置為 toDoList 狀態
            createdAt: Date(),
            updatedAt: Date(),
            correspondingImageID: "new_task"
        )
        
        // 調用 CloudKitService 保存到雲端
        print("嘗試保存待辦事項到 CloudKit...")
        CloudKitService.shared.saveTodoItem(newTask) { result in
            // 回到主線程處理結果
            DispatchQueue.main.async {
                // 結束保存中狀態
                isSaving = false
                
                switch result {
                case .success(let savedItem):
                    // 保存成功，添加到本地列表並直接關閉視圖
                    print("成功保存待辦事項! ID: \(savedItem.id)")
                    toDoItems.append(savedItem)
                    
                    // 直接關閉視圖，不顯示成功提示
                    if let onClose = onClose {
                        onClose()
                    }
                    
                case .failure(let error):
                    // 保存失敗時才顯示錯誤警告
                    let nsError = error as NSError
                    print("保存到 CloudKit 失敗: \(error.localizedDescription)")
                    print("錯誤代碼: \(nsError.code), 域: \(nsError.domain)")
                    
                    if nsError.domain == CKErrorDomain {
                        switch nsError.code {
                        case CKError.networkFailure.rawValue, CKError.networkUnavailable.rawValue:
                            saveError = "網絡連接問題，請檢查您的網絡連接後重試。"
                        case CKError.notAuthenticated.rawValue:
                            saveError = "未登入 iCloud，請在設置中登入您的 iCloud 帳戶。"
                        case CKError.quotaExceeded.rawValue:
                            saveError = "已超出 iCloud 儲存配額，請清理空間後重試。"
                        case CKError.serverRejectedRequest.rawValue:
                            saveError = "iCloud 伺服器拒絕請求: \(error.localizedDescription)"
                        default:
                            saveError = "iCloud 錯誤 (\(nsError.code)): \(error.localizedDescription)"
                        }
                    } else {
                        saveError = error.localizedDescription
                    }
                    
                    // 顯示錯誤警告
                    showSaveAlert = true
                    
                    // 即使保存失敗，也將項目添加到本地列表，以便用戶可以看到他們的項目
                    print("儘管 CloudKit 保存失敗，仍添加項目到本地列表")
                    toDoItems.append(newTask)
                }
            }
        }
    }
}

// MARK: - Keep existing helper components and extensions


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

struct KeyboardAdaptive: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0
    @State private var isKeyboardVisible = false
    @State private var topPadding: CGFloat = 0

    func body(content: Content) -> some View {
        content
            // 使用條件 padding，只在鍵盤可見時添加
            .padding(.bottom, isKeyboardVisible ? keyboardHeight : 0)
            .padding(.top, isKeyboardVisible ? topPadding : 0)
            .animation(.easeOut(duration: 0.16), value: keyboardHeight)
            .onAppear {
                setupKeyboardObservers()
            }
            .onDisappear {
                removeKeyboardObservers()
            }
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
            
            // 只將鍵盤的高度加上一些額外空間（例如按鈕高度+間距）
//            keyboardHeight = keyboardFrame.height - 30 // 減去一些高度，避免過大的空白
            keyboardHeight = 40
            topPadding = 24
            isKeyboardVisible = true
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            keyboardHeight = 0
            topPadding = 0
            isKeyboardVisible = false
        }
    }
    
    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.removeObserver(
            self,
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
}

extension View {
    func improvedKeyboardAdaptive() -> some View {
        self.modifier(KeyboardAdaptive())
    }
}
