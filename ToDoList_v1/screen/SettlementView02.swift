import SwiftUI

// MARK: - S02ProgressBarSegment (專為 SettlementView02 設計的進度條樣式)
struct S02ProgressBarSegment: View {
    let isActive: Bool // true: 帶綠色邊框的灰色; false: 純灰色
    let width: CGFloat
    private let segmentHeight: CGFloat = 11
    private let segmentCornerRadius: CGFloat = 29

    var body: some View {
        ZStack {
            // 背景統一為深灰色
            Rectangle()
                .fill(Color(red: 0.13, green: 0.13, blue: 0.13))
                .frame(width: width, height: segmentHeight)
                .cornerRadius(segmentCornerRadius)

            // 如果是 active，才加上綠色邊框
            if isActive {
                RoundedRectangle(cornerRadius: segmentCornerRadius)
                    .inset(by: 0.5)
                    .stroke(Color(red: 0, green: 0.72, blue: 0.41), lineWidth: 1)
            }
        }
        .frame(width: width, height: segmentHeight) // 確保 ZStack 大小正確
    }
}

// MARK: - SettlementView02.swift
struct SettlementView02: View {
    @Environment(\.presentationMode) var presentationMode
    
    // 接收從SettlementView傳遞的未完成任務和設置
    let uncompletedTasks: [TodoItem]
    let moveTasksToTomorrow: Bool
    
    // 用於顯示的明日任務列表
    @State private var dailyTasks: [TodoItem] = []
    
    // 原本的待辦佇列項目
    @State private var todoQueueItems: [TodoItem] = []
    
    // 初始化方法 - 接收未完成任務和是否移至明日的設置
    init(uncompletedTasks: [TodoItem], moveTasksToTomorrow: Bool) {
        self.uncompletedTasks = uncompletedTasks
        self.moveTasksToTomorrow = moveTasksToTomorrow
        
        // 如果選擇將未完成任務移至明日，則使用這些任務初始化明日任務列表
        // 否則使用空列表
        let initialDailyTasks = moveTasksToTomorrow ? uncompletedTasks : []
        self._dailyTasks = State(initialValue: initialDailyTasks)
        
        // 初始化待辦佇列項目
        self._todoQueueItems = State(initialValue: [])
    }
    @State private var selectedFilterInSettlement = "全部"
    @State private var showTodoQueue: Bool = false
    @State private var navigateToSettlementView03: Bool = false // 導航到下一頁
    
    // 延遲結算管理器
    private let delaySettlementManager = DelaySettlementManager.shared
    
    private var tomorrow: Date { Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date() }

    private func formatDateForDisplay(_ date: Date) -> (monthDay: String, weekday: String) {
        let dateFormatterMonthDay = DateFormatter()
        dateFormatterMonthDay.locale = Locale(identifier: "en_US_POSIX")
        dateFormatterMonthDay.dateFormat = "MMM dd"
        let dateFormatterWeekday = DateFormatter()
        dateFormatterWeekday.locale = Locale(identifier: "en_US_POSIX")
        dateFormatterWeekday.dateFormat = "EEEE"
        return (dateFormatterMonthDay.string(from: date), dateFormatterWeekday.string(from: date))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 15) {
                    HStack(spacing: 8) {
                        // 进度条部分
                        ProgressBarView()
                        
                        // 勾选图标部分
                        CheckmarkView()
                    }
                    .padding(.top, 5)
                    // ... (SettlementView02 的其餘頂部內容，如您之前提供)
                    // 分隔线
                    DividerView()
                    
                    // 唤醒文本
                    WakeUpTitleView()
                    
                    // 明日日期显示
                    TomorrowDateView(tomorrow: tomorrow, formatDateForDisplay: formatDateForDisplay)
                    
                    // 闹钟信息
                    AlarmInfoView()
                    Image("Vector 81").resizable().aspectRatio(contentMode: .fit).frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 15)

                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        // 任务列表
                        TaskListView(tasks: dailyTasks)
                        .padding(.top, 10)
                    }
                     // 估算底部固定UI高度，為ScrollView增加padding，避免遮擋
                    .padding(.bottom, (showTodoQueue ? 380 : 80) + 70 + 20 ) // (按鈕+展開內容)+底部導航+緩衝
                }
                .scrollIndicators(.hidden)
                .padding(.horizontal, 12)
            }
            .padding(.top, 60)

            VStack(spacing: 0) {
                if showTodoQueue {
                    TobestartedView(
                        items: $todoQueueItems,
                        selectedFilter: $selectedFilterInSettlement,
                        collapseAction: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                showTodoQueue = false
                            }
                        }
                    )
                    .padding(.horizontal, 12)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity).animation(.spring(response: 0.4, dampingFraction: 0.85)),
                        removal: .move(edge: .bottom).combined(with: .opacity).animation(.easeInOut(duration: 0.2))
                    ))
                    .padding(.bottom, 10)
                } else {
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            showTodoQueue.toggle()
                        }
                    }) {
                        HStack {
                            Text("待辦事項佇列")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.8))
                            Spacer()
                            Image(systemName: "chevron.up")
                                .foregroundColor(Color.white.opacity(0.8))
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .background(Color(white: 0.12))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeInOut(duration: 0.2)),
                        removal: .opacity.animation(.easeInOut(duration: 0.05))
                    ))
                }
                HStack {
                    Button(action: {
                        // 返回上一頁
                        self.presentationMode.wrappedValue.dismiss()
                    }) { 
                        Text("返回")
                            .font(Font.custom("Inria Sans", size: 20))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .center) // 使整個按鈕區域可點擊
                    }.padding()
                    Spacer()
                    Button(action: {
                        // 因為這是當天結算流程的最後一步（不再進入 SettlementView03）
                        // 所以直接標記結算完成
                        delaySettlementManager.markSettlementCompleted()
                        print("SettlementView02 - 已標記結算完成")
                        
                        // 仍然導航到 SettlementView03 來設置鬧鐘
                        navigateToSettlementView03 = true
                    }) { 
                        Text("Next")
                            .font(Font.custom("Inria Sans", size: 20).weight(.bold))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity, alignment: .center) // 使整個按鈕區域可點擊
                    }
                    .frame(width: 279, height: 60).background(.white).cornerRadius(40.5)
                }
                .padding(.horizontal, 12)
            }
            .padding(.bottom, 60)
            .background(Color.black)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // 日志输出，便于调试
            print("SettlementView02 - onAppear: 移动未完成任务设置 = \(moveTasksToTomorrow)")
            print("SettlementView02 - onAppear: 未完成任务数量 = \(uncompletedTasks.count)")
            
            // 如果选择移动未完成任务到明日，显示它们
            if moveTasksToTomorrow {
                dailyTasks = uncompletedTasks
            } else {
                dailyTasks = []
            }
            
            // 从 LocalDataManager 加载待办事项队列
            let allItems = LocalDataManager.shared.getAllTodoItems()
            todoQueueItems = allItems.filter { $0.status == .toDoList }
        }
        .background(
            NavigationLink(destination: SettlementView03(), isActive: $navigateToSettlementView03) {
                EmptyView()
            }
        )
    }
}
// MARK: - 辅助视图组件
// 进度条视图组件
struct ProgressBarView: View {
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 8) {
                let segmentWidth = (geometry.size.width - 8) / 2
                // 第一個是 active (灰底綠框)，第二個是 inactive (純灰色)
                S02ProgressBarSegment(isActive: true, width: segmentWidth)
                S02ProgressBarSegment(isActive: false, width: segmentWidth)
            }
        }
        .frame(height: 11)
    }
}

// 勾选图标组件
struct CheckmarkView: View {
    var body: some View {
        Image(systemName: "checkmark")
            .foregroundColor(.gray)
            .padding(5)
            .background(Color.gray.opacity(0.3))
            .clipShape(Circle())
    }
}

// 分隔线视图
struct DividerView: View {
    var body: some View {
        Rectangle()
            .frame(height: 1)
            .foregroundColor(Color(red: 0.34, green: 0.34, blue: 0.34))
            .padding(.vertical, 10)
    }
}

// 唤醒标题视图
struct WakeUpTitleView: View {
    var body: some View {
        HStack {
            Text("What do you want to wake up at")
                .font(Font.custom("Instrument Sans", size: 13).weight(.semibold))
                .foregroundColor(.white)
            Spacer()
        }
    }
}

// 明日日期视图
struct TomorrowDateView: View {
    let tomorrow: Date
    let formatDateForDisplay: (Date) -> (monthDay: String, weekday: String)
    
    var body: some View {
        let tomorrowParts = formatDateForDisplay(tomorrow)
        
        HStack(alignment: .bottom) {
            // 左侧"明日"文本
            Text("Tomorrow")
                .font(Font.custom("Instrument Sans", size: 31.79449).weight(.bold))
                .foregroundColor(.white)
            
            Spacer()
            
            // 右侧日期文本 - 改用 HStack 替代 Text 连接
            HStack(spacing: 2) {
                Text(tomorrowParts.monthDay)
                    .font(Font.custom("Instrument Sans", size: 20.65629).weight(.bold))
                    .foregroundColor(.white)
                
                Text("   ") // 空格
                
                Text(tomorrowParts.weekday)
                    .font(Font.custom("Instrument Sans", size: 20.65629).weight(.bold))
                    .foregroundColor(.gray)
            }
        }
    }
}

// 闹钟信息视图
struct AlarmInfoView: View {
    var body: some View {
        HStack {
            Image(systemName: "bell")
                .foregroundColor(.blue)
                .font(.system(size: 11.73462))
            
            Text("9:00 awake")
                .font(Font.custom("Inria Sans", size: 11.73462))
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
            
            Spacer()
        }
    }
}

// 任务列表视图
struct TaskListView: View {
    let tasks: [TodoItem]
    
    var body: some View {
        VStack(spacing: 0) {
            // 显示任务列表（如果有任务）
            if !tasks.isEmpty {
                ForEach(tasks.indices, id: \.self) { index in
                    TaskRowView(task: tasks[index], isLast: index == tasks.count - 1)
                }
            }
            // 无论有没有任务都显示添加按钮
            AddTaskButton()
        }
    }
}

// 单个任务行视图
struct TaskRowView: View {
    let task: TodoItem
    let isLast: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // 任务内容
            HStack(spacing: 12) {
                // 图标
                TaskIconView()
                
                // 标题
                Text(task.title)
                    .font(Font.custom("Inria Sans", size: 16).weight(.bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .layoutPriority(1)
                
                Spacer()
                
                // 右侧信息（优先级、时间、删除按钮）
                TaskRightInfoView(task: task)
            }
            .padding(.vertical, 12)
            
            // 分隔线（如果不是最后一项）
            if !isLast {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(red: 0.34, green: 0.34, blue: 0.34))
            }
        }
    }
}

// 任务图标视图
struct TaskIconView: View {
    var body: some View {
        ZStack {
            Rectangle()
                .foregroundColor(.clear)
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.15))
                .cornerRadius(40.5)
            
            Image("Vector")
                .resizable()
                .scaledToFit()
                .frame(width: 15.35494, height: 14.54678)
        }
    }
}

// 任务右侧信息视图
struct TaskRightInfoView: View {
    let task: TodoItem
    
    var body: some View {
        HStack(spacing: 12) {
            // 置顶或优先级星星
            Group {
                if task.isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 14))
                } else {
                    PriorityStarsView(priority: task.priority)
                }
            }
            .frame(minWidth: 14 * 3 + 2 * 2, alignment: .leading)
            
            // 时间显示
            TimeDisplayView(taskDate: task.taskDate)
                .frame(width: 39.55874, height: 20.58333, alignment: .topLeading)
            
            // 删除按钮
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.gray.opacity(0.6))
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

// 优先级星星视图
struct PriorityStarsView: View {
    let priority: Int
    
    var body: some View {
        HStack(spacing: 2) {
            if priority > 0 { 
                ForEach(0..<min(priority, 3), id: \.self) { _ in 
                    Image("Star")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14) 
                } 
            }
        }
    }
}

// 时间显示视图
struct TimeDisplayView: View {
    let taskDate: Date?
    
    var body: some View {
        // 创建一个基本的Text视图，然后根据条件应用不同的修饰符
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        let displayText = taskDate != nil ? 
            formatter.string(from: taskDate!) : 
            "00:00"
        
        return Text(displayText)
            .font(Font.custom("Inria Sans", size: 16).weight(.light))
            .foregroundColor(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .opacity(taskDate == nil ? 0 : 1) // 如果没有日期，则设为透明
    }
}

// 添加任务按钮
struct AddTaskButton: View {
    var body: some View {
        HStack {
            Image(systemName: "plus")
                .font(.system(size: 20))
                .foregroundColor(.white)
                .opacity(0.5)
            
            Text("Add test")
                .font(Font.custom("Inria Sans", size: 20).weight(.bold))
                .foregroundColor(.white)
                .opacity(0.5)
            
            Spacer()
        }
        .padding(.top, 12)
    }
}

struct SettlementView02_Previews: PreviewProvider {
    static var previews: some View {
        // 创建一些测试数据用于预览
        let testItems = [
            TodoItem(id: UUID(), userID: "testUser", title: "测试任务1", priority: 2, isPinned: false, taskDate: Date(), note: "", status: .undone, createdAt: Date(), updatedAt: Date(), correspondingImageID: ""),
            TodoItem(id: UUID(), userID: "testUser", title: "测试任务2", priority: 1, isPinned: true, taskDate: nil, note: "", status: .undone, createdAt: Date(), updatedAt: Date(), correspondingImageID: "")
        ]
        
        SettlementView02(uncompletedTasks: testItems, moveTasksToTomorrow: true)
    }
}
