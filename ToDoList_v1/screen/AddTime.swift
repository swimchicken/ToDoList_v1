import SwiftUI

struct AddTimeView: View {
    // Add bindings to receive and send data back to Add.swift
    @Binding var isDateEnabled: Bool
    @Binding var isTimeEnabled: Bool
    @Binding var selectedDate: Date
    
    // Add callbacks for Save and Back buttons
    var onSave: () -> Void
    var onBack: () -> Void
    
    @State private var calendarDays: [Int] = []
    @State private var currentMonth = ""
    @State private var showDatePicker = false
    @State private var tempSelectedDate = Date()
    @State private var scrollOffset: CGFloat = 0
    
    // State for the time picker
    @State private var selectedHour = 8
    @State private var selectedMinute = 0
    @State private var selectedAMPM = 1 // 0 for AM, 1 for PM
    
    // 添加今天的日期作为参考
    private let today = Date()
    
    private let weekdays = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    private let calendar = Calendar.current
    private var columns: [GridItem] {
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Content area with ScrollView
            VStack(spacing: 0) {
                // Title
                HStack {
                    Text("When ?")
                        .font(
                            Font.custom("Inria Sans", size: 25.45489)
                                .weight(.bold)
                                .italic()
                        )
                        .foregroundColor(.white)
                        .opacity(0.9)
                        .padding(.leading)
                    Spacer()
                }
                .padding(.top)
                
                // Main content in ScrollView with clipsToBounds enabled
                ScrollView {
                    VStack(spacing: 20) {
                        // Date Toggle
                        VStack(alignment: .leading, spacing: 9) {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 22))
                                Text("Set the date")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 22))
                                Spacer()
                                Toggle("", isOn: $isDateEnabled)
                                    .labelsHidden()
                                    .toggleStyle(SwitchToggleStyle(tint: Color.green))
                                    .onChange(of: isDateEnabled) { _ in
                                        if isDateEnabled {
                                            // 确保选中日期不在过去
                                            ensureDateNotInPast()
                                            updateCalendarDays()
                                        }
                                    }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .background(Color(red: 0.12, green: 0.12, blue: 0.12))
                        .cornerRadius(12)
                        
                        // Calendar view (shown when date toggle is on)
                        if isDateEnabled {
                            VStack(alignment: .leading, spacing: 0) {
                                // Month navigation
                                HStack {
                                    Button(action: {
                                        tempSelectedDate = selectedDate
                                        showDatePicker = true
                                    }) {
                                        HStack {
                                            Text(currentMonth)
                                                .font(
                                                    Font.custom("SF Pro Text", size: 17)
                                                    .weight(.semibold)
                                                )
                                                .foregroundColor(.white)
                                            
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.green)
                                                .padding(.leading, 5)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 25) {
                                        Button(action: {
                                            changeMonth(by: -1)
                                        }) {
                                            Image(systemName: "chevron.left")
                                                .foregroundColor(.green)
                                                .font(.system(size: 24))
                                        }
                                        .disabled(isCurrentMonthOrBeforeToday()) // 禁用按钮如果向前导航会到达过去的月份
                                        .opacity(isCurrentMonthOrBeforeToday() ? 0.4 : 1) // 视觉反馈
                                        
                                        Button(action: {
                                            changeMonth(by: 1)
                                        }) {
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.green)
                                                .font(.system(size: 24))
                                        }
                                    }
                                }
                                .padding(.top, 15)
                                .padding(.bottom, 30)
                                
                                // Days of week header
                                HStack(spacing: 0) {
                                    HStack(spacing: 0) {
                                        ForEach(0..<7) { index in
                                            Text(weekdays[index])
                                                .font(
                                                    Font.custom("SF Pro Text", size: 13)
                                                    .weight(.semibold)
                                                )
                                                .multilineTextAlignment(.center)
                                                .foregroundColor(Color(red: 0.92, green: 0.92, blue: 0.96).opacity(0.3))
                                                .frame(maxWidth: .infinity, alignment: .center)
                                        }
                                    }
                                }
                                .padding(.bottom, 20)
                                
                                // Calendar grid
                                LazyVGrid(columns: columns, spacing: 12) {
                                    ForEach(0..<calendarDays.count, id: \.self) { index in
                                        let day = calendarDays[index]
                                        if day > 0 {
                                            Button(action: {
                                                if !isPastDate(day: day) {
                                                    selectDay(day)
                                                }
                                            }) {
                                                Text("\(day)")
                                                    .font(Font.custom("SF Pro Display", size: 20))
                                                    .kerning(0.38)
                                                    .multilineTextAlignment(.center)
                                                    .foregroundColor(isPastDate(day: day) ? Color.gray.opacity(0.5) : .white)
                                                    .frame(width: 40, height: 32, alignment: .center)
                                                    .background(
                                                        Circle()
                                                            .fill(isSameDay(day: day) ? Color.green : Color.clear)
                                                            .frame(width: 40, height: 40)
                                                    )
                                            }
                                            .disabled(isPastDate(day: day)) // 禁用过去的日期
                                        } else {
                                            Text("")
                                                .frame(width: 40, height: 32)
                                        }
                                    }
                                }
                                .padding(.bottom, 15)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .background(Color(red: 0.12, green: 0.12, blue: 0.12))
                            .cornerRadius(12)
                            .onAppear {
                                ensureDateNotInPast()
                                updateCalendarDays()
                            }
                        }
                        
                        // Time Toggle
                        VStack(alignment: .leading, spacing: 9) {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 22))
                                Text("Set the time")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 22))
                                Spacer()
                                Toggle("", isOn: $isTimeEnabled)
                                    .labelsHidden()
                                    .toggleStyle(SwitchToggleStyle(tint: Color.green))
                                    .onChange(of: isTimeEnabled) { newValue in
                                        if newValue {
                                            // When enabling time, update the selectedDate with the current time settings
                                            updateTimeInSelectedDate()
                                        } else {
                                            // When disabling time, clear time part from selectedDate if date is enabled
                                            if isDateEnabled {
                                                let calendar = Calendar.current
                                                let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
                                                if let dateOnly = calendar.date(from: dateComponents) {
                                                    selectedDate = dateOnly
                                                }
                                            }
                                        }
                                    }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .background(Color(red: 0.12, green: 0.12, blue: 0.12))
                        .cornerRadius(12)
                        
                        // Time picker (shown when time toggle is on)
                        if isTimeEnabled {
                            VStack(alignment: .leading, spacing: 9) {
                                // 使用自訂的MultiComponentPicker
                                VStack {
                                    HStack(spacing: 0) {
                                        Spacer()
                                        ZStack {
                                            // 使用自訂的MultiComponentPicker
                                            MultiComponentPicker(
                                                hour: $selectedHour,
                                                minute: $selectedMinute,
                                                ampm: $selectedAMPM
                                            )
                                            .frame(width: 240, height: 160)
                                            .onChange(of: selectedHour) { _ in updateTimeInSelectedDate() }
                                            .onChange(of: selectedMinute) { _ in updateTimeInSelectedDate() }
                                            .onChange(of: selectedAMPM) { _ in updateTimeInSelectedDate() }
                                        }
                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity)
                            .background(Color(red: 0.12, green: 0.12, blue: 0.12))
                            .cornerRadius(12)
                        }
                        
                        // Add some bottom padding to ensure content doesn't get hidden behind the buttons
                        Spacer()
                            .frame(height: 80)
                    }
                    .padding(.horizontal)
                }
                .padding(.top)
            }
            
            // Fixed bottom buttons with background that extends to the bottom of the screen
            VStack(spacing: 0) {
                HStack {
                    Button(action: {
                        // Call the onBack callback
                        onBack()
                    }) {
                        Text("返回")
                            .foregroundColor(.white)
                            .padding(.vertical, 15)
                            .padding(.horizontal, 10)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        // 只有在時間啟用時才更新時間
                        if isTimeEnabled {
                            updateTimeInSelectedDate()
                        } else {
                            // 時間停用時，清除selectedDate中的時間部分，只保留日期
                            if isDateEnabled {
                                let calendar = Calendar.current
                                let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
                                if let dateOnly = calendar.date(from: dateComponents) {
                                    selectedDate = dateOnly
                                }
                            }
                        }
                        
                        // Call the onSave callback
                        onSave()
                    }) {
                        Text("Save")
                            .foregroundColor(.black)
                            .fontWeight(.semibold)
                            .frame(width: 230, height: 50)
                            .background(
                                Capsule()
                                    .fill(Color.white)
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 10)
                
               
            }
            .background(
                Rectangle()
                    .fill(Color.black)
                    .edgesIgnoringSafeArea(.bottom)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .onAppear {
            ensureDateNotInPast() // 确保初始日期不在过去
            updateMonthDisplay()
            
            // Initialize the selectedHour, selectedMinute, and selectedAMPM from the current selectedDate
            initializeTimeComponentsFromSelectedDate()
        }
        .sheet(isPresented: $showDatePicker) {
            YearMonthPicker(selectedDate: $tempSelectedDate, isPresented: $showDatePicker, onSave: {
                if !isDateInPast(date: tempSelectedDate) {
                    selectedDate = tempSelectedDate
                    updateCalendarDays()
                }
            })
            .presentationDetents([.height(400)])
            .presentationBackground(Color(red: 0.12, green: 0.12, blue: 0.12))
        }
    }
    
    // 确保日期不在过去
    private func ensureDateNotInPast() {
        let todayStart = calendar.startOfDay(for: today)
        if selectedDate < todayStart {
            selectedDate = todayStart
        }
    }
    
    // 检查日期是否在过去
    private func isDateInPast(date: Date) -> Bool {
        return date < calendar.startOfDay(for: today)
    }
    
    // 检查日期是否在过去
    private func isPastDate(day: Int) -> Bool {
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: today)
        let currentComponents = calendar.dateComponents([.year, .month], from: selectedDate)
        
        // 如果当前查看的年和月已经在过去，则所有日期都在过去
        if currentComponents.year! < todayComponents.year! ||
           (currentComponents.year! == todayComponents.year! && currentComponents.month! < todayComponents.month!) {
            return true
        }
        
        // 如果是当前月份，则只有今天之前的日期在过去
        if currentComponents.year! == todayComponents.year! && currentComponents.month! == todayComponents.month! {
            return day < todayComponents.day!
        }
        
        // 否则，如果是将来的月份，则没有日期在过去
        return false
    }
    
    // 检查当前显示的是否为今天所在的月份或更早的月份
    private func isCurrentMonthOrBeforeToday() -> Bool {
        let todayComponents = calendar.dateComponents([.year, .month], from: today)
        let currentComponents = calendar.dateComponents([.year, .month], from: selectedDate)
        
        return currentComponents.year! == todayComponents.year! && currentComponents.month! == todayComponents.month!
    }
    
    // Initialize time components based on the selectedDate
    private func initializeTimeComponentsFromSelectedDate() {
        let components = calendar.dateComponents([.hour, .minute], from: selectedDate)
        if let hour = components.hour {
            // Convert 24-hour to 12-hour format
            if hour == 0 {
                selectedHour = 12
                selectedAMPM = 0 // AM
            } else if hour < 12 {
                selectedHour = hour
                selectedAMPM = 0 // AM
            } else if hour == 12 {
                selectedHour = 12
                selectedAMPM = 1 // PM
            } else {
                selectedHour = hour - 12
                selectedAMPM = 1 // PM
            }
        }
        
        if let minute = components.minute {
            selectedMinute = minute
        }
    }
    
    // Update the selectedDate with the current time settings
    private func updateTimeInSelectedDate() {
        var components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        
        // Convert 12-hour format to 24-hour format
        var hour = selectedHour
        if selectedAMPM == 1 { // PM
            if hour < 12 {
                hour += 12
            }
        } else { // AM
            if hour == 12 {
                hour = 0
            }
        }
        
        components.hour = hour
        components.minute = selectedMinute
        
        if let newDate = calendar.date(from: components) {
            // 检查是否在过去，如果是则更新到当前时间
            if isDateInPast(date: newDate) {
                selectedDate = today
                initializeTimeComponentsFromSelectedDate()
            } else {
                selectedDate = newDate
            }
        }
    }
    
    // Helper functions
    private func updateMonthDisplay() {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        currentMonth = formatter.string(from: selectedDate)
    }
    
    private func updateCalendarDays() {
        let month = calendar.component(.month, from: selectedDate)
        let year = calendar.component(.year, from: selectedDate)
        
        guard let firstDayOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
            calendarDays = []
            return
        }
        
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let daysInMonth = calendar.range(of: .day, in: .month, for: firstDayOfMonth)?.count ?? 0
        
        var days: [Int] = Array(repeating: 0, count: firstWeekday - 1)
        days.append(contentsOf: 1...daysInMonth)
        
        let remainingDays = (7 - (days.count % 7)) % 7
        if remainingDays > 0 {
            days.append(contentsOf: Array(repeating: 0, count: remainingDays))
        }
        
        calendarDays = days
        updateMonthDisplay()
    }
    
    private func isSameDay(day: Int) -> Bool {
        return calendar.component(.day, from: selectedDate) == day
    }
    
    private func selectDay(_ day: Int) {
        let components = calendar.dateComponents([.year, .month], from: selectedDate)
        if let newDate = calendar.date(from: DateComponents(year: components.year, month: components.month, day: day)) {
            // 确保不选择过去的日期
            if !isDateInPast(date: newDate) {
                // Preserve the time when changing the day
                var timeComponents = calendar.dateComponents([.hour, .minute, .second], from: selectedDate)
                var dateComponents = calendar.dateComponents([.year, .month, .day], from: newDate)
                dateComponents.hour = timeComponents.hour
                dateComponents.minute = timeComponents.minute
                dateComponents.second = timeComponents.second
                
                if let combinedDate = calendar.date(from: dateComponents) {
                    selectedDate = combinedDate
                } else {
                    selectedDate = newDate
                }
            }
        }
    }
    
    private func changeMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: selectedDate) {
            // 检查新月份是否会在过去
            let todayComponents = calendar.dateComponents([.year, .month], from: today)
            let newComponents = calendar.dateComponents([.year, .month], from: newDate)
            
            // 如果新月份在过去，不允许改变
            if newComponents.year! < todayComponents.year! ||
               (newComponents.year! == todayComponents.year! && newComponents.month! < todayComponents.month!) {
                return
            }
            
            // Preserve the day as much as possible when changing months
            let day = calendar.component(.day, from: selectedDate)
            let month = calendar.component(.month, from: newDate)
            let year = calendar.component(.year, from: newDate)
            
            // Check how many days are in the new month
            guard let lastDayOfMonth = calendar.range(of: .day, in: .month, for: newDate)?.upperBound else {
                selectedDate = newDate
                updateCalendarDays()
                return
            }
            
            // Make sure we don't exceed the days in the month
            let targetDay = min(day, lastDayOfMonth - 1)
            
            if let adjustedDate = calendar.date(from: DateComponents(year: year, month: month, day: targetDay)) {
                // Preserve the time
                var timeComponents = calendar.dateComponents([.hour, .minute, .second], from: selectedDate)
                var dateComponents = calendar.dateComponents([.year, .month, .day], from: adjustedDate)
                dateComponents.hour = timeComponents.hour
                dateComponents.minute = timeComponents.minute
                dateComponents.second = timeComponents.second
                
                if let combinedDate = calendar.date(from: dateComponents) {
                    selectedDate = combinedDate
                } else {
                    selectedDate = adjustedDate
                }
            } else {
                selectedDate = newDate
            }
            
            updateCalendarDays()
        }
    }
}


// 修改 YearMonthPicker 以限制过去的年月选择
struct YearMonthPicker: View {
    @Binding var selectedDate: Date
    @Binding var isPresented: Bool
    var onSave: () -> Void
    
    @State private var selectedYear: Int
    @State private var selectedMonth: Int
    
    private let calendar = Calendar.current
    private let months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    private let today = Date()
    
    init(selectedDate: Binding<Date>, isPresented: Binding<Bool>, onSave: @escaping () -> Void) {
        self._selectedDate = selectedDate
        self._isPresented = isPresented
        self.onSave = onSave
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: selectedDate.wrappedValue)
        self._selectedYear = State(initialValue: components.year ?? 2022)
        self._selectedMonth = State(initialValue: (components.month ?? 1) - 1)
    }
    
    // 获取当前月份和年份
    private var currentYearMonth: (year: Int, month: Int) {
        let components = calendar.dateComponents([.year, .month], from: today)
        return (components.year ?? 2022, components.month ?? 1)
    }
    
    var body: some View {
        VStack {
            HStack {
                Button("取消") {
                    isPresented = false
                }
                .foregroundColor(.green)
                
                Spacer()
                
                Text("選擇日期")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("確認") {
                    // 确保所选日期不在过去
                    if let newDate = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth + 1, day: 1)) {
                        let todayComponents = calendar.dateComponents([.year, .month], from: today)
                        
                        // 如果所选年月在过去，则选择当前月份
                        if selectedYear < todayComponents.year! ||
                           (selectedYear == todayComponents.year! && selectedMonth + 1 < todayComponents.month!) {
                            if let currentDate = calendar.date(from: DateComponents(year: todayComponents.year, month: todayComponents.month, day: 1)) {
                                selectedDate = currentDate
                            } else {
                                selectedDate = today
                            }
                        } else {
                            selectedDate = newDate
                        }
                    }
                    onSave()
                    isPresented = false
                }
                .foregroundColor(.green)
            }
            .padding()
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            HStack {
                // 年份选择器 - 只显示当前年份及以后
                Picker("年份", selection: $selectedYear) {
                    ForEach(currentYearMonth.year...2040, id: \.self) { year in
                        Text("\(year)年")
                            .foregroundColor(.white)
                            .tag(year)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(width: UIScreen.main.bounds.width / 2)
                .clipped()
                
                // 月份选择器 - 如果是当前年份，只显示当前月份及以后
                Picker("月份", selection: $selectedMonth) {
                    ForEach(0..<12, id: \.self) { index in
                        if selectedYear > currentYearMonth.year || index >= (currentYearMonth.month - 1) {
                            Text(months[index])
                                .foregroundColor(.white)
                                .tag(index)
                        }
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(width: UIScreen.main.bounds.width / 2)
                .clipped()
                .onChange(of: selectedYear) { _ in
                    // 如果改变了年份，检查并调整月份
                    if selectedYear == currentYearMonth.year && selectedMonth < (currentYearMonth.month - 1) {
                        selectedMonth = currentYearMonth.month - 1
                    }
                }
            }
            .padding(.vertical)
            
            Spacer()
        }
        .background(Color(red: 0.12, green: 0.12, blue: 0.12))
        .edgesIgnoringSafeArea(.bottom)
    }
}

struct AddTimeView_Previews: PreviewProvider {
    static var previews: some View {
        // Create dummy binding values for preview
        AddTimeView(
            isDateEnabled: .constant(true),
            isTimeEnabled: .constant(true),
            selectedDate: .constant(Date()),
            onSave: {},
            onBack: {}
        )
    }
}
