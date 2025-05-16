import SwiftUI

struct ScrollCalendarView: View {
    // 初始顯示的總天數
    private let initialDays = 60

    // 動態管理天數的狀態
    @State private var totalDays = 60
    @State private var selectedDay: Int = 0 // 預設為備忘錄
    
    // 使用更簡潔的初始化方法
    init() {
        // 使用默認值 0 (備忘錄)
        self._selectedDay = State(initialValue: 0)
    }
    
    // 帶參數的初始化方法
    init(initialSelectedDay: Int) {
        self._selectedDay = State(initialValue: initialSelectedDay)
    }
    
    var body: some View {
        // 主視圖容器
        VStack {
            // 使用ScrollViewReader包裝ScrollView
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    // 使用LazyHStack以提高效能
                    LazyHStack(spacing: 8) {
                        // 生成所有日期區塊
                        ForEach(0...totalDays, id: \.self) { dayIndex in
                            DayBlock(dayIndex: dayIndex)
                                .id(dayIndex) // 重要：設置ID以便滾動定位
                                .onAppear {
                                    // 當接近最右邊時，動態增加更多日期
                                    if dayIndex >= totalDays - 5 {
                                        totalDays += 30 // 每次增加30天
                                    }
                                }
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, 20)
                }
                .onAppear {
                    // 根據初始選擇日期滾動到相應位置
                    print("📜 ScrollCalendarView onAppear: 正準備滾動到 \(selectedDay) 位置")
                    
                    // 強制更新 selectedDay 為當前指定的初始值
                    // 這裡我們不需要再引用 initialSelectedDay 了，因為 selectedDay 值已經在初始化時設置好
                    
                    // 使用多層延遲確保視圖已經完全加載並刷新
                    DispatchQueue.main.async {
                        print("📜 第一層異步: selectedDay = \(selectedDay)")
                        // 這裡不需要再設置 selectedDay
                        
                        // 延遲 0.1 秒滾動（確保視圖已經完全加載）
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            print("📜 第二層延遲: 正在滾動到 \(selectedDay) 位置")
                            
                            // 直接滾動到 selectedDay 位置
                            withAnimation {
                                proxy.scrollTo(selectedDay, anchor: .center)
                            }
                            
                            // 延遲 0.3 秒再次檢查
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                print("📜 最終確認: selectedDay = \(selectedDay)")
                                // 最後一次確認滾動位置
                                withAnimation {
                                    proxy.scrollTo(selectedDay, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
        }
        .scrollTargetBehavior(.viewAligned)
        .frame(height: 60)
//        .padding(.horizontal, 8)
    }
    
    // 單日區塊
    struct DayBlock: View {
        let dayIndex: Int
        
        var body: some View {
            // 取得區塊內容
            let blockInfo = getBlockInfo(for: dayIndex)
            
            // 確保備忘錄區塊更明顯區分
            let isMemoBLock = dayIndex == 0
            
            return ZStack {
                // 背景矩形 - 備忘錄區塊使用不同的顏色
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: 329, height: 51)
                    .background(isMemoBLock ? Color(red: 0, green: 0.72, blue: 0.41).opacity(0.3) : Color(red: 0.85, green: 0.85, blue: 0.85))
                    .cornerRadius(8)
                    .opacity(isMemoBLock ? 0.4 : 0.15)
                
                // 內容
                HStack {
                    // 左側標題
                    Text(blockInfo.title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.leading, 16)
                    
                    Spacer()
                    
                    // 右側資訊
                    if dayIndex == 0 { // 備忘錄
                        Text("待辦事項佇列")
                            .foregroundColor(.white)
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.trailing, 10)
                        
                        Image(systemName: "chevron.down")
                            .foregroundColor(.white)
                            .font(.system(size: 14))
                            .padding(.trailing, 16)
                    } else { // 日期區塊
                        HStack(spacing: 6) {
                            Text(blockInfo.dateText)
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .semibold))
                            
                            Text(blockInfo.weekdayText)
                                .foregroundColor(.gray)
                                .font(.system(size: 16))
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 10)
                    }
                }
                .frame(width: 329)
            }
        }
        
        // 根據索引取得區塊資訊
        private func getBlockInfo(for dayIndex: Int) -> (title: String, dateText: String, weekdayText: String) {
            // 備忘錄
            if dayIndex == 0 {
                return ("備忘錄", "", "")
            }
            
            // 計算日期
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let date = calendar.date(byAdding: .day, value: dayIndex - 1, to: today) ?? today
            
            // 檢查是否是今天或明天
            let isToday = calendar.isDateInToday(date)
            let isTomorrow = calendar.isDateInTomorrow(date)
            
            // 設定標題
            let title: String
            if isToday {
                title = "TODAY"
            } else if isTomorrow {
                title = "Tomorrow"
            } else {
                title = "" // 其他日期無標題
            }
            
            // 格式化日期
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d" // 例如：Jan 12
            let dateText = dateFormatter.string(from: date)
            
            // 星期幾
            dateFormatter.dateFormat = "EEEE" // 例如：Tuesday
            let weekdayText = dateFormatter.string(from: date)
            
            return (title, dateText, weekdayText)
        }
    }
}

// 預覽
struct HorizontalCalendarView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            ScrollCalendarView(initialSelectedDay: 0) // 使用明確的參數
        }
    }
}
