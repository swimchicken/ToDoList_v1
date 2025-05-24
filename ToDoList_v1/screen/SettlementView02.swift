import SwiftUI

// ProgressBarSegment 結構定義 (保持不變)
struct ProgressBarSegment: View {
    let isActive: Bool
    let width: CGFloat
    let height: CGFloat = 11
    let cornerRadius: CGFloat = 29

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 0.13, green: 0.13, blue: 0.13))
                .frame(width: width, height: height)
                .cornerRadius(cornerRadius)

            if isActive {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color(red: 0, green: 0.72, blue: 0.41), lineWidth: 1)
                    .frame(width: width, height: height)
            }
        }
    }
}

// MARK: - SettlementView02.swift
struct SettlementView02: View {

    // ... (State variables and other functions remain the same) ...
    @State private var dailyTasks: [(title: String, iconName: String, time: String, priority: Int, isPinned: Bool)] = [
        ("完成設計提案初稿", "Vector", "", 2, true),
        ("練習日語聽力", "Vector", "10:00", 3, false),
        ("Shiro birthday", "Vector", "10:00", 1, false),
        ("另一項無時間任務", "Vector", "", 0, false)
    ]

    @State private var todoQueueItems: [TodoItem] = [
        TodoItem(id: UUID(), userID: "user1", title: "回覆所有未讀郵件", priority: 1, isPinned: false, taskDate: nil, note: "", status: .toDoList, createdAt: Date(), updatedAt: Date(), correspondingImageID: ""),
        TodoItem(id: UUID(), userID: "user1", title: "整理桌面和文件夾", priority: 1, isPinned: false, taskDate: nil, note: "", status: .toDoList, createdAt: Date(), updatedAt: Date(), correspondingImageID: ""),
        TodoItem(id: UUID(), userID: "user1", title: "寫一篇學習筆記", priority: 1, isPinned: false, taskDate: nil, note: "", status: .toDoList, createdAt: Date(), updatedAt: Date(), correspondingImageID: "")
    ]
    @State private var selectedFilterInSettlement = "全部"
    @State private var showTodoQueue: Bool = false
    
    private var bottomFixedUIHeight: CGFloat { // 保持這個輔助計算
        var height: CGFloat = 0
        height += 50
        if showTodoQueue {
            height += 300
        }
        height += 70
        return height
    }
    
    private var tomorrow: Date {
        return Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }

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
            // --- Layer 1: 主要滾動內容 ---
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 15) {
                    // ... (頂部固定內容，保持不變) ...
                    HStack(spacing: 8) {
                        GeometryReader { geometry in
                            HStack(spacing: 8) {
                                let segmentWidth = (geometry.size.width - 8) / 2
                                ProgressBarSegment(isActive: true, width: segmentWidth)
                                ProgressBarSegment(isActive: false, width: segmentWidth)
                            }
                        }
                        .frame(height: 11)
                        Image(systemName: "checkmark").foregroundColor(.gray).padding(5).background(Color.gray.opacity(0.3)).clipShape(Circle())
                    }
                    .padding(.top, 5)

                    Rectangle().frame(height: 1).foregroundColor(Color(red: 0.34, green: 0.34, blue: 0.34)).padding(.vertical, 10)
                    HStack {
                        Text("What do you want to wake up at")
                            .font(Font.custom("Instrument Sans", size: 13).weight(.semibold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    let tomorrowParts = formatDateForDisplay(tomorrow)
                    HStack(alignment: .bottom) {
                        Text("Tomorrow").font(Font.custom("Instrument Sans", size: 31.79449).weight(.bold)).foregroundColor(.white)
                        Spacer()
                        Text(tomorrowParts.monthDay).font(Font.custom("Instrument Sans", size: 20.65629).weight(.bold)).foregroundColor(.white)
                        + Text("   ")
                        + Text(tomorrowParts.weekday).font(Font.custom("Instrument Sans", size: 20.65629).weight(.bold)).foregroundColor(.gray)
                    }
                    HStack {
                        Image(systemName: "bell").foregroundColor(.blue).font(.system(size: 11.73462))
                        Text("9:00 awake").font(Font.custom("Inria Sans", size: 11.73462)).multilineTextAlignment(.center).foregroundColor(.white)
                        Spacer()
                    }
                    Image("Vector 81").resizable().aspectRatio(contentMode: .fit).frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 15)

                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        // ... (任務列表 dailyTasks ForEach，保持不變) ...
                        VStack(spacing: 0) {
                            ForEach(dailyTasks.indices, id: \.self) { index in
                                let task = dailyTasks[index]
                                VStack(spacing: 0) {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Rectangle().foregroundColor(.clear).frame(width: 28, height: 28).background(Color.white.opacity(0.15)).cornerRadius(40.5)
                                            Image("Vector").resizable().scaledToFit().frame(width: 15.35494, height: 14.54678)
                                        }
                                        Text(task.title).font(Font.custom("Inria Sans", size: 16).weight(.bold)).foregroundColor(.white).lineLimit(1).layoutPriority(1)
                                        Spacer()
                                        HStack(spacing: 12) {
                                            Group {
                                                if task.isPinned {
                                                    Image(systemName: "pin.fill").foregroundColor(.white).font(.system(size: 14))
                                                } else {
                                                    HStack(spacing: 2) {
                                                        if task.priority > 0 { ForEach(0..<min(task.priority, 3), id: \.self) { _ in Image("Star").resizable().scaledToFit().frame(width: 14, height: 14) } }
                                                    }
                                                }
                                            }.frame(minWidth: 14 * 3 + 2 * 2, alignment: .leading)
                                            Group {
                                                if !task.time.isEmpty {
                                                    Text(task.time).font(Font.custom("Inria Sans", size: 16).weight(.light)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.7)
                                                } else {
                                                    Text("00:00").font(Font.custom("Inria Sans", size: 16).weight(.light)).opacity(0)
                                                }
                                            }.frame(width: 39.55874, height: 20.58333, alignment: .topLeading)
                                            Image(systemName: "xmark.circle.fill").foregroundColor(.gray.opacity(0.6))
                                        }.fixedSize(horizontal: true, vertical: false)
                                    }.padding(.vertical, 12)
                                    if index < dailyTasks.count - 1 {
                                        Rectangle().frame(height: 1).foregroundColor(Color(red: 0.34, green: 0.34, blue: 0.34))
                                    }
                                }
                            }
                            HStack {
                               Image(systemName: "plus").font(.system(size: 20)).foregroundColor(.white).opacity(0.5)
                               Text("Add test").font(Font.custom("Inria Sans", size: 20).weight(.bold)).foregroundColor(.white).opacity(0.5)
                               Spacer()
                            }.padding(.top, 12)
                        }
                        .padding(.top, 10) // 原VStack的padding
                    }
                    .padding(.bottom, bottomFixedUIHeight + 20)
                }
                .scrollIndicators(.hidden)
                .padding(.horizontal, 12)
            }
            .padding(.top, 60)

            // --- Layer 2: 固定在底部的 UI ---
            VStack(spacing: 0) {
                if showTodoQueue {
                    TobestartedView(
                        items: $todoQueueItems,
                        selectedFilter: $selectedFilterInSettlement,
                        collapseAction: { // *** 傳遞收合動作 ***
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
                    Button(action: {}) {
                        Text("返回")
                            .font(Font.custom("Inria Sans", size: 20))
                            .foregroundColor(.white)
                    }
                    .padding()
                    Spacer()
                    Button(action: {}) {
                        Text("Next")
                            .font(Font.custom("Inria Sans", size: 20).weight(.bold))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.black)
                            .frame(width: 87.68571, alignment: .top)
                    }
                    .frame(width: 279, height: 60)
                    .background(.white)
                    .cornerRadius(40.5)
                }
                .padding(.horizontal, 12)
            }
            .padding(.bottom, 60)
            .background(Color.black)
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .edgesIgnoringSafeArea(.bottom)
    }
}

// Preview
struct SettlementView02_Previews: PreviewProvider {
    static var previews: some View {
        SettlementView02()
    }
}
