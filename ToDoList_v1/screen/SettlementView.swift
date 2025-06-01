import SwiftUI
import CoreGraphics // Import CoreGraphics for explicit math functions if needed

// MARK: - TodoItem.swift
// 主資料結構：待辦事項 (TodoItem) - 假設已在別處定義
// enum TodoStatus: String, Codable - 假設已在別處定義

// 更新 CircleShapeView 以使用 Image Asset，並移除內部固定 frame
struct CircleShapeView: View {
    let imageName: String // 圖片名稱，例如 "Circle01", "Circle02", "Circle03"
    
    var body: some View {
        Image(imageName)
            .resizable() // 使圖片可縮放以填充框架
            .aspectRatio(contentMode: .fit) // 保持圖片的原始長寬比，完整顯示
            // 如果SVG本身不是圓形透明背景，可能需要 .clipShape(Circle()) 來確保圓形外觀
    }
}

// 更新綠色球球的視圖：移除描邊，加深顏色，確保圓形裁剪
struct GreenCircleImageView: View {
    let imageName: String
    var body: some View {
        Image(imageName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            // 移除了之前的矩形描邊 .overlay(...)
            .clipShape(Circle()) // 確保圖片本身被裁剪成圓形
            .overlay( // 添加半透明黑色疊加層以加深顏色
                Circle() // 疊加一個圓形的顏色
                    .fill(Color.black.opacity(0.2)) // 調整 opacity 來控制加深程度
            )
    }
}


struct SettlementView: View {

    // 模擬數據，之後你可以從你的數據源加載
    @State private var completedTasks: [TodoItem] = []
    @State private var uncompletedTasks: [TodoItem] = []
    @State private var moveUncompletedTasksToTomorrow: Bool = true
    @State private var navigateToSettlementView02: Bool = false // 導航到下一頁

    // 日期相關
    private var yesterday: Date {
        return Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    }
    // 左側日期先假定一個，例如7天前
    private var leftDisplayDate: Date {
        return Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    }

    // 更新 formatDate 以返回月日和星期兩個部分
    private func formatDateForDisplay(_ date: Date) -> (monthDay: String, weekday: String) {
        let dateFormatterMonthDay = DateFormatter()
        dateFormatterMonthDay.locale = Locale(identifier: "en_US_POSIX") // 確保英文月份
        dateFormatterMonthDay.dateFormat = "MMM dd" // 例如：Jan 01
        
        let dateFormatterWeekday = DateFormatter()
        dateFormatterWeekday.locale = Locale(identifier: "en_US_POSIX") // 確保英文星期
        dateFormatterWeekday.dateFormat = "EEEE" // 例如：Tuesday
        
        return (dateFormatterMonthDay.string(from: date), dateFormatterWeekday.string(from: date))
    }

    var body: some View {
        ZStack {
            // 背景顏色修改為全黑
            Color.black
                .edgesIgnoringSafeArea(.all)

            VStack(alignment: .leading, spacing: 0) {
                // 1. 頂部日期選擇器
                TopDateView(
                    leftDateParts: formatDateForDisplay(leftDisplayDate),
                    rightDateParts: formatDateForDisplay(yesterday)
                )
                .padding(.bottom, 20) // 日期選擇器下方的間距

                // 日期下方的分隔線 - 修改為響應式寬度
                Rectangle()
                    .frame(height: 1) // 線條高度
                    .foregroundColor(Color(red: 0.34, green: 0.34, blue: 0.34)) // 線條顏色
                                
                // 2. 標題 - 更新文字風格
                VStack(alignment: .leading, spacing: 4) {
                    Text("未結算提醒")
                        .font(Font.custom("Instrument Sans", size: 13).weight(.bold))
                        .foregroundColor(.white)
                    Text("你尚未結算之前的任務")
                        .font(Font.custom("Instrument Sans", size: 31.79449).weight(.bold))
                        .foregroundColor(.white)
                }
                .padding(.top, 20) // 分隔線與標題之間的間距

                ScrollView {
                    // 調整 VStack 的 spacing 以減少項目間的垂直距離
                    VStack(alignment: .leading, spacing: 10) {
                        
                        // 3. 已完成任務列表區域 (使用 ZStack 包裹以添加背景球球)
                        ZStack(alignment: .topLeading) {
                            GeometryReader { geo in
                                // 放置五個綠色球球，更新 frame 和 position
                                GreenCircleImageView(imageName: "GreenCircle01")
                                    .frame(width: 33, height: 32)
                                    .position(x: geo.size.width * 0.7, y: geo.size.height * 0.1)

                                GreenCircleImageView(imageName: "GreenCircle02")
                                    .frame(width: 79, height: 79)
                                    .position(x: geo.size.width * 0.9, y: geo.size.height * 0.55)

                                GreenCircleImageView(imageName: "GreenCircle03")
                                    .frame(width: 59, height: 58)
                                    .position(x: geo.size.width * 0.55, y: geo.size.height * 0.85)

                                GreenCircleImageView(imageName: "GreenCircle04")
                                     .frame(width: 58, height: 58)
                                     .position(x: geo.size.width * 0.2, y: geo.size.height * 0.65)

                                GreenCircleImageView(imageName: "GreenCircle05")
                                     .frame(width: 67, height: 67)
                                     .position(x: geo.size.width * 0.35, y: geo.size.height * 0.25)
                            }
                            .opacity(0.5) // 保持背景球球的整體半透明效果

                            // 實際的已完成任務列表
                            VStack(alignment: .leading, spacing: 10) {
                                if !completedTasks.isEmpty {
                                    ForEach(completedTasks) { task in
                                        TaskRow(task: task, isCompleted: true)
                                    }
                                } else {
                                    MockTaskRow(title: "完成設計提案初稿", isCompleted: true)
                                    MockTaskRow(title: "Prepare tomorrow's meeting report", isCompleted: true)
                                    MockTaskRow(title: "整理桌面和文件夾", isCompleted: true)
                                    MockTaskRow(title: "寫一篇學習筆記", isCompleted: true)
                                }
                            }
                        }
                        .frame(minHeight: 200) // 確保 ZStack 有足夠高度讓 GeometryReader 工作

                        Spacer(minLength: 20)

                        // 4. 未完成任務列表
                        Text("\(uncompletedTasks.isEmpty ? 3 : uncompletedTasks.count)個任務尚未達成")
                            .font(Font.custom("Instrument Sans", size: 13).weight(.semibold))
                            .foregroundColor(.white)

                        if !uncompletedTasks.isEmpty {
                            ForEach(uncompletedTasks) { task in
                                TaskRow(task: task, isCompleted: false)
                            }
                        } else {
                            MockTaskRow(title: "回覆所有未讀郵件", isCompleted: false)
                            MockTaskRow(title: "練習日語聽力", isCompleted: false)
                            MockTaskRow(title: "市場研究", isCompleted: false)
                        }
                    }
                    .padding(.top, 20)
                }
                
                ZStack {
                    Color.clear.frame(height: 80)

                    HStack(spacing: 30) {
                        CircleShapeView(imageName: "Circle01")
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                            .offset(y: 15)
                        
                        CircleShapeView(imageName: "Circle02")
                            .frame(width: 59, height: 59)
                            .clipShape(Circle())
                            .offset(x: 0, y: 0)
                        
                        CircleShapeView(imageName: "Circle03")
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                            .offset(y: 15)
                    }
                    .offset(x: 40)
                }

                BottomControlsView(
                    moveUncompletedTasksToTomorrow: $moveUncompletedTasksToTomorrow,
                    navigateToSettlementView02: $navigateToSettlementView02
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 60)
        }
        .onAppear {
            loadSampleTasks()
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .background(
            NavigationLink(destination: SettlementView02(), isActive: $navigateToSettlementView02) {
                EmptyView()
            }
        )
    }

    func loadSampleTasks() {
        if completedTasks.isEmpty {
        }
        if uncompletedTasks.isEmpty {
        }
    }
}

// MARK: - 子視圖 (Components)

struct TopDateView: View {
    let leftDateParts: (monthDay: String, weekday: String)
    let rightDateParts: (monthDay: String, weekday: String)

    var body: some View {
        HStack {
            DateDisplay(monthDayString: leftDateParts.monthDay, weekdayString: leftDateParts.weekday)
            Spacer()
            Image("line01")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 2)
            Spacer()
            DateDisplay(monthDayString: rightDateParts.monthDay, weekdayString: rightDateParts.weekday)
        }
        .padding(.vertical, 10)
    }
}

struct DateDisplay: View {
    let monthDayString: String
    let weekdayString: String

    var body: some View {
        HStack(spacing: 5) {
            Text(monthDayString)
                .font(Font.custom("Instrument Sans", size: 16).weight(.bold))
                .foregroundColor(.white)
            Text(weekdayString)
                .font(Font.custom("Instrument Sans", size: 16).weight(.bold))
                .foregroundColor(.white)
                .opacity(0.5)
        }
    }
}

struct TaskRow: View {
    let task: TodoItem
    let isCompleted: Bool

    var body: some View {
        HStack(spacing: 12) {
            if isCompleted {
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: 17, height: 17)
                    .background(Color(red: 0, green: 0.72, blue: 0.41))
                    .cornerRadius(40.5)

                Text(task.title)
                    .font(Font.custom("Inria Sans", size: 14).weight(.bold))
                    .foregroundColor(Color(red: 0, green: 0.72, blue: 0.41))
                    .frame(height: 15, alignment: .topLeading)
                    .lineLimit(1)
            } else {
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: 17, height: 17)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(40.5)

                Text(task.title)
                    .font(Font.custom("Inria Sans", size: 14).weight(.bold))
                    .foregroundColor(Color(red: 0.52, green: 0.52, blue: 0.52))
                    .frame(height: 15, alignment: .topLeading)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    static var staticUncompletedTasks: [TodoItem] = [
        TodoItem(id: UUID(), userID: "user1", title: "市場研究", priority: 0, isPinned: false, note: "aa", status: .undone, createdAt: Date(), updatedAt: Date(), correspondingImageID: "")
    ]
}

struct MockTaskRow: View {
    let title: String
    let isCompleted: Bool

    var body: some View {
        HStack(spacing: 12) {
            if isCompleted {
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: 17, height: 17)
                    .background(Color(red: 0, green: 0.72, blue: 0.41))
                    .cornerRadius(40.5)

                Text(title)
                    .font(Font.custom("Inria Sans", size: 14).weight(.bold))
                    .foregroundColor(Color(red: 0, green: 0.72, blue: 0.41))
                    .frame(height: 15, alignment: .topLeading)
                    .lineLimit(1)
            } else {
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: 17, height: 17)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(40.5)

                Text(title)
                    .font(Font.custom("Inria Sans", size: 14).weight(.bold))
                    .foregroundColor(Color(red: 0.52, green: 0.52, blue: 0.52))
                    .frame(height: 15, alignment: .topLeading)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct BottomControlsView: View {
    @Binding var moveUncompletedTasksToTomorrow: Bool
    @Binding var navigateToSettlementView02: Bool  // 添加導航綁定
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("將未完成的任務直接移至明日待辦")
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                Spacer()
                Toggle("", isOn: $moveUncompletedTasksToTomorrow)
                    .labelsHidden()
                    .tint(.green)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)

            Button(action: {
                // 導航到 SettlementView02
                navigateToSettlementView02 = true
            }) {
                Text("開始設定今天的計畫")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(25)
            }
            
            // 返回按鈕
            Button(action: {
                // 返回上一頁
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("返回首頁")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
        }
    }
}

// MARK: - Preview
struct SettlementView_Previews: PreviewProvider {
    static var previews: some View {
        SettlementView()
    }
}
