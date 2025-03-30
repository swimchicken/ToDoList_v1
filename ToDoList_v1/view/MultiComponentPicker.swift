import SwiftUI

struct MultiComponentPicker: UIViewRepresentable {
    @Binding var hour: Int
    @Binding var minute: Int
    @Binding var ampm: Int
    
    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIView(_ uiView: UIPickerView, context: Context) {
        uiView.selectRow(hour - 1, inComponent: 0, animated: false)
        uiView.selectRow(minute, inComponent: 1, animated: false)
        uiView.selectRow(ampm, inComponent: 2, animated: false)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        var parent: MultiComponentPicker
        
        init(_ parent: MultiComponentPicker) {
            self.parent = parent
        }
        
        func numberOfComponents(in pickerView: UIPickerView) -> Int {
            3
        }
        
        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            switch component {
            case 0: return 12  // 1~12
            case 1: return 60  // 0~59
            case 2: return 2   // AM/PM
            default: return 0
            }
        }
        
        // 每個 row 的高度
        func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
            return 60  // 依需求調整
        }
        
        // 自訂字體、顏色等（viewForRow）
        func pickerView(_ pickerView: UIPickerView,
                        viewForRow row: Int,
                        forComponent component: Int,
                        reusing view: UIView?) -> UIView {
            let label = UILabel()
            label.textAlignment = .center
            label.textColor = .white
            label.font = UIFont(name: "Inter-Medium", size: 32.68482)
                ?? UIFont.systemFont(ofSize: 32.68482, weight: .medium)
            
            switch component {
            case 0:
                label.text = "\(row + 1)"  // hour
            case 1:
                label.text = "\(row)"      // minute
            case 2:
                label.text = (row == 0) ? "AM" : "PM"
            default:
                label.text = ""
            }
            return label
        }
        
        func pickerView(_ pickerView: UIPickerView,
                        didSelectRow row: Int,
                        inComponent component: Int) {
            switch component {
            case 0: parent.hour = row + 1
            case 1: parent.minute = row
            case 2: parent.ampm = row
            default: break
            }
        }
    }
}
