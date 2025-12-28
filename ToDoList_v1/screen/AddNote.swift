import SwiftUI
import UIKit

// 自定義TextEditor，完全沒有鍵盤工具欄
struct CustomTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var isTextEditorFocused: Bool
    
    var font: UIFont = UIFont.preferredFont(forTextStyle: .body)
    var textColor: UIColor = .white
    
    func makeUIView(context: Context) -> UITextView {
        let textView = NoToolbarTextView()
        textView.delegate = context.coordinator
        textView.font = font
        textView.textColor = textColor
        textView.autocapitalizationType = .sentences
        textView.backgroundColor = .clear
        textView.keyboardAppearance = .dark  // 強制深色鍵盤
        textView.text = text
        textView.isScrollEnabled = true  // 確保可以滾動
        
        // 為了防止文本視圖嘗試處理整個屏幕的觸摸事件
        textView.isUserInteractionEnabled = true
        
        // 完全移除inputAccessoryView
        textView.inputAccessoryView = nil
        
        // 設置自定義屬性以防止自動獲取焦點
        textView.isAutomaticKeyboardToggleEnabled = false
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
        
        // 啟用自動獲取焦點的功能，以便能夠正常響應焦點變化
        let textView = uiView as? NoToolbarTextView
        textView?.isAutomaticKeyboardToggleEnabled = true
        
        // 處理焦點狀態
        if isTextEditorFocused && !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isTextEditorFocused && uiView.isFirstResponder {
            uiView.resignFirstResponder()
            
            // 禁用自動獲取焦點功能，以防止點擊後自動獲取焦點
            textView?.isAutomaticKeyboardToggleEnabled = false
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: CustomTextEditor
        
        init(_ parent: CustomTextEditor) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isTextEditorFocused = true
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            parent.isTextEditorFocused = false
        }
    }
}

// 自定義UITextView子類，覆蓋inputAccessoryView屬性確保它總是為nil
class NoToolbarTextView: UITextView {
    // 必須使用可讀寫屬性來覆蓋
    private var _inputAccessoryView: UIView? = nil
    
    // 自定義屬性，用於控制自動鍵盤切換行為
    var isAutomaticKeyboardToggleEnabled: Bool = true
    
    // 始終返回nil，無論如何都不會顯示輸入工具欄
    override var inputAccessoryView: UIView? {
        get {
            // 即使被系統設置，也始終返回nil
            return nil
        }
        set {
            // 忽略設置操作
            _inputAccessoryView = nil
        }
    }
    
    // 覆蓋重新加載輸入視圖的方法
    override func reloadInputViews() {
        // 先確保inputAccessoryView為nil
        inputAccessoryView = nil
        // 然後調用super方法
        super.reloadInputViews()
    }
    
    override var canBecomeFirstResponder: Bool {
        // 只有在允許自動獲取焦點時才返回true
        return isAutomaticKeyboardToggleEnabled
    }
    
    // 覆蓋觸摸事件處理，防止文本視圖自動取得焦點
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isAutomaticKeyboardToggleEnabled {
            super.touchesBegan(touches, with: event)
        } else {
            // 如果點擊了文本本身，則允許編輯，否則忽略觸摸事件
            let touch = touches.first
            let position = touch?.location(in: self)
            
            if position != nil && position!.y > 0 && position!.y < self.bounds.height && 
               self.text.count > 0 && self.layoutManager.characterIndex(for: position!, 
               in: self.textContainer, fractionOfDistanceBetweenInsertionPoints: nil) < self.text.count {
                super.touchesBegan(touches, with: event)
            }
        }
    }
}

struct AddNote: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var noteText: String
    @State private var isTextEditorFocused: Bool = false
    @State private var isKeyboardVisible = false
    
    // Callback closure to pass the text back to the parent view
    var onSave: (String) -> Void
    
    // Initialize with existing note text and save callback
    init(noteText: String = "", onSave: @escaping (String) -> Void) {
        _noteText = State(initialValue: noteText)
        self.onSave = onSave
    }
    
    // 用於點擊處理的函數，強制隱藏鍵盤
    func dismissKeyboard() {
        print("嘗試隱藏鍵盤") // 調試用
        
        // 確保當前不處於重新獲取焦點的過程中
        guard isTextEditorFocused else { return }
        
        isTextEditorFocused = false
        isKeyboardVisible = false
        
        // 使用多種方法確保鍵盤被隱藏
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        // 使用強制方法確保編輯狀態結束
        UIApplication.shared.windows.first?.rootViewController?.view.endEditing(true)
    }
    
    var body: some View {
        ZStack {
            // 處理背景點擊的透明層 - 點擊空白處隱藏鍵盤
            Color.black
                .edgesIgnoringSafeArea(.all)
                .contentShape(Rectangle())  // 確保整個區域都可以接收點擊
                .onTapGesture {
                    // 點擊背景時隱藏鍵盤
                    dismissKeyboard()
                }
            
            // 固定佈局，不受鍵盤的影響
            ScrollView {
                VStack(spacing: 0) {
                    // 標題部分 - 固定頂部
                    HStack {
                        Text("common.note")
                            .font(.system(size: 26))
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.top, 12)
                            .padding(.leading, 16)
                        Spacer()
                    }
                    .contentShape(Rectangle())  // 確保標題區域可以接收點擊
                    .onTapGesture {
                        // 點擊標題時也隱藏鍵盤
                        dismissKeyboard()
                    }
                    .padding(.bottom, 12)
                    
                    // 文字編輯區域 - 固定位置不變，不受鍵盤影響
                    ZStack {
                        // 添加一個透明的捕捉點擊的背景層
                        Color.black.opacity(0.01)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                dismissKeyboard()
                            }
                        
                        // 實際的文字編輯器，固定高度
                        CustomTextEditor(text: $noteText, isTextEditorFocused: $isTextEditorFocused)
                            .frame(height: 300) // 給予足夠的固定高度
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(8)
                            .onChange(of: isTextEditorFocused) { focused in
                                // 不使用動畫，以防止位置變化
                                isKeyboardVisible = focused
                            }
                    }
                    .padding(.horizontal, 16)
                    
                    // 文字區域之後的固定空白區
                    Spacer(minLength: 20)
                        .frame(height: 30) // 固定高度
                        .frame(maxWidth: .infinity)
                        .background(Color.black.opacity(0.01))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            dismissKeyboard()
                        }
                }
                .padding(.top, 16)
                .padding(.bottom, 80) // 為底部按鈕留出空間
            }
            .contentShape(Rectangle()) // 確保整個滾動視圖可以接收點擊
            .onTapGesture {
                dismissKeyboard()
            }
            .scrollDisabled(true) // 禁用滾動，保持界面固定
            
            // 底部按鈕 - 固定在底部，只控制可見性而不改變位置
            VStack {
                Spacer() // 將按鈕推到底部
                
                if !isKeyboardVisible {
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("common.back")
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
                            Text("common.save")
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
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissKeyboard()
                    }
                    .background(Color.black.opacity(0.01)) // 幾乎透明的背景
                    .transition(.opacity) // 只改變透明度，不改變位置
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                dismissKeyboard()
            }
        }
        .ignoresSafeArea(.keyboard) // 忽略鍵盤安全區域，防止布局向上推動
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
            // 只有在編輯器被聚焦時才設置鍵盤為可見
            if self.isTextEditorFocused {
                self.isKeyboardVisible = true
                
                // 重新應用鍵盤設置，確保工具欄被隱藏
                DispatchQueue.main.async {
                    UITextView.appearance().inputAccessoryView?.isHidden = true
                    UITextView.appearance().inputAccessoryView?.frame = CGRect.zero
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            // 鍵盤隱藏時，強制設置為不可見和非聚焦
            self.isKeyboardVisible = false
            
            // 避免重新獲取焦點的循環
            DispatchQueue.main.async {
                if !self.isTextEditorFocused {
                    UIApplication.shared.windows.first?.rootViewController?.view.endEditing(true)
                }
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
