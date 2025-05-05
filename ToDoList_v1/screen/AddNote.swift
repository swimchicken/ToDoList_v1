import SwiftUI

struct AddNote: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var noteText: String
    @FocusState private var isTextEditorFocused: Bool
    @State private var isKeyboardVisible = false
    
    // Callback closure to pass the text back to the parent view
    var onSave: (String) -> Void
    
    // Initialize with existing note text and save callback
    init(noteText: String = "", onSave: @escaping (String) -> Void) {
        _noteText = State(initialValue: noteText)
        self.onSave = onSave
        
        // 清除鍵盤工具欄 - 針對SwiftUI的TextEditor
        UITextView.appearance().inputAccessoryView = UIToolbar()
        UITextView.appearance().inputAccessoryView?.isHidden = true
        UITextView.appearance().inputAccessoryView?.isUserInteractionEnabled = false
        UITextView.appearance().inputAccessoryView?.frame = CGRect.zero
    }
    
    var body: some View {
        ZStack {
            // 處理背景點擊的透明層 - 點擊空白處隱藏鍵盤
            Color.black
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    isTextEditorFocused = false
                }
                
            // 隱藏的視圖，用於強制移除鍵盤工具欄 
            TextEditor(text: .constant(""))
                .frame(width: 0, height: 0)
                .opacity(0)
            
            VStack(spacing: 0) {
                // 標題
                HStack {
                    Text("note")
                        .font(.system(size: 26))
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.top, 12)
                        .padding(.leading, 16)
                    Spacer()
                }
                
                // 文字編輯器
                TextEditor(text: $noteText)
                    .foregroundColor(.white)
                    .font(.body)
                    .background(Color.black)
                    .colorScheme(.dark) // 強制深色模式鍵盤
                    .focused($isTextEditorFocused)
                    .onChange(of: isTextEditorFocused) { focused in
                        withAnimation {
                            isKeyboardVisible = focused
                        }
                        
                        // 當獲得焦點時強制隱藏鍵盤工具欄
                        if focused {
                            DispatchQueue.main.async {
                                UITextView.appearance().inputAccessoryView?.isHidden = true
                                UITextView.appearance().inputAccessoryView?.frame = CGRect.zero
                            }
                        }
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 16)
                    // 使編輯器區域不響應背景的點擊事件
                    .allowsHitTesting(true)
                    // 防止點擊事件穿透
                    .contentShape(Rectangle())
                
                Spacer(minLength: 10)
                
                // 底部按鈕 - 只在鍵盤隱藏時顯示
                if !isKeyboardVisible {
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Back")
                                .foregroundColor(.white)
                                .frame(height: 46)
                                .frame(width: 80)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(25)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            saveNote()
                        }) {
                            Text("Save")
                                .font(.system(size: 18, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .foregroundColor(.black)
                                .cornerRadius(25)
                                .frame(width: 200)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // 重要：這會讓整個 VStack 忽略背景點擊事件，允許點擊事件傳遞到最底層的黑色背景
            .contentShape(Rectangle())
            .allowsHitTesting(true)
        }
        .onAppear {
            // 在視圖出現時自動顯示鍵盤
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isTextEditorFocused = true
            }
            
            // 設置鍵盤通知觀察者
            setupKeyboardObservers()
        }
        .onDisappear {
            // 視圖消失時移除鍵盤通知觀察者
            removeKeyboardObservers()
        }
        .preferredColorScheme(.dark)
        .navigationBarHidden(true)
    }
    
    func saveNote() {
        onSave(noteText)
    }
    
    // 設置鍵盤觀察者
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { _ in
            // 重新應用鍵盤設置，確保工具欄被隱藏
            DispatchQueue.main.async {
                UITextView.appearance().inputAccessoryView?.isHidden = true
                UITextView.appearance().inputAccessoryView?.frame = CGRect.zero
            }
            
            withAnimation {
                isKeyboardVisible = true
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            withAnimation {
                isKeyboardVisible = false
            }
        }
    }
    
    // 移除鍵盤觀察者
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

struct AddNoteView_Previews: PreviewProvider {
    static var previews: some View {
        AddNote(onSave: { _ in })
            .preferredColorScheme(.dark)
    }
}
