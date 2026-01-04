    import SwiftUI
import CloudKit

// 導入本地數據和同步管理器
import Combine

struct Add: View {
    // 使用與 Home.swift 相同的 enum
    enum AddMode {
        case memo      // 備忘錄模式（從待辦事項佇列添加）
        case today     // 今天模式（從今天添加）
        case future    // 未來日期模式（從未來日期添加）
    }
    
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
    @State private var totalDays: Int = 60      // 總天數，與 ScrollCalendarView 同步
    
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
    
    @State private var editingItem: TodoItem? = nil  // 保存正在編輯的項目

    // 新增：防重複提交機制
    @State private var lastSubmissionTime: Date = Date.distantPast
    @State private var currentTaskId: String? = nil
    private let minimumSubmissionInterval: TimeInterval = 2.0 // 最小提交間隔2秒
    
    // 用於記住初始模式
    var mode: AddMode = .today
    var offset: Int = 0
    
    // 新增：明確標記是否來自待辦事項佇列
    var isFromTodoSheet: Bool = false
    
    // 處理關閉此視圖的事件
    var onClose: (() -> Void)?
    var onOptimisticAdd: ((TodoItem) -> Void)?
    
    // 區塊標題列表，模擬多個區塊
    let blockTitles = ["備忘錄", "重要事項", "會議記錄"]
    
    // MARK: - MODIFIED: 修改 init 方法以接收 initialDate
    init(toDoItems: Binding<[TodoItem]>, initialMode: Home.AddTaskMode, initialDate: Date, fromTodoSheet: Bool = false, editingItem: TodoItem? = nil, onClose: (() -> Void)? = nil, onOptimisticAdd: ((TodoItem) -> Void)? = nil) {

        self._toDoItems = toDoItems
        self.onClose = onClose
        self.onOptimisticAdd = onOptimisticAdd
        self.isFromTodoSheet = fromTodoSheet
        
        // --- 新增邏輯：從傳入的 initialDate 反向計算 dateOffset ---
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startOfInitialDate = calendar.startOfDay(for: initialDate)
        let dateOffset = calendar.dateComponents([.day], from: today, to: startOfInitialDate).day ?? 0
        self.offset = dateOffset
        // --- 結束新增邏輯 ---

        // 1. 決定最終的模式和起始索引
        let calculatedMode: AddMode
        let startIndex: Int
        let startIsDateEnabled: Bool

        if fromTodoSheet {
            calculatedMode = .memo
            startIndex = 0
            startIsDateEnabled = false
        } else {
            switch initialMode {
            case .memo:
                calculatedMode = .memo
                startIndex = 0
                startIsDateEnabled = false
            case .today:
                calculatedMode = .today
                startIndex = 1 // <<<<< 當是 .today 時，強制為 1
                startIsDateEnabled = true
            case .future:
                calculatedMode = .future
                startIndex = dateOffset + 1 // 使用我們計算出的 dateOffset
                startIsDateEnabled = true
            }
        }

        // 2. 設定常規屬性
        self.mode = calculatedMode

        // 3. 初始化 @State 屬性 (只做一次！)
        self._currentBlockIndex = State(initialValue: startIndex) // <<<<< 關鍵！
        self._isDateEnabled = State(initialValue: startIsDateEnabled)
        self._isTimeEnabled = State(initialValue: false) // 預設不啟用時間

        // 4. 設定初始日期 (直接使用傳入的 initialDate)
        self._selectedDate = State(initialValue: initialDate)

        // 如果是編輯模式，預填現有項目的資料
        if let editingItem = editingItem {
            self._title = State(initialValue: editingItem.title)
            self._displayText = State(initialValue: editingItem.title)
            self._priority = State(initialValue: editingItem.priority)
            self._priorityLevel = State(initialValue: editingItem.priority)
            self._isPinned = State(initialValue: editingItem.isPinned)
            
            self._editingItem = State(initialValue: editingItem)
            
            // 處理時間和日期
            if let taskDate = editingItem.taskDate {
                self._taskDate = State(initialValue: taskDate)
                self._selectedDate = State(initialValue: taskDate)
                self._isDateEnabled = State(initialValue: true)
                self._isTimeEnabled = State(initialValue: true)
            }
            
        }

    }
    
    // 設置初始狀態的方法 - 抽取為函數以便重複使用
    private func setupInitialState() {
        // 首先檢查是否來自待辦事項佇列
        if isFromTodoSheet {
            // 如果來自待辦事項佇列，強制設置為備忘錄模式
            isDateEnabled = false
            isTimeEnabled = false
            currentBlockIndex = 0
            return
        }
        
        // 否則根據模式設置不同的初始狀態
        switch mode {
        case .memo:
            // 備忘錄模式 - 關閉日期和時間
            isDateEnabled = false
            isTimeEnabled = false
            currentBlockIndex = 0
            
        case .today:
            // 今天模式 - 啟用日期
            isDateEnabled = true
            isTimeEnabled = false
            currentBlockIndex = 1
            
        case .future:
            // 未來日期模式 - 啟用日期，設置為相應的日期偏移
            isDateEnabled = true
            isTimeEnabled = false
            currentBlockIndex = offset + 1
        }
    }
    
    // 根據當前的 blockIndex 更新日期選擇
    func updateDateFromBlockIndex() {
        
        // 根據 currentBlockIndex 更新日期和時間狀態
        if currentBlockIndex == 0 {
            // 備忘錄模式 - 清除日期
            isDateEnabled = false
            isTimeEnabled = false
            // 保留原有時間以備之後需要
        } else {
            // 其他模式 - 設置為相應的日期
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            
            // 計算目標日期（今天 + (currentBlockIndex - 1)天）
            let targetDate = calendar.date(byAdding: .day, value: currentBlockIndex - 1, to: today) ?? today
            
            // 保留原有的時間部分
            var timeComponents = calendar.dateComponents([.hour, .minute], from: selectedDate)
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: targetDate)
            
            // 如果之前沒有啟用時間，則使用 00:00:00 (午夜)
            if !isTimeEnabled {
                timeComponents.hour = 0
                timeComponents.minute = 0
            }
            
            // 合併日期和時間
            dateComponents.hour = timeComponents.hour
            dateComponents.minute = timeComponents.minute
            
            // 建立新的日期對象
            if let combinedDate = calendar.date(from: dateComponents) {
                selectedDate = combinedDate
            }
            
            // 啟用日期
            isDateEnabled = true
            
        }
    }
    
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
                    // 根據模式和來源設定初始選擇的日期
                    ScrollCalendarView(currentDisplayingIndex: $currentBlockIndex)
                        .padding(.top, 9)
                        .padding(.horizontal, -16)
                    /*
                        // 添加手勢識別器來捕獲滑匡的變化
                        .gesture(
                          DragGesture()
                              .onEnded { value in
                                  // 根據滑動方向判斷是向左還是向右滑動
                                  let threshold: CGFloat = 50
                                  if value.translation.width < -threshold {
                                      // 向左滑動（增加索引）
                                      if currentBlockIndex < totalDays {
                                          currentBlockIndex += 1
                                          updateDateFromBlockIndex()
                                      }
                                  } else if value.translation.width > threshold {
                                      // 向右滑動（減少索引）
                                      if currentBlockIndex > 0 {
                                          currentBlockIndex -= 1
                                          updateDateFromBlockIndex()
                                      }
                                  }
                              }
                        )
                    */
                    
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
                                .submitLabel(.done)
                                .onSubmit {
                                    if !displayText.isEmpty && !isSaving {
                                        saveToCloudKit()
                                    }
                                }
                                .onChange(of: isTextFieldFocused) { newValue in
                                    // Update keyboard visibility state when focus changes
                                    // This is in addition to the notification center observers
                                    // for better reliability
                                    isKeyboardVisible = newValue
                                    
                                    // 確保當文字欄獲得焦點時更新日期/時間顯示
                                    if newValue == true {
                                        // 再次調用 updateDateFromBlockIndex() 確保時間按鈕顯示最新狀態
                                        updateDateFromBlockIndex()
                                    }
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
                                                        
                                                        // 先再次同步時間與滑匡位置，確保時間正確
                                                        updateDateFromBlockIndex()
                                                        
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
                                // 額外防護：再次檢查是否正在保存
                                if !isSaving {
                                    saveToCloudKit()
                                }
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
                            .disabled(displayText.isEmpty || isSaving || Date().timeIntervalSince(lastSubmissionTime) < minimumSubmissionInterval)
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
                        
                        // 只有在時間啟用時才更新taskDate
                        if isTimeEnabled {
                            taskDate = selectedDate
                        }
                        // 如果時間未啟用，保持taskDate不變
                        
                        // 根據選擇的日期更新滑匡的日期視圖位置
                        // 計算所選日期與當前日期的差異天數
                        let calendar = Calendar.current
                        let today = calendar.startOfDay(for: Date())
                        let selectedDay = calendar.startOfDay(for: selectedDate)
                        
                        if let dayDifference = calendar.dateComponents([.day], from: today, to: selectedDay).day {
                            // 更新當前塊索引以反映選擇的日期
                            // 0:備忘錄，1:今天，2+:未來日期
                            if dayDifference == 0 {
                                currentBlockIndex = 1 // 今天
                            } else if dayDifference > 0 {
                                currentBlockIndex = dayDifference + 1 // 未來日期
                            } else {
                                currentBlockIndex = 1 // 默認為今天
                            }
                                        }
                        
                        // 設置日期狀態，保持時間狀態不變
                        isDateEnabled = true
                        // isTimeEnabled 保持從 AddTimeView 傳回的狀態
                        
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
        // 添加 onAppear 處理，確保根據初始模式設置正確的狀態
        .onChange(of: currentBlockIndex) { oldValue, newValue in
            updateDateFromBlockIndex()
        }
        // Add.swift
        .onAppear {
            // 確保日期/時間狀態與初始索引同步
            // 使用 DispatchQueue.main.async 確保在視圖佈局後執行
            DispatchQueue.main.async {
                updateDateFromBlockIndex()
            }
        }
        // Move the fullScreenCover for AddNote outside the main view structure
        .fullScreenCover(isPresented: $showAddNoteView) {
            AddNote(noteText: note) { savedNote in
                // 只保存note資料，但不顯示在輸入框中
                note = savedNote
                
                // 更新筆記狀態標記
                hasNote = !note.isEmpty
                
                showAddNoteView = false
                
            }
        }
    }
    
    // 添加新任務並保存到本地和雲端
    func saveToCloudKit() {
        guard !displayText.isEmpty else {
            return
        }

        let now = Date()

        // 多重防重複檢查
        // 1. 檢查標題是否為空
        guard !displayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        // 2. 檢查是否正在保存
        guard !isSaving else {
            return
        }

        // 3. 檢查時間間隔防護
        guard now.timeIntervalSince(lastSubmissionTime) >= minimumSubmissionInterval else {
            return
        }

        // 4. 生成唯一任務ID並檢查是否有重複任務正在處理
        let taskId = "\(displayText)_\(Int(now.timeIntervalSince1970))"
        guard currentTaskId != taskId else {
            return
        }

        // 5. 使用原子操作設置狀態
        DispatchQueue.main.async {
            // 再次檢查，確保在異步執行時狀態沒有改變
            guard !self.isSaving else {
                return
            }

            // 立即設置所有保護狀態
            self.isSaving = true
            self.lastSubmissionTime = now
            self.currentTaskId = taskId


            // 設置超時保護，10秒後自動重置保存狀態
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                if self.isSaving && self.currentTaskId == taskId {
                    self.isSaving = false
                    self.currentTaskId = nil
                }
            }

            // 執行實際的保存邏輯
            self.performSave(taskId: taskId)
        }
    }

    // 分離出實際的保存邏輯
    private func performSave(taskId: String) {
        // 驗證任務ID是否仍然有效
        guard currentTaskId == taskId else {
            return
        }

        // 根據當前模式和時間啟用狀態來決定最終的日期時間
        var finalTaskDate: Date?

        // MARK: - MODIFIED: 修正時間顯示邏輯
        if currentBlockIndex == 0 && !isTimeEnabled {
            // 備忘錄模式且沒有啟用時間 - 日期設為 nil
            finalTaskDate = nil
        } else if isTimeEnabled {
            // 有啟用時間才使用完整的selectedDate（包含日期和時間）
            finalTaskDate = selectedDate
        } else if isDateEnabled {
            // 有啟用日期但沒有啟用時間：使用日期但清除時間部分
            let calendar = Calendar.current
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
            finalTaskDate = calendar.date(from: dateComponents)
        } else {
            // 都沒啟用的情況（理論上不應該發生）
            finalTaskDate = nil
        }

        // 🆕 判斷新的任務類型和完成狀態
        let (taskType, completionStatus): (TaskType, CompletionStatus)
        if let editingItem = editingItem {
            // 編輯模式：保持原有類型和狀態
            taskType = editingItem.taskType
            completionStatus = editingItem.completionStatus
        } else {
            // 新增模式：根據是否有日期決定類型
            if finalTaskDate != nil {
                taskType = .scheduled // 有日期時間的事件
            } else {
                taskType = .memo // 備忘錄（用戶主動創建）
            }
            completionStatus = .pending // 新任務都是待完成
        }

        // 🔄 向後兼容：推導舊狀態
        let taskStatus: TodoStatus = editingItem?.status ??
            (taskType == .memo ? .toDoList : .toBeStarted)

        // ✅ 根據是否為編輯模式決定使用哪個 ID 和創建時間
        let itemId = editingItem?.id ?? UUID()
        let createdAt = editingItem?.createdAt ?? Date()

        // 獲取當前用戶ID
        let appleUserID = UserDefaults.standard.string(forKey: "appleAuthorizedUserId")
        let googleUserID = UserDefaults.standard.string(forKey: "googleAuthorizedUserId")
        let currentUserID = appleUserID ?? googleUserID ?? "unknown_user"

        // 創建或更新 TodoItem
        let taskToSave = TodoItem(
            id: itemId,  // ✅ 編輯時使用原 ID，新增時創建新 ID
            userID: editingItem?.userID ?? currentUserID,
            title: displayText,
            priority: priority,
            isPinned: isPinned,
            taskDate: finalTaskDate,
            note: note,
            taskType: taskType, // 🆕 新的任務類型
            completionStatus: completionStatus, // 🆕 新的完成狀態
            status: taskStatus, // 🔄 向後兼容
            createdAt: createdAt,  // ✅ 編輯時保持原創建時間
            updatedAt: Date(),     // 更新時間總是當前時間
            correspondingImageID: editingItem?.correspondingImageID ?? ""
        )
        
        // 使用 API 伺服器保存待辦事項
        
        if let originalEditingItem = editingItem {
            // ✅ 編輯模式：添加樂觀更新
            // 1. 立即更新本地 toDoItems 中的對應項目
            if let index = toDoItems.firstIndex(where: { $0.id == originalEditingItem.id }) {
                toDoItems[index] = taskToSave
            }

            // 2. 立即重置保存狀態並關閉視圖
            self.isSaving = false
            self.currentTaskId = nil
            if let onClose = self.onClose {
                onClose()
            }

            // 3. 在背景執行API更新
            Task {
                do {
                    let updatedItem = try await APIDataManager.shared.updateTodoItem(taskToSave)
                    await MainActor.run {
                        // 4. 用API返回的實際數據替換樂觀更新的數據
                        if let index = self.toDoItems.firstIndex(where: { $0.id == originalEditingItem.id }) {
                            self.toDoItems[index] = updatedItem
                        }
                    }
                } catch {
                    await MainActor.run {
                        // 5. 回滾樂觀更新：恢復原始項目數據
                        if let index = self.toDoItems.firstIndex(where: { $0.id == originalEditingItem.id }) {
                            self.toDoItems[index] = originalEditingItem
                        }

                        // 6. 顯示錯誤提示（可選）
                        // 注意：這裡不能直接設置self.saveError，因為視圖已關閉
                        // 可以通過通知系統顯示錯誤
                        NotificationCenter.default.post(
                            name: Notification.Name("TodoItemUpdateFailed"),
                            object: nil,
                            userInfo: ["error": error.localizedDescription]
                        )
                    }
                }
            }
        } else {
            // ✅ 新增模式：添加新項目 - 樂觀更新

            // 1. 立即關閉視圖並通知父視圖樂觀新增
            self.isSaving = false
            self.currentTaskId = nil

            if let onOptimisticAdd = self.onOptimisticAdd {
                onOptimisticAdd(taskToSave)  // 傳遞新建的任務讓 Home 立即顯示
            } else if let onClose = self.onClose {
                onClose()  // 備用方案
            }

            // 2. 在背景發送 API 請求
            Task {
                do {
                    let newItem = try await APIDataManager.shared.addTodoItem(taskToSave)

                    // 3. 通知 Home 更新實際的 API 數據
                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: Notification.Name("TodoItemApiSyncCompleted"),
                            object: nil,
                            userInfo: [
                                "item": newItem,
                                "operation": "add",
                                "tempId": taskToSave.id  // 傳遞臨時ID用於匹配樂觀更新的項目
                            ]
                        )
                    }
                } catch {

                    // 4. 如果 API 失敗，通知 Home 撤回樂觀更新
                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: Notification.Name("TodoItemOptimisticUpdateFailed"),
                            object: nil,
                            userInfo: ["tempId": taskToSave.id, "operation": "add", "error": error.localizedDescription]
                        )
                    }
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
        Add(toDoItems: $mockItems, initialMode: .today, initialDate: Date()) {
             // 空的關閉回調
         }
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
//          keyboardHeight = keyboardFrame.height - 30 // 減去一些高度，避免過大的空白
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
