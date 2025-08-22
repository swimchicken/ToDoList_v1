import SwiftUI

struct MultiComponentPicker: UIViewRepresentable {
    @Binding var hour: Int
    @Binding var minute: Int
    @Binding var ampm: Int
    
    // 無限循環的總行數（足夠大的數字）
    private let infiniteRows = 10000
    
    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator
        
        // 設置初始位置到中間位置，模擬無限循環
        DispatchQueue.main.async {
            let hourMiddle = context.coordinator.infiniteRows / 2
            let minuteMiddle = context.coordinator.infiniteRows / 2
            
            // 計算初始位置，確保顯示正確的值
            let hourOffset = hourMiddle - (hourMiddle % 12) + (hour - 1)
            let minuteOffset = minuteMiddle - (minuteMiddle % 60) + minute
            
            picker.selectRow(hourOffset, inComponent: 0, animated: false)
            picker.selectRow(minuteOffset, inComponent: 1, animated: false)
            picker.selectRow(ampm, inComponent: 2, animated: false)
        }
        
        return picker
    }
    
    func updateUIView(_ uiView: UIPickerView, context: Context) {
        // 如果是內部更新觸發的，跳過重新定位避免衝突
        if context.coordinator.isInternalUpdate {
            context.coordinator.isInternalUpdate = false
            return
        }
        
        // 只在需要時更新，避免無限循環衝突
        let currentHourRow = uiView.selectedRow(inComponent: 0)
        let currentMinuteRow = uiView.selectedRow(inComponent: 1)
        let currentAmPmRow = uiView.selectedRow(inComponent: 2)
        
        let expectedHour = (currentHourRow % 12) + 1
        let expectedMinute = currentMinuteRow % 60
        
        if expectedHour != hour || expectedMinute != minute || currentAmPmRow != ampm {
            let hourMiddle = infiniteRows / 2
            let minuteMiddle = infiniteRows / 2
            
            let hourOffset = hourMiddle - (hourMiddle % 12) + (hour - 1)
            let minuteOffset = minuteMiddle - (minuteMiddle % 60) + minute
            
            uiView.selectRow(hourOffset, inComponent: 0, animated: true)
            uiView.selectRow(minuteOffset, inComponent: 1, animated: true)
            uiView.selectRow(ampm, inComponent: 2, animated: true)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        var parent: MultiComponentPicker
        let infiniteRows = 10000
        private var lastHourRow: Int = -1  // 追蹤上一次小時的行位置
        var isInternalUpdate = false  // 防止內部更新觸發重新定位
        
        init(_ parent: MultiComponentPicker) {
            self.parent = parent
        }
        
        func numberOfComponents(in pickerView: UIPickerView) -> Int {
            3
        }
        
        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            switch component {
            case 0: return infiniteRows  // 無限循環 hours
            case 1: return infiniteRows  // 無限循環 minutes  
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
                // 小時：1-12 循環
                let hour = (row % 12) + 1
                label.text = "\(hour)"
            case 1:
                // 分鐘：00-59 循環，確保兩位數顯示
                let minute = row % 60
                label.text = String(format: "%02d", minute)
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
            case 0:
                // 小時：1-12 循環
                let newHour = (row % 12) + 1
                
                // 檢測 AM/PM 自動切換邏輯
                if lastHourRow != -1 {
                    let shouldSwitchAmPm = checkIfShouldSwitchAmPm(
                        fromRow: lastHourRow,
                        toRow: row,
                        oldHour: parent.hour,
                        newHour: newHour
                    )
                    
                    if shouldSwitchAmPm {
                        isInternalUpdate = true  // 標記為內部更新
                        parent.ampm = parent.ampm == 0 ? 1 : 0
                        DispatchQueue.main.async {
                            pickerView.selectRow(self.parent.ampm, inComponent: 2, animated: true)
                        }
                    }
                }
                
                // 更新追蹤變量
                lastHourRow = row
                parent.hour = newHour
            case 1:
                // 分鐘：0-59 循環
                parent.minute = row % 60
            case 2:
                parent.ampm = row
            default: break
            }
        }
        
        // 檢測是否應該切換 AM/PM
        private func checkIfShouldSwitchAmPm(fromRow: Int, toRow: Int, oldHour: Int, newHour: Int) -> Bool {
            // 正確的 AM/PM 切換邏輯：
            // 只有在 11 ↔ 12 之間移動時才切換 AM/PM
            // 12 ↔ 1 之間移動時不切換（同一個時段內）
            
            // 檢測 11 ↔ 12 的切換
            if (oldHour == 11 && newHour == 12) || (oldHour == 12 && newHour == 11) {
                return true
            }
            
            // 檢測跨越多個小時但經過 11→12 邊界的情況
            let rowDifference = toRow - fromRow
            if abs(rowDifference) > 1 {
                // 向前滾動：檢查是否跨越了 11→12 邊界
                if rowDifference > 0 {
                    // 檢查路徑是否包含 11→12 的切換
                    if oldHour <= 11 && newHour >= 12 {
                        // 進一步檢查是否真的跨越了 11→12 邊界
                        let oldPosition = fromRow % 12
                        let newPosition = toRow % 12
                        
                        // 如果從 ≤10 的位置到 ≥11 的位置，表示跨越了 11→12
                        if oldPosition <= 10 && newPosition >= 11 {
                            return true
                        }
                        // 或者跨越了整個 12 小時週期
                        if newPosition < oldPosition {
                            return true
                        }
                    }
                }
                // 向後滾動：檢查是否跨越了 12→11 邊界
                else if rowDifference < 0 {
                    if oldHour >= 12 && newHour <= 11 {
                        let oldPosition = fromRow % 12
                        let newPosition = toRow % 12
                        
                        // 如果從 ≥11 的位置到 ≤10 的位置，表示跨越了 12→11
                        if oldPosition >= 11 && newPosition <= 10 {
                            return true
                        }
                        // 或者跨越了整個 12 小時週期
                        if newPosition > oldPosition {
                            return true
                        }
                    }
                }
            }
            
            return false
        }
    }
}
