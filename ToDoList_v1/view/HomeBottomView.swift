import SwiftUI

// MARK: - UI Helpers

/// 鍵盤監聽器，用於讀取鍵盤高度並觸發更新
struct KeyboardReadable: ViewModifier {
    @Binding var keyboardHeight: CGFloat

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                guard let userInfo = notification.userInfo,
                      let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                // 使用動畫來更新高度，使變化更平滑
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.5)) {
                    self.keyboardHeight = keyboardFrame.height
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.5)) {
                    self.keyboardHeight = 0
                }
            }
    }
}

extension View {
    /// 一個方便的方法來應用鍵盤監聽修飾符
    func keyboardReadable(height: Binding<CGFloat>) -> some View {
        self.modifier(KeyboardReadable(keyboardHeight: height))
    }
}

// MARK: - Main View

/// 主頁底部視圖：包含物理場景和按鈕
struct HomeBottomView: View {
    // 數據屬性
    let todoItems: [TodoItem]
    let refreshToken: UUID
    let isCurrentDay: Bool
    let isSyncing: Bool
    
    // 回調
    let onEndTodayTapped: () -> Void
    let onReturnToTodayTapped: () -> Void
    let onAddButtonTapped: () -> Void
    let onError: (String) -> Void
    let onTasksReceived: ([TodoItem]) -> Void
    
    // 是否處於睡眠模式
    let isSleepMode: Bool
    let alarmTimeString: String
    let dayProgress: Double
    let onSleepButtonTapped: () -> Void
    
    // 狀態管理
    @State private var isRecording = false
    @State private var grayBoxWidth: CGFloat = 0
    @State private var isTextInputMode = false
    @State private var newTodoText = ""
    @State private var isSavingRecording = false
    @State private var isSendingText = false
    
    
    @Namespace private var namespace
    
    @State private var keyboardHeight: CGFloat = 0
    
    // 管理器
    @StateObject private var speechManager = SpeechManager()
    @StateObject private var geminiService = GeminiService() // 新增 Gemini 服務
    
    var body: some View {
        ZStack {
            VStack {
                Spacer()
                
                if !isSleepMode {
                    if isCurrentDay {
                        currentDayView
                    } else {
                        otherDayView
                    }
                } else {
                    sleepModeView
                }
                
                Spacer().frame(height: 20)
            }
            
        }
        .padding(.horizontal, 10)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .keyboardReadable(height: $keyboardHeight)
        .animation(.spring(response: 0.3), value: isCurrentDay)
        .animation(.spring(response: 0.3), value: isSleepMode)
        .onAppear {
            speechManager.requestPermissions()
        }
    }
    
    // 當天視圖
    private var currentDayView: some View {
        ZStack {
            // 圖層 1: 固定的背景和靜態按鈕
            VStack(spacing: 10) {
                PhysicsSceneWrapper(
                    todoItems: todoItems,
                    refreshToken: refreshToken
                )
                
                // 靜態按鈕區域
                ZStack {
                    HStack {
                        Button(action: onEndTodayTapped) {
                            if isSyncing {
                                HStack { Text("同步中..."); ProgressView() }
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("end today").frame(maxWidth: .infinity)
                            }
                        }
                        .font(.custom("Inria Sans", size: 20).weight(.bold))
                        .foregroundColor(.black)
                        .frame(width: 230, height: 60)
                        .background(Color.white)
                        .cornerRadius(40.5)
                        
                        Spacer()
                        
                        Button(action: onAddButtonTapped) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 77).fill(Color.gray)
                                Image(systemName: "plus").foregroundColor(.white)
                            }
                            .frame(width: 60, height: 60)
                        }
                        
                        Spacer()
                        
                        Rectangle().fill(Color.clear).frame(width: 60, height: 60)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .opacity(isRecording || isTextInputMode ? 0 : 1)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 32)
                        .fill(Color.gray.opacity(0.2))
                        .onAppear { self.grayBoxWidth = geometry.size.width }
                        .onChange(of: geometry.size.width) { self.grayBoxWidth = $0 }
                }
            )
            .overlay(alignment: .bottomTrailing) {
                let bottomPadding: CGFloat = -10
                let offset = (isTextInputMode && keyboardHeight > 0) ? -keyboardHeight + safeAreaInsets.bottom - bottomPadding : 0
                
                // 圖層 2: 會移動的元件 (輸入框 + 星星)
                ZStack(alignment: .bottomTrailing) {
                    // 星星
                    VStack(spacing: 10) {
                        Spacer()
                        GeometryReader { geometry in
                            let soundButtonCenterX = geometry.size.width - 42
                            let soundButtonCenterY = 30.0
                            
                            ZStack {
                                Image("Star 12")
                                    .renderingMode(.template).resizable().scaledToFit()
                                    .frame(width: 18, height: 18)
                                    .foregroundColor(Color(red: 0, green: 0.72, blue: 0.41))
                                    .position(x: soundButtonCenterX + 42, y: soundButtonCenterY - 30)
                                
                                Image("Star 12")
                                    .renderingMode(.template).resizable().scaledToFit()
                                    .frame(width: 10, height: 10)
                                    .foregroundColor(Color(red: 0, green: 0.72, blue: 0.41))
                                    .position(x: soundButtonCenterX + 50, y: soundButtonCenterY - 15)
                            }
                        }
                        .frame(height: 60)
                    }
                    .allowsHitTesting(false)
                    
                    // 輸入框 / AI 按鈕
                    ZStack {
                        if isTextInputMode {
                            TextInputView(
                                namespace: namespace,
                                isTextInputMode: $isTextInputMode,
                                isSending: $isSendingText,
                                text: $newTodoText,
                                width: max(60, grayBoxWidth - 20),
                                onSend: { textToSend in
                                    // 這是新的回調，當按下傳送按鈕時觸發
                                    handleSend(text: textToSend)
                                }
                            )
                        } else {
                            ExpandableSoundButton(
                                namespace: namespace,
                                isRecording: $isRecording,
                                isTextInputMode: $isTextInputMode,
                                isSaving: $isSavingRecording,
                                audioLevel: speechManager.audioLevel,
                                onRecordingStart: startRecording,
                                onRecordingEnd: endRecording,
                                onRecordingCancel: cancelRecording,
                                expandedWidth: max(60, grayBoxWidth - 20)
                            )
                        }
                    }
                }
                .padding(12)
                .offset(y: offset)
                .animation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.5), value: offset)
            }
        }
        .transition(.opacity.combined(with: .scale))
    }
    // ... otherDayView and sleepModeView remain the same ...
    private var otherDayView: some View {
        HStack {
            Button(action: onReturnToTodayTapped) {
                if isSyncing {
                    HStack {
                        Text("同步中...")
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .black))
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Text("return to today")
                        .frame(maxWidth: .infinity)
                }
            }
            .font(.custom("Inria Sans", size: 20).weight(.bold))
            .foregroundColor(.black)
            .frame(width: 272, height: 60)
            .background(Color.white)
            .cornerRadius(40.5)
            
            Spacer()
            
            Button(action: onAddButtonTapped) {
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
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 32).fill(Color.gray.opacity(0.2)))
        .transition(.opacity.combined(with: .scale))
    }
    
    private var sleepModeView: some View {
        VStack(spacing: 20) {
            HStack(spacing: 15) {
                Image(systemName: "moon.fill").font(.system(size: 20)).foregroundColor(.white.opacity(0.9))
                    .shadow(color: .white.opacity(0.4), radius: 25, x: 0, y: 0)
                    .shadow(color: .white.opacity(0.7), radius: 15, x: 0, y: 0)
                    .shadow(color: .white, radius: 7, x: 0, y: 0)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle().foregroundColor(Color.gray.opacity(0.35))
                        Rectangle()
                            .frame(width: max(0, geometry.size.width * CGFloat(dayProgress)))
                            .foregroundColor(.white)
                    }
                    .frame(height: 4).cornerRadius(2).clipped()
                }.frame(height: 4)
                Image(systemName: "bell.and.waves.left.and.right").font(.system(size: 16)).foregroundColor(.gray)
                Text(alarmTimeString)
                    .font(Font.custom("Inria Sans", size: 18.62571).weight(.light))
                    .multilineTextAlignment(.center).foregroundColor(.gray)
            }.padding(.top, 20)
            
            HStack(spacing: 10) {
                Button(action: onSleepButtonTapped) {
                    Text("back to sleep mode")
                        .font(.custom("Inria Sans", size: 20).weight(.bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                }
                .frame(width: 272, height: 60)
                .background(Color.white)
                .cornerRadius(40.5)
                
                Button(action: onAddButtonTapped) {
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
            .padding(.bottom, 20)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 32).fill(Color.white.opacity(0.15)))
        .transition(.opacity.combined(with: .scale))
    }
    
    // 輔助屬性，用於獲取底部安全區域的高度
    private var safeAreaInsets: UIEdgeInsets {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .windows
            .first?
            .safeAreaInsets ?? .zero
    }
    
    private func startRecording() {
        isRecording = true
        speechManager.start()
    }
    
    // 修正點：將 endRecording 的邏輯改回先切換到文字模式
    private func endRecording() {
        isSavingRecording = true
        speechManager.stop { recognizedText in
            isSavingRecording = false
            isRecording = false
            
            if !recognizedText.isEmpty {
                // 語音辨識完成後，設定文字並切換到點按模式
                newTodoText = recognizedText
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isTextInputMode = true
                }
            }
        }
    }
    
    private func cancelRecording() {
        speechManager.cancel()
        isRecording = false
    }
    
    // 修改後的 handleSend 函式
    private func handleSend(text: String) {
        guard !text.isEmpty else { return }
        
        isSendingText = true
        /*
        // --- 為了測試，暫時模擬 API 錯誤 ---
            print("🧪 正在模擬 API 錯誤...")

            // 模擬 1.5 秒的網路延遲
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                // 直接手動呼叫 onError 來觸發 Toast
                onError("轉譯錯誤，請再試一次")

                // --- 同時也要記得重設 UI 狀態 ---
                isSendingText = false
                newTodoText = ""
                withAnimation(.spring()) {
                    isTextInputMode = false
                }
            }
        */
        
        geminiService.analyzeText(text) { result in
            // ✨✨✨ 這是修改過的地方 ✨✨✨
            // 現在 result 的 success case 直接就是 [TodoItem]
            switch result {
            case .success(let items):
                print("✅ Gemini API 成功回傳!")
                print("任務總數: \(items.count)")
                
                isSendingText = false
                
                // === 修改的核心：不再設定本地 State，而是呼叫閉包通知 Home ===
                onTasksReceived(items)
                
                newTodoText = ""
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isTextInputMode = false
                }
                
            case .failure(let error):
                print("❌ Gemini API 錯誤: \(error.localizedDescription)")
                
                // 呼叫 onError 閉包來顯示 Toast
                onError("轉譯錯誤，請再試一次")
                
                // 停止傳送狀態
                isSendingText = false
                
                // 清空文字並關閉輸入模式
                newTodoText = ""
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isTextInputMode = false
                }
                
            }
            
        }
        
        
    }
    
    // MARK: - Subviews
    
    struct ExpandableSoundButton: View {
        let namespace: Namespace.ID
        @Binding var isRecording: Bool
        @Binding var isTextInputMode: Bool
        @Binding var isSaving: Bool
        
        let audioLevel: Double
        let onRecordingStart: () -> Void
        let onRecordingEnd: () -> Void
        let onRecordingCancel: () -> Void
        let expandedWidth: CGFloat
        
        @State private var dragLocation: CGPoint = .zero
        @State private var isOverCancelButton = false
        @State private var isOverSendButton = true
        @State private var pressEffectScale: CGFloat = 1.0
        @State private var cancelPressEffectScale: CGFloat = 0.0
        
        @State private var showRecordingContents = false
        
        @State private var recordingHintText: String = ""
        
        private var currentWidth: CGFloat {
            isRecording || isSaving ? expandedWidth : 60
        }
        
        var body: some View {
            ZStack(alignment: .top) {
                Text(recordingHintText)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.7), radius: 5, x: 0, y: 2)
                    .offset(y: -50)
                    .opacity(isRecording && !recordingHintText.isEmpty ? 1 : 0)
                    .animation(.easeInOut, value: recordingHintText)
                    .zIndex(1)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 30)
                        .fill(Color(red: 0, green: 0.72, blue: 0.41))
                        .matchedGeometryEffect(id: "aiButton", in: namespace)
                    
                    if isRecording || isSaving {
                        if showRecordingContents {
                            recordingView
                        }
                    } else {
                        defaultView
                    }
                }
                .frame(width: currentWidth, height: 60)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isRecording || isSaving)
                .onTapGesture {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isTextInputMode = true
                    }
                }
                .gesture(longPressGesture)
                .onChange(of: isRecording) { newValue in
                    if newValue {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            showRecordingContents = true
                        }
                    } else if !isSaving {
                        showRecordingContents = false
                    }
                }
                .onChange(of: isSaving) { newValue in
                    if !newValue {
                        showRecordingContents = false
                    }
                }
            }
        }
        
        private var defaultView: some View {
            ZStack {
                Image("Star 12")
                    .resizable().scaledToFit().frame(width: 20, height: 20)
                    .foregroundColor(.white).offset(x: -4, y: -4)
                Image("Star 12")
                    .resizable().scaledToFit().frame(width: 11, height: 11)
                    .foregroundColor(.white).offset(x: 7, y: 7)
            }
        }
        
        private var recordingView: some View {
            HStack(spacing: 0) {
                Button(action: { cancelRecording() }) {
                    ZStack {
                        ZStack {
                            Circle().stroke(Color.white, lineWidth: 1.5).frame(width: 47, height: 47)
                            Image(systemName: "xmark").font(.system(size: 16, weight: .medium)).foregroundColor(.white)
                        }.opacity(isOverCancelButton ? 0 : 1)
                        ZStack {
                            Circle().fill(Color.white).frame(width: 47, height: 47)
                            Image(systemName: "xmark").font(.system(size: 16, weight: .medium)).foregroundColor(Color(red: 0, green: 0.72, blue: 0.41))
                        }.opacity(isOverCancelButton ? 1 : 0)
                    }
                }
                .frame(width: 60, height: 60)
                .background(
                    Circle().fill(Color.white.opacity(0.3)).frame(width: 80, height: 80)
                        .scaleEffect(cancelPressEffectScale)
                        .opacity(isOverCancelButton ? 1 : 0)
                )
                .opacity(isSaving ? 0 : 1)
                .transition(.move(edge: .leading).combined(with: .opacity))
                
                ZStack {
                    AudioWaveformView(audioLevel: audioLevel, isSaving: $isSaving)
                    if isSaving {
                        LoadingIndicatorView()
                    }
                }
                .frame(maxWidth: .infinity)
                .transition(.opacity.combined(with: .scale))
                
                ZStack {
                    ZStack {
                        ZStack {
                            Circle().fill(Color(red: 0, green: 0.72, blue: 0.41))
                            Circle().stroke(Color.white, lineWidth: 1.5)
                            Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                        }
                        .frame(width: 50, height: 50)
                        .opacity(isOverSendButton ? 0 : 1)
                        
                        ZStack {
                            Circle().fill(Color.white)
                            Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)).foregroundColor(Color(red: 0, green: 0.72, blue: 0.41))
                        }
                        .frame(width: 50, height: 50)
                        .opacity(isOverSendButton ? 1 : 0)
                        
                        Circle().fill(Color.white.opacity(0.3)).frame(width: 80, height: 80)
                            .scaleEffect(pressEffectScale)
                            .opacity(isOverSendButton ? 1 : 0)
                    }
                }
                .frame(width: 60, height: 60)
                .opacity(isSaving ? 0 : 1)
                .transition(.opacity)
            }
            .transition(.opacity)
        }
        
        private var longPressGesture: some Gesture {
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    if !isRecording && !isTextInputMode {
                        onRecordingStart()
                    }
                }
                .simultaneously(with: dragGesture)
        }
        
        private var dragGesture: some Gesture {
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if isRecording {
                        dragLocation = value.location
                        let sendButtonFrame = CGRect(x: currentWidth - 60, y: 0, width: 60, height: 60)
                        let cancelButtonFrame = CGRect(x: 0, y: 0, width: 60, height: 60)
                        
                        self.isOverSendButton = sendButtonFrame.contains(value.location)
                        self.isOverCancelButton = cancelButtonFrame.contains(value.location)
                        
                        if self.isOverCancelButton {
                            self.recordingHintText = "Release to cancel"
                        } else if self.isOverSendButton {
                            self.recordingHintText = "Release to send..."
                        } else {
                            self.recordingHintText = ""
                        }
                        
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            self.pressEffectScale = self.isOverSendButton ? 1.0 : 0.0
                            self.cancelPressEffectScale = self.isOverCancelButton ? 1.0 : 0.0
                        }
                    }
                }
                .onEnded { value in
                    if isRecording {
                        if isOverCancelButton {
                            cancelRecording()
                        } else {
                            completeRecording()
                        }
                        dragLocation = .zero
                        isOverCancelButton = false
                        isOverSendButton = true
                        pressEffectScale = 1.0
                        cancelPressEffectScale = 0.0
                        recordingHintText = ""
                    }
                }
        }
        
        private func cancelRecording() {
            onRecordingCancel()
        }
        
        private func completeRecording() {
            onRecordingEnd()
        }
        
        struct LoadingIndicatorView: View {
            @State private var isAnimating = false
            
            var body: some View {
                GeometryReader { geometry in
                    let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    
                    ZStack {
                        ForEach(0..<8) { i in
                            Path { path in
                                path.addArc(
                                    center: center, radius: 20,
                                    startAngle: .degrees(Double(i) * 45 + 1),
                                    endAngle: .degrees(Double(i) * 45 + 20),
                                    clockwise: false
                                )
                            }
                            .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .foregroundColor(.white)
                        }
                    }
                    .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                    .onAppear {
                        withAnimation(Animation.linear(duration: 2).repeatForever(autoreverses: false)) {
                            isAnimating = true
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
        }
    }
    
    struct TextInputView: View {
        let namespace: Namespace.ID
        @Binding var isTextInputMode: Bool
        @Binding var isSending: Bool
        @Binding var text: String
        let width: CGFloat
        var onSend: (String) -> Void // 新增回調
        
        @FocusState private var isTextFieldFocused: Bool
        @State private var showContents = false
        
        var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color.white)
                    .matchedGeometryEffect(id: "aiButton", in: namespace)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(Color(red: 0, green: 0.72, blue: 0.41), lineWidth: 2)
                            .shadow(color: Color(red: 0, green: 0.72, blue: 0.41).opacity(0.8), radius: 8, x: 0, y: 0)
                            .shadow(color: Color(red: 0, green: 0.72, blue: 0.41).opacity(0.5), radius: 4, x: 0, y: 0)
                    )
                
                if showContents {
                    HStack(spacing: 0) {
                        Button(action: { closeTextInput() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        .frame(width: 60, height: 60)
                        
                        ZStack(alignment: .leading) {
                            TextField("輸入待辦事項, 或直接跟 AI 說要做什麼", text: $text)
                                .focused($isTextFieldFocused)
                                .foregroundColor(Color(red: 0, green: 0.72, blue: 0.41))
                                .opacity(isSending ? 0 : 1)
                            
                            if isSending {
                                AnimatedGradientTextView(text: text)
                            }
                        }
                        
                        if isSending {
                            TextLoadingIndicatorView()
                                .frame(width: 44, height: 44)
                                .padding(.trailing, 8)
                        } else if !text.isEmpty {
                            // 確保按鈕呼叫 onSend 回調
                            Button(action: {
                                onSend(text)
                            }) {
                                ZStack {
                                    Circle().fill(Color(red: 0, green: 0.72, blue: 0.41))
                                    Image(systemName: "arrow.up")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(width: 44, height: 44)
                            .padding(.trailing, 8)
                            .transition(.scale.animation(.spring()))
                        }
                    }
                    .transition(.opacity.animation(.easeIn(duration: 0.3).delay(0.2)))
                }
            }
            .frame(width: width, height: 60)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showContents = true
                }
            }
            .onChange(of: isTextInputMode) { newValue in
                if !newValue {
                    isTextFieldFocused = false
                }
            }
        }
        
        private func closeTextInput() {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isTextInputMode = false
            }
            isTextFieldFocused = false
        }
        
        struct TextLoadingIndicatorView: View {
            @State private var isAnimating = false
            
            var body: some View {
                GeometryReader { geometry in
                    let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    
                    ZStack {
                        ForEach(0..<4) { i in
                            Path { path in
                                path.addArc(
                                    center: center, radius: 14,
                                    startAngle: .degrees(Double(i) * 90 + 35),
                                    endAngle: .degrees(Double(i) * 90 + 75),
                                    clockwise: false
                                )
                            }
                            .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .foregroundColor(Color(red: 0, green: 0.72, blue: 0.41))
                        }
                    }
                    .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                    .onAppear {
                        withAnimation(Animation.linear(duration: 2).repeatForever(autoreverses: false)) {
                            isAnimating = true
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
        }
    }
    
    struct AnimatedGradientTextView: View {
        let text: String
        @State private var gradientStartPoint: UnitPoint = .init(x: -1, y: 0.5)
        
        private let gradientColors = [
            Color.green.opacity(0.7), Color.cyan.opacity(0.7), Color.blue.opacity(0.7),
            Color.purple.opacity(0.7), Color.pink.opacity(0.7), Color.green.opacity(0.7)
        ]
        
        var body: some View {
            Text(text)
                .font(.system(size: 17))
                .foregroundColor(.clear)
                .overlay(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: gradientStartPoint,
                        endPoint: .init(x: gradientStartPoint.x + 1, y: 0.5)
                    )
                    .mask(Text(text).font(.system(size: 17)))
                )
                .onAppear {
                    withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                        gradientStartPoint = .init(x: 1, y: 0.5)
                    }
                }
        }
    }
    
    struct AudioWaveformView: View {
        let audioLevel: Double
        @Binding var isSaving: Bool
        
        private let barCount = 50
        @State private var waveformData: [Double] = Array(repeating: 0, count: 50)
        @State private var savingTimer: Timer?
        
        var body: some View {
            HStack(spacing: 2) {
                ForEach(0..<waveformData.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.white)
                        .frame(width: 3, height: max(4, waveformData[index] * 55))
                }
            }
            .animation(.easeOut(duration: 0.1), value: waveformData)
            .onChange(of: audioLevel) { newLevel in
                if !isSaving {
                    updateWaveform(with: newLevel)
                }
            }
            .onChange(of: isSaving) { newValue in
                if newValue {
                    startDecayAnimation()
                } else {
                    savingTimer?.invalidate()
                    savingTimer = nil
                }
            }
        }
        
        private func updateWaveform(with level: Double) {
            waveformData.append(level)
            if waveformData.count > barCount {
                waveformData.removeFirst()
            }
        }
        
        private func startDecayAnimation() {
            var decaySteps = 20
            savingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                guard decaySteps > 0 else {
                    waveformData = Array(repeating: 0, count: barCount)
                    savingTimer?.invalidate()
                    savingTimer = nil
                    return
                }
                
                let decayFactor = Double(decaySteps) / 20.0
                let newLevel = Double.random(in: 0...0.3) * decayFactor
                updateWaveform(with: newLevel)
                
                decaySteps -= 1
            }
        }
    }

