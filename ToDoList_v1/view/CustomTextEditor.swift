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
    override var inputAccessoryView: UIView? {
        // 強制總是返回nil，無論系統嘗試設置什麼
        return nil
    }
    
    override var canBecomeFirstResponder: Bool {
        // 確保此視圖能夠接收焦點
        return true
    }
}