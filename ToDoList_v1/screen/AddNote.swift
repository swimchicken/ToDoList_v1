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
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
        
        // 處理焦點狀態
        if isTextEditorFocused && !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isTextEditorFocused && uiView.isFirstResponder {
            uiView.resignFirstResponder()
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
        // 確保此視圖能夠接收焦點
        return true
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
    
    // 用於點擊處理的函數
    func dismissKeyboard() {
        isTextEditorFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
            
            VStack(spacing: 0) {
                // 增加一個隱藏的觸摸區域，用於處理點擊空白區域
                Color.black.opacity(0.01)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissKeyboard()
                    }
                    .frame(height: 0) // 不佔據視覺空間，但會捕捉點擊事件
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
                .contentShape(Rectangle())  // 確保標題區域可以接收點擊
                .onTapGesture {
                    // 點擊標題時也隱藏鍵盤
                    dismissKeyboard()
                }
                
                // 使用自定義TextEditor替代原來的TextEditor
                ZStack {
                    // 背景包裝層，用於接收點擊事件
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // 確保文字輸入區域周圍也能收起鍵盤
                            dismissKeyboard()
                        }
                    
                    VStack {
                        // 實際的文字編輯器，固定高度，使其不佔滿整個可用空間
                        CustomTextEditor(text: $noteText, isTextEditorFocused: $isTextEditorFocused)
                            .frame(height: 200) // 限制高度為固定值，這樣下方區域可以接收點擊
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(8)
                        
                        // 添加一個透明的區域，用於捕獲點擊事件
                        Color.clear
                            .frame(height: 20)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                dismissKeyboard()
                            }
                    }
                        .onChange(of: isTextEditorFocused) { focused in
                            withAnimation {
                                isKeyboardVisible = focused
                            }
                        }
                }
                .padding(.top, 12)
                .padding(.horizontal, 16)
                
                // 文字區域之後的空白區，增加點擊處理
                Spacer(minLength: 10)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissKeyboard()
                    }
                
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
