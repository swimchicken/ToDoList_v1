import SwiftUI

struct CalendarView: View {
    @Binding var toDoItems: [TodoItem]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate = Date()
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var showAddEventSheet = false
    @State private var newEventTitle = ""
    @State private var newEventTime = Date()
    
    // 每週日期標題
    let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    
    // 初始化添加必做事項
    init(toDoItems: Binding<[TodoItem]>) {
        self._toDoItems = toDoItems
        
        // 自動獲取當前月份
        let calendar = Calendar.current
        let currentDate = Date()
        let currentYear = calendar.component(.year, from: currentDate)
        let currentMonth = calendar.component(.month, from: currentDate)
                
        // 指定當月的測試日期
        let date26 = calendar.date(from: DateComponents(year: currentYear, month: currentMonth, day: 26))!
        let date3 = calendar.date(from: DateComponents(year: currentYear, month: currentMonth, day: 3))!
        let date28 = calendar.date(from: DateComponents(year: currentYear, month: currentMonth, day: 28))!

        let date30 = calendar.date(from: DateComponents(year: currentYear, month: currentMonth, day: min(30, calendar.range(of: .day, in: .month, for: currentDate)!.upperBound - 1)))!
                
        // 創建預設事項（使用動態日期）
        let meetingReport = TodoItem(
            id: UUID(), userID: "user123", title: "meeting report", priority: 1, isPinned: true,
            taskDate: date3, note: "\(currentMonth)/3 Meeting Report", status: .toBeStarted,
            createdAt: Date(), updatedAt: Date(), correspondingImageID: ""
        )
        
        let meetingReport2 = TodoItem(
            id: UUID(), userID: "user123", title: "meeting report2", priority: 1, isPinned: true,
            taskDate: date3, note: "\(currentMonth)/3 Meeting Report2", status: .toBeStarted,
            createdAt: Date(), updatedAt: Date(), correspondingImageID: ""
        )
        
        let meetingReport3 = TodoItem(
            id: UUID(), userID: "user123", title: "meeting report3", priority: 1, isPinned: true,
            taskDate: date3, note: "\(currentMonth)/3 Meeting Report3", status: .toBeStarted,
            createdAt: Date(), updatedAt: Date(), correspondingImageID: ""
        )
        
        let meetingReport4 = TodoItem(
            id: UUID(), userID: "user123", title: "meeting report4", priority: 1, isPinned: true,
            taskDate: date30, note: "\(currentMonth)/30 Meeting Report4", status: .toBeStarted,
            createdAt: Date(), updatedAt: Date(), correspondingImageID: ""
        )
        
        let meetingReport5 = TodoItem(
            id: UUID(), userID: "user123", title: "meeting report5", priority: 1, isPinned: true,
            taskDate: date3, note: "\(currentMonth)/3 Meeting Report5", status: .toBeStarted,
            createdAt: Date(), updatedAt: Date(), correspondingImageID: ""
        )
        
        let meetingReport6 = TodoItem(
            id: UUID(), userID: "user123", title: "meeting report6", priority: 1, isPinned: true,
            taskDate: date28, note: "\(currentMonth)/28 Meeting Report6", status: .toBeStarted,
            createdAt: Date(), updatedAt: Date(), correspondingImageID: ""
        )
        
        let meetingReport7 = TodoItem(
            id: UUID(), userID: "user123", title: "meeting report7", priority: 1, isPinned: true,
            taskDate: date28, note: "\(currentMonth)/28 Meeting Report7", status: .toBeStarted,
            createdAt: Date(), updatedAt: Date(), correspondingImageID: ""
        )
                
        let jamOpeningParty = TodoItem(
            id: UUID(), userID: "user123", title: "jam opening party", priority: 1, isPinned: true,
            taskDate: date26, note: "\(currentMonth)/26 Jam Opening Party", status: .toBeStarted,
            createdAt: Date(), updatedAt: Date(), correspondingImageID: ""
        )
                
        let shiroBithdayPartyOpening = TodoItem(
            id: UUID(), userID: "user123", title: "shiro bithday party opening", priority: 1, isPinned: true,
            taskDate: date26, note: "\(currentMonth)/26 shiro bithday party opening", status: .toBeStarted,
            createdAt: Date(), updatedAt: Date(), correspondingImageID: ""
        )
        
        let shiroBithdayPartyEnding = TodoItem(
            id: UUID(), userID: "user123", title: "shiro bithday party ending", priority: 1, isPinned: true,
            taskDate: date26, note: "\(currentMonth)/26 shiro bithday party ending", status: .toBeStarted,
            createdAt: Date(), updatedAt: Date(), correspondingImageID: ""
        )
                
        let meeting27 = TodoItem(
            id: UUID(), userID: "user123", title: "meeting", priority: 1, isPinned: true,
            taskDate: date26, note: "\(currentMonth)/26 meeting", status: .toBeStarted,
            createdAt: Date(), updatedAt: Date(), correspondingImageID: ""
        )
        
        // 將預設事項添加到列表中
        var initialItems = toDoItems.wrappedValue
        
        // 創建所有預設事項的陣列
        let allDefaultItems = [meetingReport, meetingReport2, meetingReport3, meetingReport4,meetingReport5,meetingReport6,meetingReport7, jamOpeningParty, shiroBithdayPartyOpening,shiroBithdayPartyEnding, meeting27]

        // 自動添加不存在的預設事項
        for item in allDefaultItems {
            if !initialItems.contains(where: {
                calendar.isDate($0.taskDate, inSameDayAs: item.taskDate) && $0.title == item.title
            }) {
                initialItems.append(item)
            }
        }

        _toDoItems = Binding(
            get: { initialItems },
            set: { toDoItems.wrappedValue = $0 }
        )
    }
    
    // 獲取月份名稱
    var currentMonthName: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM"
        let date = Calendar.current.date(from: DateComponents(year: selectedYear, month: selectedMonth))!
        return dateFormatter.string(from: date)
    }
    
    // 獲取當前月份的天數
    func daysInMonth(month: Int, year: Int) -> Int {
        let calendar = Calendar.current
        let dateComponents = DateComponents(year: year, month: month)
        let date = calendar.date(from: dateComponents)!
        let range = calendar.range(of: .day, in: .month, for: date)!
        return range.count
    }
    
    // 獲取當前月份第一天的偏移量（即需要多少個空格）
    func calculateFirstDayOffset(month: Int, year: Int) -> Int {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1 // 每月的第一天
        
        guard let firstDayOfMonth = calendar.date(from: components) else { return 0 }
        
        // 獲取星期幾 (1-7，1代表星期日，2代表星期一，以此類推)
        let weekday = calendar.component(.weekday, from: firstDayOfMonth)
        
        // 轉換為我們視圖中的偏移量（0 = 星期一，6 = 星期日）
        let offset = (weekday + 5) % 7
        
        return offset
    }
    
    // 計算上個月需要顯示的天數
    func previousMonthDays() -> [Int] {
        let offset = calculateFirstDayOffset(month: selectedMonth, year: selectedYear)
        
        if offset == 0 { return [] }
        
        // 計算上個月
        let prevMonth = selectedMonth == 1 ? 12 : selectedMonth - 1
        let prevYear = selectedMonth == 1 ? selectedYear - 1 : selectedYear
        
        // 獲取上個月的總天數
        let daysInPrevMonth = daysInMonth(month: prevMonth, year: prevYear)
        
        // 返回上個月需要顯示的日期（從後往前）
        var days: [Int] = []
        for i in 0..<offset {
            days.append(daysInPrevMonth - i)
        }
        return days.reversed()
    }
    
    // 計算下個月需要顯示的天數
    func nextMonthDays() -> [Int] {
        let offset = calculateFirstDayOffset(month: selectedMonth, year: selectedYear)
        let daysInCurrentMonth = daysInMonth(month: selectedMonth, year: selectedYear)
        
        // 計算當前月份佔用的單元格數量
        let occupiedCells = offset + daysInCurrentMonth
        
        // 計算需要從下個月補充的單元格數量（使總數為7的倍數，且至少顯示一行下個月）
        let cellsInRow = 7
        let filledRows = (occupiedCells + cellsInRow - 1) / cellsInRow // 向上取整
        let totalCells = filledRows * cellsInRow
        let neededCells = totalCells - occupiedCells
        
        if neededCells <= 0 {
            // 至少顯示一行下個月
            let extraCells = cellsInRow
            var days: [Int] = []
            for i in 1...extraCells {
                days.append(i)
            }
            return days
        }
        
        // 從下個月第一天開始
        var days: [Int] = []
        for i in 1...neededCells {
            days.append(i)
        }
        return days
    }
    
    // 獲取指定日期的事件
    func eventsForDate(_ day: Int, month: Int, year: Int) -> [TodoItem] {
        let calendar = Calendar.current
        let targetDate = calendar.date(from: DateComponents(year: year, month: month, day: day))!
        
        return toDoItems.filter { item in
            let itemComponents = calendar.dateComponents([.year, .month, .day], from: item.taskDate)
            let itemDate = calendar.date(from: itemComponents)!
            return calendar.isDate(itemDate, inSameDayAs: targetDate)
        }
    }
    
    func eventColor(for day: Int, isCurrentMonth: Bool = true, month: Int? = nil, year: Int? = nil) -> Color {
        if !isCurrentMonth {
            return Color.gray.opacity(0.5) // 非當前月份的日期顯示為淺灰色
        }
        
        let actualMonth = month ?? selectedMonth
        let actualYear = year ?? selectedYear
        
        let calendar = Calendar.current
        let today = Date()
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: today)
        
        // 只有當天的日期為綠色，其餘為灰色
        if todayComponents.day == day &&
           todayComponents.month == actualMonth &&
           todayComponents.year == actualYear {
            return Color.green
        } else {
            return Color.gray.opacity(0.7)
        }
    }
    
    // 簡化版本，用於當前月份
    func eventsForDate(_ day: Int) -> [TodoItem] {
        return eventsForDate(day, month: selectedMonth, year: selectedYear)
    }
    
    // 檢查是否為今天
    func isToday(day: Int, month: Int, year: Int) -> Bool {
        let calendar = Calendar.current
        let today = Date()
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: today)
        
        return todayComponents.day == day &&
               todayComponents.month == month &&
               todayComponents.year == year
    }
    
    // 簡化版本，用於當前月份
    func isToday(day: Int) -> Bool {
        return isToday(day: day, month: selectedMonth, year: selectedYear)
    }
    
    // 檢查日期是否在當前週
    func isInCurrentWeek(day: Int, month: Int, year: Int) -> Bool {
        let calendar = Calendar.current
        let today = Date()
        let targetDate = calendar.date(from: DateComponents(year: year, month: month, day: day))!
        
        let todayWeek = calendar.component(.weekOfYear, from: today)
        let todayYear = calendar.component(.yearForWeekOfYear, from: today)
        
        let targetWeek = calendar.component(.weekOfYear, from: targetDate)
        let targetYear = calendar.component(.yearForWeekOfYear, from: targetDate)
        
        return todayWeek == targetWeek && todayYear == targetYear
    }
    
    // 顏色函數 - 根據事件數量返回顏色
    func dateColor(for day: Int, isCurrentMonth: Bool = true, month: Int? = nil, year: Int? = nil) -> Color {
        if !isCurrentMonth {
            return Color.gray // 非當前月份的日期顯示為灰色
        }
        
        let actualMonth = month ?? selectedMonth
        let actualYear = year ?? selectedYear
        
        let events = eventsForDate(day, month: actualMonth, year: actualYear)
        
        if events.isEmpty {
            return Color.white.opacity(0.7)
        } else if events.contains(where: { $0.priority == 1 }) {
            return Color.green
        } else {
            return Color.green.opacity(0.7)
        }
    }
    
    // 修改：獲取非當前週事件的顯示標題（添加省略號）
    func getAbbreviatedTitle(for title: String) -> String {
        // 取標題的前部分並加上省略號
        return "\(title.prefix(7))..."
    }
    
    // 計算當週所需的高度
    func calculateWeekHeight(for week: [(day: Int, month: Int, year: Int, isCurrentMonth: Bool)], isCurrentWeek: Bool) -> CGFloat {
        var maxEvents = 0
        
        for dayInfo in week {
            let events = eventsForDate(dayInfo.day, month: dayInfo.month, year: dayInfo.year)
            maxEvents = max(maxEvents, events.count)
        }
        
        if isCurrentWeek {
            // 當週：日期高度 + 待辦事項高度（根據事項數量）
            let dateHeight: CGFloat = 45
            let eventBaseHeight: CGFloat = 20  // 每個事項基本高度
            let eventSpacing: CGFloat = 3      // 事項間距
            let padding: CGFloat = 10          // 增加下方padding
            
            let eventsToShow = min(maxEvents, 3)
            let extraText: CGFloat = maxEvents > 3 ? 20 : 0  // 增加 "+x more" 文字高度空間
            
            return dateHeight + CGFloat(eventsToShow) * eventBaseHeight + CGFloat(max(0, eventsToShow - 1)) * eventSpacing + extraText + padding + 5 // 增加額外的5點空間
        } else {
            // 非當週：固定較小高度
            return 69
        }
    }
    
    var body: some View {
        ZStack {
            // 背景
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // 頂部導航欄
                HStack {
                    // 頭像
                    Image("who")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                    
                    Spacer()
                    
                    // 顯示年份和月份
                    HStack(spacing: 5) {
                        Text(currentMonthName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(String(selectedYear))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // 關閉按鈕
                    Button {
                        dismiss()
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 50, height: 50)
                            
                            // 使用系統內建圖標 - 方形勾選符號
                            Image(systemName: "checkmark.square")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal)
                
                // 星期標題
                HStack(spacing: 0) {
                    ForEach(weekdays, id: \.self) { day in
                        Text(day)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal)
                
                // 準備日期數據
                let prevDays = previousMonthDays()
                let daysInCurrentMonth = daysInMonth(month: selectedMonth, year: selectedYear)
                let nextDays = nextMonthDays()
                
                // 所有日期資料
                let allDaysData: [(day: Int, month: Int, year: Int, isCurrentMonth: Bool)] = {
                    var result: [(day: Int, month: Int, year: Int, isCurrentMonth: Bool)] = []
                    
                    // 上個月的日期
                    let prevMonth = selectedMonth == 1 ? 12 : selectedMonth - 1
                    let prevYear = selectedMonth == 1 ? selectedYear - 1 : selectedYear
                    for day in prevDays {
                        result.append((day: day, month: prevMonth, year: prevYear, isCurrentMonth: false))
                    }
                    
                    // 當前月份的日期
                    for day in 1...daysInCurrentMonth {
                        result.append((day: day, month: selectedMonth, year: selectedYear, isCurrentMonth: true))
                    }
                    
                    // 下個月的日期
                    let nextMonth = selectedMonth == 12 ? 1 : selectedMonth + 1
                    let nextYear = selectedMonth == 12 ? selectedYear + 1 : selectedYear
                    for day in nextDays {
                        result.append((day: day, month: nextMonth, year: nextYear, isCurrentMonth: false))
                    }
                    
                    return result
                }()
                
                // 將日期分成每週
                let weeks: [[(day: Int, month: Int, year: Int, isCurrentMonth: Bool)]] = {
                    var result: [[(day: Int, month: Int, year: Int, isCurrentMonth: Bool)]] = []
                    var currentWeek: [(day: Int, month: Int, year: Int, isCurrentMonth: Bool)] = []
                    
                    for (index, dayData) in allDaysData.enumerated() {
                        currentWeek.append(dayData)
                        
                        if currentWeek.count == 7 || index == allDaysData.count - 1 {
                            result.append(currentWeek)
                            currentWeek = []
                        }
                    }
                    
                    // 如果最後一週不足7天，用空白填充
                    while currentWeek.count < 7 && !currentWeek.isEmpty {
                        let nextMonth = selectedMonth == 12 ? 1 : selectedMonth + 1
                        let nextYear = selectedMonth == 12 ? selectedYear + 1 : selectedYear
                        let day = nextDays.count + currentWeek.count
                        currentWeek.append((day: day, month: nextMonth, year: nextYear, isCurrentMonth: false))
                    }
                    
                    if !currentWeek.isEmpty {
                        result.append(currentWeek)
                    }
                    
                    return result
                }()
                
                // 日曆網格
                VStack(spacing: 0) {
                    ForEach(0..<weeks.count, id: \.self) { weekIndex in
                        let week = weeks[weekIndex]
                        
                        // 檢查這一週是否包含今天（即當前週）
                        let containsToday = week.contains { isToday(day: $0.day, month: $0.month, year: $0.year) }
                        
                        // 計算當週所需高度
                        let weekHeight = calculateWeekHeight(for: week, isCurrentWeek: containsToday)
                        
                        // 整週容器
                        ZStack(alignment: .top) {
                            // 如果是當前週，添加背景色
                            if containsToday {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: weekHeight) // 修改：使用計算得到的weekHeight
                            }
                            
                            // 週內容 - 使用VStack確保內容從上到下排列，但使用ZStack進行重疊佈局
                            ZStack(alignment: .top) {
                                // 日期行 - 固定高度
                                HStack(spacing: 0) {
                                    ForEach(0..<week.count, id: \.self) { dayIndex in
                                        let dayInfo = week[dayIndex]
                                        
                                        // 日期區塊 - 所有日期左對齊
                                        Button(action: {
                                            // 處理點擊日期的事件
                                            let date = Calendar.current.date(from: DateComponents(year: dayInfo.year, month: dayInfo.month, day: dayInfo.day))!
                                            selectedDate = date
                                            print("選擇了日期: \(dayInfo.day)/\(dayInfo.month)/\(dayInfo.year)")
                                            
                                            // 在這裡可以添加你需要的其他操作
                                            // 例如：顯示該日期的詳細事項、打開新增事項表單等
                                        }) {
                                            VStack {
                                                HStack {
                                                    ZStack {
                                                        // 如果是今天，顯示綠色圓圈
                                                        if isToday(day: dayInfo.day, month: dayInfo.month, year: dayInfo.year) {
                                                            Circle()
                                                                .fill(Color.green)
                                                                .frame(width: 36, height: 36)
                                                        }
                                                        
                                                        // 日期文字固定位置
                                                        Text(String(dayInfo.day))
                                                            .font(.system(size: 16, weight: .bold))
                                                            .foregroundColor(
                                                                isToday(day: dayInfo.day, month: dayInfo.month, year: dayInfo.year)
                                                                ? .black
                                                                : (dayInfo.isCurrentMonth
                                                                ? .white
                                                                : .gray.opacity(0.7)) // 非當前月份使用淡灰色
                                                            )
                                                    }
                                                    .frame(width: 36, height: 36) // 確保ZStack有固定大小
                                                    
                                                    Spacer() // 確保日期左對齊
                                                }
                                                .padding(.leading, 2) // 統一左側內邊距
                                                
                                                Spacer() // 讓日期位於VStack頂部
                                            }
                                        }
                                        .buttonStyle(PlainButtonStyle()) // 使用樸素按鈕樣式，不會有按下效果
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 45) // 保持日期區塊高度不變
                                    }
                                }

                                // 待辦事項行 - 與日期行重疊，根據是否為當週使用不同的定位方式
                                HStack(spacing: 0) {
                                    ForEach(0..<week.count, id: \.self) { dayIndex in
                                        let dayInfo = week[dayIndex]
                                        
                                        // 待辦事項區塊 - 統一使用左對齊，無上方間距
                                        VStack(alignment: .leading, spacing: 3) {
                                            let events = eventsForDate(dayInfo.day, month: dayInfo.month, year: dayInfo.year)
                                            let isCurrentWeekDay = isInCurrentWeek(day: dayInfo.day, month: dayInfo.month, year: dayInfo.year)
                                            
                                            if !events.isEmpty {
                                                // 確定是否為當前週或包含今天的週
                                                let isActiveWeek = isCurrentWeekDay || containsToday
                                                
                                                // 統一顯示邏輯 - 不分當週或非當週
                                                ForEach(events.prefix(3), id: \.id) { event in
                                                    Text(isActiveWeek ? event.title : "\(event.title.prefix(6))...")
                                                        .font(.system(size: 10))
                                                        .lineLimit(isActiveWeek ? 3 : 1)
                                                        .truncationMode(.tail)
                                                        .fixedSize(horizontal: false, vertical: isActiveWeek)
                                                        .padding(.horizontal, 4)
                                                        .padding(.vertical, 2)
                                                        .background(eventColor(for: dayInfo.day, isCurrentMonth: dayInfo.isCurrentMonth, month: dayInfo.month, year: dayInfo.year).opacity(0.7))
                                                        .cornerRadius(4)
                                                        .foregroundColor(.white)
                                                }
                                                
                                                // 如果事項超過3個，顯示"+x more"
                                                if events.count > 3 {
                                                    Text("+\(events.count - 3) more")
                                                        .font(.system(size: 9))
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                        }
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                        .padding(.horizontal, 2)
                                        .padding(.top, 0) // 確保無上方間距
                                    }
                                }
                                .offset(y: 32) // 使待辦事項緊貼日期，不要太靠下
                            }
                        }
                        .frame(height: weekHeight) // 修改：使用計算得到的weekHeight
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top, 40)
        }
        .navigationBarHidden(true)
    }
}

// 預覽
struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarView(toDoItems: .constant([]))
    }
}
