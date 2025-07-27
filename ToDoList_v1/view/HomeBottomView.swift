import SwiftUI


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
    let SoundtoText: () -> Void
    
    // 是否處於睡眠模式
    let isSleepMode: Bool
    let alarmTimeString: String
    let dayProgress: Double
    let onSleepButtonTapped: () -> Void
    
    // 新增：錄音狀態管理
    @State private var isRecording = false
    @State private var recordingTimer: Timer?
    @State private var audioLevel: Double = 0.0
    
    // 新增一個狀態來儲存灰色背景框的寬度
    @State private var grayBoxWidth: CGFloat = 0
    
    // 新增狀態來控制文字輸入模式
    @State private var isTextInputMode = false
    @State private var newTodoText = ""
    
    // 新增狀態來控制儲存中的載入動畫
    @State private var isSavingRecording = false
    
    // 新增狀態來控制文字傳送中的載入動畫
    @State private var isSendingText = false
    
    // 建立一個 Namespace 來追蹤動畫元件
    @Namespace private var namespace
    
    var body: some View {
        VStack {
            Spacer()
            
            // 主視圖選擇
            if !isSleepMode {
                // 非睡眠模式
                if isCurrentDay {
                    // 當天顯示
                    currentDayView
                } else {
                    // 非當天顯示
                    otherDayView
                }
            } else {
                // 睡眠模式
                sleepModeView
            }
            
            // 底部間距
            Spacer().frame(height: 20)
        }
        // 將水平邊距應用於整個 VStack，確保所有子視圖的寬度都受到約束
        .padding(.horizontal, 10)
        .animation(.spring(response: 0.3), value: isCurrentDay)
        .animation(.spring(response: 0.3), value: isSleepMode)
    }
    
    // 當天視圖
    private var currentDayView: some View {
        // 使用ZStack确保展開按鈕和外部星号显示在最上层
        ZStack {
            VStack(spacing: 10) {
                // 1. 物理場景 (BumpyCircle 掉落動畫)
                PhysicsSceneWrapper(
                    todoItems: todoItems,
                    refreshToken: refreshToken
                )
                
                // 2. 靜態按鈕區域 (在特殊模式下隱藏)
                ZStack {
                    HStack {
                        // end today 按鈕
                        Button(action: onEndTodayTapped) {
                            if isSyncing {
                                HStack {
                                    Text("同步中...")
                                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .black))
                                }
                                .frame(maxWidth: .infinity)
                            } else {
                                Text("end today")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .font(.custom("Inria Sans", size: 20).weight(.bold))
                        .foregroundColor(.black)
                        .frame(width: 230, height: 60)
                        .background(Color.white)
                        .cornerRadius(40.5)
                        
                        Spacer()
                        
                        // plus 按鈕 - 新增任務
                        Button(action: onAddButtonTapped) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 77)
                                    .fill(Color.gray)
                                    .frame(width: 60, height: 60)
                                Image(systemName: "plus")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                            }
                        }
                        
                        Spacer()
                        
                        // 佔位符
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 60, height: 60)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                // 當進入錄音或文字輸入模式時，隱藏原始按鈕
                .opacity(isRecording || isTextInputMode ? 0 : 1)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 32)
                        .fill(Color.gray.opacity(0.2))
                        .onAppear {
                            self.grayBoxWidth = geometry.size.width
                        }
                        .onChange(of: geometry.size.width) { newWidth in
                            self.grayBoxWidth = newWidth
                        }
                }
            )
            // 將對齊方式改回 .bottomTrailing，確保動畫起點和終點都靠右對齊
            .overlay(alignment: .bottomTrailing) {
                ZStack {
                    if isTextInputMode {
                        TextInputView(
                            namespace: namespace,
                            isTextInputMode: $isTextInputMode,
                            isSending: $isSendingText, // 傳入綁定
                            text: $newTodoText,
                            width: max(60, grayBoxWidth - 20)
                        )
                    } else {
                        // 對齊方式已由 overlay 處理，不再需要 HStack 和 Spacer
                        ExpandableSoundButton(
                            namespace: namespace,
                            isRecording: $isRecording,
                            isTextInputMode: $isTextInputMode,
                            isSaving: $isSavingRecording,
                            audioLevel: audioLevel,
                            onRecordingStart: startRecording,
                            onRecordingEnd: endRecording,
                            expandedWidth: max(60, grayBoxWidth - 20)
                        )
                    }
                }
                .padding(12)
            }
            
            // 顶层：外部星号
            VStack(spacing: 10) {
                PhysicsSceneWrapper(
                    todoItems: todoItems,
                    refreshToken: refreshToken
                )
                .opacity(0)
                
                GeometryReader { geometry in
                    let soundButtonCenterX = geometry.size.width - 42
                    let soundButtonCenterY = 30.0
                    
                    ZStack {
                        Image("Star 12")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .foregroundColor(Color(red: 0, green: 0.72, blue: 0.41))
                            .position(
                                x: soundButtonCenterX + 42,
                                y: soundButtonCenterY - 30
                            )
                        
                        Image("Star 12")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 10, height: 10)
                            .foregroundColor(Color(red: 0, green: 0.72, blue: 0.41))
                            .position(
                                x: soundButtonCenterX + 50,
                                y: soundButtonCenterY - 15
                            )
                    }
                }
                .frame(height: 60)
                .allowsHitTesting(false)
            }
            .padding(12)
        }
        .transition(.opacity.combined(with: .scale))
    }
    
    private func startRecording() {
        isRecording = true
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.1)) {
                audioLevel = Double.random(in: 0.2...1.0)
            }
        }
        print("開始錄音...")
    }
    
    private func endRecording() {
        isSavingRecording = true // 開始儲存
        // 模擬網路或處理延遲
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isRecording = false // 結束錄音狀態，讓按鈕收合
            isSavingRecording = false // 結束儲存狀態
            
            recordingTimer?.invalidate()
            recordingTimer = nil
            audioLevel = 0.0
            
            print("結束錄音...")
            SoundtoText() // 呼叫原始的回調
        }
    }
    
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
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(Color.gray.opacity(0.2))
        )
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
}

// 將 ExpandableSoundButton 簡化，只處理預設和錄音狀態
struct ExpandableSoundButton: View {
    let namespace: Namespace.ID
    @Binding var isRecording: Bool
    @Binding var isTextInputMode: Bool
    @Binding var isSaving: Bool
    
    let audioLevel: Double
    let onRecordingStart: () -> Void
    let onRecordingEnd: () -> Void
    let expandedWidth: CGFloat
    
    @State private var dragLocation: CGPoint = .zero
    @State private var isOverCancelButton = false
    @State private var isOverSendButton = true
    @State private var pressEffectScale: CGFloat = 1.0
    @State private var cancelPressEffectScale: CGFloat = 0.0
    
    @State private var showRecordingContents = false

    private var currentWidth: CGFloat {
        isRecording ? expandedWidth : 60
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30)
                .fill(Color(red: 0, green: 0.72, blue: 0.41))
                .matchedGeometryEffect(id: "aiButton", in: namespace)

            if isRecording {
                if showRecordingContents {
                    recordingView
                }
            } else {
                defaultView
            }
        }
        .frame(width: currentWidth, height: 60)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isRecording)
        .onTapGesture {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isTextInputMode = true
            }
        }
        .gesture(longPressGesture)
        .onChange(of: isRecording) { newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showRecordingContents = true
                }
            } else {
                showRecordingContents = false
            }
        }
    }
    
    // 預設視圖 (星星)
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
    
    // 錄音視圖
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
            .transition(.move(edge: .leading).combined(with: .opacity))
            
            HStack {
                Spacer()
                AudioWaveformView(audioLevel: audioLevel)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .transition(.opacity.combined(with: .scale))
            
            ZStack {
                if isSaving {
                    LoadingIndicatorView()
                } else {
                    // 打勾按鈕的兩種狀態
                    ZStack {
                        // 樣式一 (手指移開時): 綠底白框、白色打勾
                        ZStack {
                            Circle().fill(Color(red: 0, green: 0.72, blue: 0.41))
                            Circle().stroke(Color.white, lineWidth: 1.5)
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(width: 50, height: 50)
                        .opacity(isOverSendButton ? 0 : 1)
                        
                        // 樣式二 (手指按住時): 白底實心、綠色打勾
                        ZStack {
                            Circle().fill(Color.white)
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Color(red: 0, green: 0.72, blue: 0.41))
                        }
                        .frame(width: 50, height: 50)
                        .opacity(isOverSendButton ? 1 : 0)
                        
                        // 按壓光暈效果
                        Circle().fill(Color.white.opacity(0.3)).frame(width: 80, height: 80)
                            .scaleEffect(pressEffectScale)
                            .opacity(isOverSendButton ? 1 : 0)
                    }
                }
            }
            .frame(width: 60, height: 60)
            .transition(.opacity)
        }
        .transition(.opacity)
    }
    
    // 長按手勢
    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .onEnded { _ in
                if !isRecording && !isTextInputMode {
                    onRecordingStart()
                }
            }
            .simultaneously(with: dragGesture)
    }
    
    // 拖動手勢
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if isRecording {
                    dragLocation = value.location
                    let sendButtonFrame = CGRect(x: currentWidth - 60, y: 0, width: 60, height: 60)
                    let cancelButtonFrame = CGRect(x: 0, y: 0, width: 60, height: 60)
                    self.isOverSendButton = sendButtonFrame.contains(value.location)
                    self.isOverCancelButton = cancelButtonFrame.contains(value.location)
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
                }
            }
    }
    
    private func cancelRecording() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isRecording = false
            print("錄音已取消...")
        }
    }
    
    private func completeRecording() {
        // 直接呼叫 onRecordingEnd，由父視圖處理儲存狀態
        onRecordingEnd()
    }
    
    // 新增載入中動畫的視圖，並加上註解
    private struct LoadingIndicatorView: View {
        @State private var isAnimating = false

        var body: some View {
            GeometryReader { geometry in
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                
                ZStack {
                    ForEach(0..<8) { i in
                        Path { path in
                            path.addArc(
                                center: center,
                                radius: 20, // 圓弧半徑
                                startAngle: .degrees(Double(i) * 45 + 1), // 每段弧線的起點
                                endAngle: .degrees(Double(i) * 45 + 20), // 每段弧線的終點
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

// 建立一個新的 TextInputView 來處理文字輸入狀態
struct TextInputView: View {
    let namespace: Namespace.ID
    @Binding var isTextInputMode: Bool
    @Binding var isSending: Bool
    @Binding var text: String
    let width: CGFloat
    @FocusState private var isTextFieldFocused: Bool
    
    @State private var showContents = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30)
                .fill(Color(.systemGray6))
                .matchedGeometryEffect(id: "aiButton", in: namespace)
                .overlay(
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(Color(red: 0, green: 0.72, blue: 0.41), lineWidth: 2)
                        .shadow(color: Color(red: 0, green: 0.72, blue: 0.41).opacity(0.8), radius: 8, x: 0, y: 0)
                        .shadow(color: Color(red: 0, green: 0.72, blue: 0.41).opacity(0.5), radius: 4, x: 0, y: 0)
                )

            if showContents {
                HStack(spacing: 0) {
                    Button(action: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            isTextInputMode = false
                        }
                        isTextFieldFocused = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .frame(width: 60, height: 60)
                    
                    ZStack(alignment: .leading) {
                        // 當不在傳送時，顯示正常的 TextField
                        TextField("輸入待辦事項, 或直接跟 AI 說要做什麼", text: $text)
                            .focused($isTextFieldFocused)
                            .foregroundColor(Color(red: 0, green: 0.72, blue: 0.41))
                            .opacity(isSending ? 0 : 1) // 傳送時隱藏
                        
                        // 當正在傳送時，顯示漸層動畫文字
                        if isSending {
                            AnimatedGradientTextView(text: text)
                        }
                    }
                    
                    // 根據 isSending 狀態決定顯示傳送按鈕還是載入動畫
                    if isSending {
                        TextLoadingIndicatorView()
                            .frame(width: 44, height: 44)
                            .padding(.trailing, 8)
                    } else if !text.isEmpty {
                        Button(action: {
                            // 模擬傳送延遲
                            isSending = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                print("傳送文字: \(text)")
                                text = "" // 清空文字
                                isSending = false
                                isTextInputMode = false // 關閉輸入模式
                                isTextFieldFocused = false
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0, green: 0.72, blue: 0.41))
                                
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                isTextFieldFocused = true
            }
        }
    }
    
    // 新增文字傳送的載入中動畫視圖
    private struct TextLoadingIndicatorView: View {
        @State private var isAnimating = false

        var body: some View {
            // 使用 GeometryReader 獲取視圖的中心點，以確保圓弧圍繞中心繪製
            GeometryReader { geometry in
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                
                ZStack {
                    // 使用 ForEach 繪製四段獨立的圓弧
                    ForEach(0..<4) { i in
                        Path { path in
                            path.addArc(
                                center: center, // 使用計算出的中心點
                                radius: 14, // 圓弧半徑
                                startAngle: .degrees(Double(i) * 90 + 35), // 每段弧線的起點
                                endAngle: .degrees(Double(i) * 90 + 75), // 每段弧線的終點
                                clockwise: false
                            )
                        }
                        .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .foregroundColor(Color(red: 0, green: 0.72, blue: 0.41))
                    }
                }
                // 將旋轉動畫應用於 ZStack，使其原地旋轉
                .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                .onAppear {
                    withAnimation(Animation.linear(duration: 2).repeatForever(autoreverses: false)) {
                        isAnimating = true
                    }
                }
                // 確保 ZStack 填滿 GeometryReader 的空間
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }
}

// 新增一個專門用來顯示漸層動畫文字的視圖
struct AnimatedGradientTextView: View {
    let text: String
    @State private var gradientStartPoint: UnitPoint = .init(x: -1, y: 0.5)
    
    // 彩色漸層
    private let gradientColors = [
        Color.green.opacity(0.7),
        Color.cyan.opacity(0.7),
        Color.blue.opacity(0.7),
        Color.purple.opacity(0.7),
        Color.pink.opacity(0.7),
        Color.green.opacity(0.7) // 結尾顏色與開頭相同，以實現無縫循環
    ]

    var body: some View {
        // 使用與 TextField 相同的字體和顏色，以確保對齊
        Text(text)
            .font(.system(size: 17)) // 假設 TextField 的預設字體大小為 17
            .foregroundColor(.clear) // 先將文字設為透明
            .overlay(
                // 用一個移動的漸層作為覆蓋
                LinearGradient(
                    colors: gradientColors,
                    startPoint: gradientStartPoint,
                    endPoint: .init(x: gradientStartPoint.x + 1, y: 0.5)
                )
                .mask(Text(text).font(.system(size: 17))) // 再用同樣的文字作為遮罩
            )
            .onAppear {
                // 讓漸層從左到右移動，並無限循環
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    gradientStartPoint = .init(x: 1, y: 0.5)
                }
            }
    }
}


// 音頻波形視圖
struct AudioWaveformView: View {
    let audioLevel: Double
    @State private var waveformData: [Double] = Array(repeating: 0.2, count: 20)
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<waveformData.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white)
                    .frame(width: 3, height: max(4, waveformData[index] * 30))
                    .animation(
                        .easeInOut(duration: 0.1)
                        .delay(Double(index) * 0.01),
                        value: waveformData[index]
                    )
            }
        }
        .onChange(of: audioLevel) { newLevel in
            updateWaveform(with: newLevel)
        }
    }
    
    private func updateWaveform(with level: Double) {
        waveformData = Array(waveformData.dropFirst()) + [level]
    }
}
