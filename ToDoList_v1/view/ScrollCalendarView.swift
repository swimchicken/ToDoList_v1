import SwiftUI

struct ScrollCalendarView: View {
    // 初始顯示的總天數
    private let initialDays = 60

    // 動態管理天數的狀態
    @State private var totalDays = 60
    @State private var selectedDay = 0 // 0=備忘錄, 1=TODAY, 2=Tomorrow...
    
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
                    // 初始顯示「備忘錄」區塊
                    proxy.scrollTo(0, anchor: .center)
                }
            }
        }
        .scrollTargetBehavior(.viewAligned)
        .frame(height: 60)
    }
    
    // 單日區塊
    struct DayBlock: View {
        let dayIndex: Int
        
        var body: some View {
            // 取得區塊內容
            let blockInfo = getBlockInfo(for: dayIndex)
            
            return ZStack {
                // 背景矩形
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: 329, height: 51)
                    .background(Color(red: 0.85, green: 0.85, blue: 0.85))
                    .cornerRadius(8)
                    .opacity(0.15)
                
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
            ScrollCalendarView()
        }
    }
}
