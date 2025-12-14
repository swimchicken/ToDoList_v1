import SwiftUI
import Combine
import CloudKit

struct CalendarView: View {
    @Binding var toDoItems: [TodoItem]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate = Date()
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var showAddEventSheet = false
    @State private var newEventTitle = ""
    @State private var newEventTime = Date()
    @State private var isLoading = false
    @State private var loadingError: String? = nil
    
    // 新增：跟蹤用戶點擊的日期
    @State private var clickedDate: Date? = nil
    
    // 新增：用於傳遞所選日期偏移到Home視圖
    var onDateSelected: ((Int) -> Void)?
    
    // 新增：用於處理導航到home
    var onNavigateToHome: (() -> Void)?
    
    // 引用已完成日期數據管理器
    private let completeDayDataManager = CompleteDayDataManager.shared
    
    // 每週日期標題
    let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    
    // 初始化，從本地數據管理器讀取待辦事項
    init(toDoItems: Binding<[TodoItem]>,
         onDateSelected: ((Int) -> Void)? = nil,
         onNavigateToHome: (() -> Void)? = nil) {
        // 直接使用傳入的綁定
        self._toDoItems = toDoItems
        self.onDateSelected = onDateSelected
        self.onNavigateToHome = onNavigateToHome
        
        print("日曆視圖初始化，傳入了 \(toDoItems.wrappedValue.count) 個待辦事項")
        
        // 使用獨立代碼塊確保在初始化完成後進行刪除項目檢查
        DispatchQueue.main.async {
            // 獲取已刪除項目ID集合
            var recentlyDeletedItemIDs: Set<UUID> = []
            if let savedData = UserDefaults.standard.data(forKey: "recentlyDeletedItemIDs"),
               let decodedIDs = try? JSONDecoder().decode([UUID].self, from: savedData) {
                recentlyDeletedItemIDs = Set(decodedIDs)
                if !recentlyDeletedItemIDs.isEmpty {
                    print("日曆視圖初始化時檢測到 \(recentlyDeletedItemIDs.count) 個已刪除項目ID")
                }
            }
        }
    }
    
    // 新增：重置到當週
    private func resetToCurrentWeek() {
        withAnimation {
            clickedDate = nil
        }
    }
    
    // 從本地數據加載待辦事項，並過濾掉已刪除的項目
    private func loadFromLocalDataManager() {
        isLoading = true
        loadingError = nil
        
        // 從UserDefaults獲取最近刪除的項目ID
        var recentlyDeletedItemIDs: Set<UUID> = []
        if let savedData = UserDefaults.standard.data(forKey: "recentlyDeletedItemIDs"),
           let decodedIDs = try? JSONDecoder().decode([UUID].self, from: savedData) {
            recentlyDeletedItemIDs = Set(decodedIDs)
            print("CalendarView - 獲取到 \(recentlyDeletedItemIDs.count) 個最近刪除項目ID")
        }
        
        // 獲取本地數據
        var localItems = LocalDataManager.shared.getAllTodoItems()
        
        // 過濾掉已刪除的項目
        if !recentlyDeletedItemIDs.isEmpty {
            let originalCount = localItems.count
            localItems = localItems.filter { !recentlyDeletedItemIDs.contains($0.id) }
            let filteredCount = originalCount - localItems.count
            print("CalendarView - 過濾掉 \(filteredCount) 個已刪除項目")
        }
        
        // 更新狀態
        DispatchQueue.main.async {
            if !localItems.isEmpty {
                self.toDoItems = localItems
                print("從本地數據載入了 \(localItems.count) 個待辦事項")
            } else {
                print("本地數據為空")
            }
            self.isLoading = false
        }
    }
    
    // 新增：計算週開始日期（以週一為開始）
    private func getWeekStart(for date: Date) -> Date {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date) // 1=週日, 2=週一, ..., 7=週六
        let daysFromMonday = (weekday + 5) % 7 // 計算距離週一的天數
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: date)!
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
    
    // 獲取指定日期的事件，確保已刪除的項目不會顯示
    func eventsForDate(_ day: Int, month: Int, year: Int) -> [TodoItem] {
        let calendar = Calendar.current
        let targetDate = calendar.date(from: DateComponents(year: year, month: month, day: day))!
        
        // 獲取已刪除項目ID集合
        var recentlyDeletedItemIDs: Set<UUID> = []
        if let savedData = UserDefaults.standard.data(forKey: "recentlyDeletedItemIDs"),
           let decodedIDs = try? JSONDecoder().decode([UUID].self, from: savedData) {
            recentlyDeletedItemIDs = Set(decodedIDs)
        }
        
        return toDoItems.filter { item in
            // 首先檢查該項目是否已被刪除
            if recentlyDeletedItemIDs.contains(item.id) {
                return false
            }
            
            // 檢查 taskDate 是否為 nil
            guard let taskDate = item.taskDate else {
                return false // 沒有日期的項目不顯示在日曆中
            }
            
            let itemComponents = calendar.dateComponents([.year, .month, .day], from: taskDate)
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
    
    // 簡化版本，用於當前月份，會調用完整版本以確保過濾已刪除項目
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
    
    // 檢查指定日期是否已完成
    func isDayCompleted(day: Int, month: Int, year: Int) -> Bool {
        let calendar = Calendar.current
        let dateComponents = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: dateComponents) else { return false }
        return completeDayDataManager.isDayCompleted(date: date)
    }
    
    // 簡化版本，用於當前月份
    func isDayCompleted(day: Int) -> Bool {
        return isDayCompleted(day: day, month: selectedMonth, year: selectedYear)
    }
    
    // 檢查指定日期是否為過去日期
    func isPastDate(day: Int, month: Int, year: Int) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dateComponents = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: dateComponents) else { return false }
        let targetDate = calendar.startOfDay(for: date)
        return targetDate < today
    }
    
    // 修改：檢查日期是否在當前選擇的週（基於點擊的日期或今天）
    func isInCurrentWeek(day: Int, month: Int, year: Int) -> Bool {
        let calendar = Calendar.current
        let referenceDate = clickedDate ?? Date() // 使用點擊的日期或今天作為參考
        let targetDate = calendar.date(from: DateComponents(year: year, month: month, day: day))!
        
        // 使用 getWeekStart 方法計算週開始日期
        let referenceWeekStart = getWeekStart(for: referenceDate)
        let targetWeekStart = getWeekStart(for: targetDate)
        
        return calendar.isDate(referenceWeekStart, inSameDayAs: targetWeekStart)
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
    
    // 計算單一事項的實際文字高度
    func calculateActualEventHeight(title: String, isActiveWeek: Bool, availableWidth: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 10)
        let maxLines = isActiveWeek ? 3 : 1
        
        // 使用NSString的boundingRect計算實際高度
        let text = NSString(string: title)
        let rect = text.boundingRect(
            with: CGSize(width: availableWidth - 8, height: .greatestFiniteMagnitude), // -8 for horizontal padding
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        
        let actualLines = min(maxLines, max(1, Int(ceil(rect.height / font.lineHeight))))
        return CGFloat(actualLines) * font.lineHeight + 4 // +4 for vertical padding (.padding(.vertical, 2))
    }
    
    // 修改：計算週所需的高度（根據實際事項文字高度精確計算）
    func calculateWeekHeight(for week: [(day: Int, month: Int, year: Int, isCurrentMonth: Bool)], isCurrentWeek: Bool) -> CGFloat {
        var maxDayHeight: CGFloat = 0
        let availableWidth: CGFloat = (UIScreen.main.bounds.width - 32) / 7 // 32 for horizontal padding, 7 days per week
        
        for dayInfo in week {
            let events = eventsForDate(dayInfo.day, month: dayInfo.month, year: dayInfo.year)
            let eventsToShow = Array(events.prefix(3))
            
            var dayEventHeight: CGFloat = 0
            
            // 計算該日所有事項的實際高度
            for event in eventsToShow {
                let eventHeight = calculateActualEventHeight(title: event.title, isActiveWeek: isCurrentWeek, availableWidth: availableWidth)
                dayEventHeight += eventHeight
            }
            
            // 添加事項間距
            if eventsToShow.count > 1 {
                dayEventHeight += CGFloat(eventsToShow.count - 1) * 3 // 3 is spacing between events
            }
            
            // 如果事項超過3個，添加"+x more"文字高度
            if events.count > 3 {
                dayEventHeight += 15 // height for "+x more" text
            }
            
            maxDayHeight = max(maxDayHeight, dayEventHeight)
        }
        
        // 基礎計算參數
        let dateHeight: CGFloat = 45
        let padding: CGFloat = 10
        let safetyMargin: CGFloat = 5 // 減少安全邊距，因為現在計算更精確
        
        return dateHeight + maxDayHeight + padding + safetyMargin
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
                    
                    // 關閉按鈕 - 修改為支持導航
                    Button {
                        // 如果有導航到 Home 的回調，就調用它
                        if let onNavigateToHome = onNavigateToHome {
                            onNavigateToHome()
                        } else {
                            // 否則使用默認的關閉動作
                            dismiss()
                        }
                    } label: {
                        Image("calendar_icon")
                            .font(.system(size: 20))
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
                        
                        // 修改：使用一致的週判斷邏輯
                        let calendar = Calendar.current
                        let referenceDate = clickedDate ?? Date()
                        
                        // 獲取參考日期的週一日期
                        let referenceWeekStart = getWeekStart(for: referenceDate)
                        
                        // 檢查這一週是否包含參考日期
                        let containsReferenceWeek: Bool = {
                            // 檢查週的第一天（週一）是否屬於同一週
                            let weekFirstDate = calendar.date(from: DateComponents(
                                year: week[0].year,
                                month: week[0].month,
                                day: week[0].day
                            ))!
                            
                            let weekDateStart = getWeekStart(for: weekFirstDate)
                            
                            return calendar.isDate(referenceWeekStart, inSameDayAs: weekDateStart)
                        }()
                        
                        // 計算當週所需高度
                        let weekHeight = calculateWeekHeight(for: week, isCurrentWeek: containsReferenceWeek)
                        
                        // 整週容器
                        ZStack(alignment: .top) {
                            // 如果是選擇的週，添加背景色
                            if containsReferenceWeek {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(hex:"181818"))
                                    .frame(height: weekHeight)
                            }
                            
                            // 在選擇的週顯示加載指示器
                            if containsReferenceWeek && isLoading {
                                VStack {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.5)
                                    Text("common.loading")
                                        .foregroundColor(.white)
                                        .padding(.top, 8)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                                            
                                            // 修改：判斷是否再次點擊同一日期
                                            withAnimation(.easeInOut) {
                                                if let currentClickedDate = clickedDate {
                                                    let calendar = Calendar.current
                                                    let sameDay = calendar.isDate(currentClickedDate, inSameDayAs: date)
                                                    if sameDay {
                                                        // 再次點擊同一日期，重置到當週
                                                        clickedDate = nil
                                                        print("重置到當週")
                                                    } else {
                                                        // 點擊不同日期，更新選擇的日期
                                                        clickedDate = date
                                                        print("切換到 \(date) 所在的週")
                                                    }
                                                } else {
                                                    // 第一次點擊，設置選擇的日期
                                                    clickedDate = date
                                                    print("第一次選擇，切換到 \(date) 所在的週")
                                                }
                                            }
                                            
                                            // 延遲執行日期選擇回調和關閉
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                // 計算選擇的日期與當前日期的偏移量
                                                let calendar = Calendar.current
                                                let today = calendar.startOfDay(for: Date())
                                                let selectedDay = calendar.startOfDay(for: date)
                                                let components = calendar.dateComponents([.day], from: today, to: selectedDay)
                                                
                                                // 獲取偏移量（天數差）
                                                if let dayOffset = components.day {
                                                    print("日期偏移量: \(dayOffset)天")
                                                    
                                                    // 優先使用導航回調
                                                    if let onNavigateToHome = self.onNavigateToHome {
                                                        // 先執行日期選擇回調
                                                        self.onDateSelected?(dayOffset)
                                                        
                                                        // 延遲執行導航回調
                                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                            onNavigateToHome()
                                                        }
                                                    } else if let onDateSelected = self.onDateSelected {
                                                        // 先執行日期選擇回調
                                                        onDateSelected(dayOffset)
                                                        
                                                        // 延遲關閉視圖
                                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                            self.dismiss()
                                                        }
                                                    } else {
                                                        // 如果沒有回調，直接關閉
                                                        self.dismiss()
                                                    }
                                                }
                                            }
                                        }) {
                                            VStack {
                                                HStack {
                                                    ZStack {
                                                        // 如果是今天，顯示綠色圓圈，尺寸縮小
                                                        if isToday(day: dayInfo.day, month: dayInfo.month, year: dayInfo.year) {
                                                            Circle()
                                                                .fill(Color.green)
                                                                .frame(width: 28, height: 28) // 從36x36縮小到28x28
                                                        }
                                                        
                                                        // 如果這一天已完成，顯示綠色小勾勾
                                                        if isDayCompleted(day: dayInfo.day, month: dayInfo.month, year: dayInfo.year) {
                                                            HStack {
                                                                Spacer()
                                                                VStack {
                                                                    Image(systemName: "checkmark.circle.fill")
                                                                        .foregroundColor(Color(red: 0, green: 0.72, blue: 0.41))
                                                                        .font(.system(size: 12))
                                                                    Spacer()
                                                                }
                                                            }
                                                            .frame(width: 36, height: 36)
                                                        }
                                                        
                                                        // 日期文字固定位置
                                                        Text(String(dayInfo.day))
                                                            .font(.system(size: 16, weight: .semibold))
                                                            .foregroundColor(
                                                                isToday(day: dayInfo.day, month: dayInfo.month, year: dayInfo.year)
                                                                ? .black
                                                                : isPastDate(day: dayInfo.day, month: dayInfo.month, year: dayInfo.year)
                                                                ? .green
                                                                : (dayInfo.isCurrentMonth
                                                                ? .white
                                                                : .gray.opacity(0.7)) // 非當前月份使用淡灰色
                                                            )
                                                            .overlay(
                                                                Group {
                                                                    if isPastDate(day: dayInfo.day, month: dayInfo.month, year: dayInfo.year){
                                                                        Rectangle()
                                                                            .fill(Color.green)
                                                                            .frame(height: 1)
//                                                                                .padding(.horizontal, 2)
                                                                    }
                                                                }
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
                                                let isActiveWeek = isCurrentWeekDay || containsReferenceWeek
                                                
                                                // 統一顯示邏輯 - 不分當週或非當週
                                                ForEach(events.prefix(3), id: \.id) { event in
                                                    Text(isActiveWeek ? event.title : "\(event.title.prefix(6))...")
                                                        .font(.system(size: 10))
                                                        .lineLimit(isActiveWeek ? 3 : 1)
                                                        .truncationMode(.tail)
                                                        .multilineTextAlignment(.leading) // 添加文本對齊方式
                                                        .frame(maxWidth: .infinity, alignment: .leading) // 讓文本填滿可用寬度
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
                                                        .frame(maxWidth: .infinity, alignment: .leading) // 同樣讓 "+x more" 文本也填滿寬度
                                                }
                                            }
                                        }
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                        .padding(.horizontal, 1) // 減少水平 padding，讓事項有更多空間
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
            .padding(.top, 20)
        }
        .navigationBarHidden(true)
        .onAppear {
            // 視圖出現時重置到當週
            resetToCurrentWeek()
            
            // 如果傳入的toDoItems為空，則從本地數據加載
            if toDoItems.isEmpty {
                loadFromLocalDataManager()
            }
            
            // 監聽已完成日期數據變更通知
            NotificationCenter.default.addObserver(
                forName: Notification.Name("CompletedDaysDataChanged"),
                object: nil,
                queue: .main
            ) { _ in
                // 強制更新視圖以顯示最新的完成狀態
                print("CalendarView 收到已完成日期數據變更通知")
                // 這裡不需要做什麼，因為視圖會自動刷新
            }
            
            // 監聽數據刷新通知
            NotificationCenter.default.addObserver(
                forName: Notification.Name("TodoItemsDataRefreshed"),
                object: nil,
                queue: .main
            ) { _ in
                // 檢查是否有項目刪除並刷新數據
                print("CalendarView 收到數據刷新通知，重新加載數據")
                if toDoItems.isEmpty {
                    self.loadFromLocalDataManager()
                }
            }
        }
        .onDisappear {
            // 移除通知觀察者
            NotificationCenter.default.removeObserver(self, name: Notification.Name("CompletedDaysDataChanged"), object: nil)
            NotificationCenter.default.removeObserver(self, name: Notification.Name("TodoItemsDataRefreshed"), object: nil)
        }
    }
}

// 預覽
struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarView(
            toDoItems: .constant([]),
            onDateSelected: { offset in
                print("預覽模式中選擇了日期偏移: \(offset)")
            },
            onNavigateToHome: {
                print("預覽模式中導航到 Home")
            }
        )
    }
}
