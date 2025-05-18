import SwiftUI

struct ScrollCalendarView: View {
    @Binding var currentDisplayingIndex: Int // 從 Add.swift 傳入的 currentBlockIndex (保持 Int)
    @State private var internalTotalDays = 60 // 內部管理總天數

    // 創建一個計算屬性來橋接 Binding<Int> 到 Binding<Int?>
    private var scrollableID: Binding<Int?> {
        Binding<Int?>(
            get: {
                // 當 scrollPosition 讀取時，返回 currentDisplayingIndex (作為 Int?)
                return Optional(self.currentDisplayingIndex)
            },
            set: { newOptionalID in
                // 當 scrollPosition 寫入新值時
                if let newID = newOptionalID {
                    // 只有當 scrollPosition 提供一個非 nil 的 ID 時才更新
                    // 並且只有當值確實改變時才更新，以避免潛在的無限循環
                    if self.currentDisplayingIndex != newID {
                        self.currentDisplayingIndex = newID
                    }
                }
                // 如果 newOptionalID 為 nil (例如 ScrollView 未對齊任何特定 ID，
                // 雖然在 .viewAligned 和所有項目都有 ID 的情況下不常見)，
                // 我們選擇不改變 currentDisplayingIndex，因為它在我們的模型中是非可選的。
            }
        )
    }

    var body: some View {
        // ScrollViewReader 可能仍然有用於某些特定情況，但 .scrollPosition 會處理主要滾動同步
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(0...internalTotalDays, id: \.self) { dayIndex in
                        DayBlock(dayIndex: dayIndex)
                            .id(dayIndex) // 確保每個子視圖有唯一 ID
                            .onAppear {
                                if dayIndex >= internalTotalDays - 5 {
                                    internalTotalDays += 30 // 動態加載更多天
                                }
                            }
                    }
                }
                .scrollTargetLayout() // 配合 scrollTargetBehavior
            }
            .scrollTargetBehavior(.viewAligned) // 使滾動停止時對齊到子視圖
            .scrollPosition(id: scrollableID) // << --- 使用橋接的 Binding
            .onAppear {
                // .scrollPosition 應該會處理初始視圖的對齊。
                // 如果在某些情況下初始滾動不符合預期，可以考慮在這裡用 proxy.scrollTo，
                // 但通常情況下 .scrollPosition 會處理好。
                print("📜 ScrollCalendarView onAppear: currentDisplayingIndex is \(currentDisplayingIndex). ScrollView should position to this ID via .scrollPosition.")
            }
            // 如果你仍然需要在 currentDisplayingIndex 從外部改變時 (非用戶滾動導致) 強制滾動，
            // 可以保留 onChange，但要注意與 .scrollPosition 的交互。
            // .onChange(of: currentDisplayingIndex) { oldValue, newValue in
            //     print("📜 ScrollCalendarView currentDisplayingIndex changed externally to \(newValue). Scrolling with proxy.")
            //     proxy.scrollTo(newValue, anchor: .center)
            // }
        }
        .frame(height: 60) // 或你需要的高度
    }

    // DayBlock 結構和 getBlockInfo 方法保持不變
    struct DayBlock: View {
        let dayIndex: Int
        var body: some View {
            let blockInfo = getBlockInfo(for: dayIndex)
            let isMemoBLock = dayIndex == 0
            return ZStack {
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: 329, height: 51)
                    .background(isMemoBLock ? Color.gray : Color(red: 0.85, green: 0.85, blue: 0.85))
                    .cornerRadius(8)
                    .opacity(isMemoBLock ? 0.4 : 0.15)
                HStack {
                    Text(blockInfo.title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.leading, 16)
                    Spacer()
                    if dayIndex == 0 {
                        Text("待辦事項佇列")
                            .foregroundColor(.white)
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.trailing, 10)
                        Image(systemName: "chevron.down")
                            .foregroundColor(.white)
                            .font(.system(size: 14))
                            .padding(.trailing, 16)
                    } else {
                        HStack(spacing: 6) {
                            Text(blockInfo.dateText)
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .semibold))
                            Text(blockInfo.weekdayText)
                                .foregroundColor(.gray)
                                .font(.system(size: 16))
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 10) // This padding seems a bit off, might want to review if it's on all date blocks
                    }
                }
                .frame(width: 329)
            }
        }
        private func getBlockInfo(for dayIndex: Int) -> (title: String, dateText: String, weekdayText: String) {
            if dayIndex == 0 { return ("備忘錄", "", "") }
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let date = calendar.date(byAdding: .day, value: dayIndex - 1, to: today) ?? today
            let isToday = calendar.isDateInToday(date)
            let isTomorrow = calendar.isDateInTomorrow(date)
            let title: String
            if isToday { title = "TODAY" }
            else if isTomorrow { title = "Tomorrow" }
            else { title = "" }
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d"
            let dateText = dateFormatter.string(from: date)
            dateFormatter.dateFormat = "EEEE"
            let weekdayText = dateFormatter.string(from: date)
            return (title, dateText, weekdayText)
        }
    }
}

//// 預覽
//struct HorizontalCalendarView_Previews: PreviewProvider {
//    static var previews: some View {
//        ZStack {
//            Color.black.edgesIgnoringSafeArea(.all)
//            ScrollCalendarView(initialSelectedDay: 0) // 使用明確的參數
//        }
//    }
//}
