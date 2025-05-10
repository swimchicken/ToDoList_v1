import SwiftUI

struct Today: View {
    @State private var moveToTomorrow = true
    
    // 已完成的任務
    let completedTasks = [
        "完成設計提案初稿",
        "Prepare tomorrow's meeting report",
        "整理桌面和文件夾",
        "寫一篇實習筆記"
    ]
    
    // 未完成的任務
    let incompleteTasks = [
        "回覆所有未讀郵件",
        "練習日語聽力",
        "市場研究"
    ]
    
    var body: some View {
        ZStack {
            // 黑色背景
            Color.black
                .ignoresSafeArea()
            
            // 為整個內容添加邊距
            VStack(spacing: 0) {
                // 頂部日期
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text("Jan 12")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                            Text("Tuesday")
                                .font(.system(size: 15))
                                .foregroundColor(.gray)
                        }
                        
                        // 分隔線
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color(red: 0.34, green: 0.34, blue: 0.34))
                    }
                    
                    Spacer()
                }
                
                // 主要內容
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // 標題
                        VStack(alignment: .leading, spacing: 8) {
                            Text("你今天完成了")
                                .font(.system(size: 15))
                                .foregroundColor(.gray)
                                .padding(.leading, 20)
                            
                            Text("4個任務")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.leading, 20)
                        }
                        .padding(.top, 20)
                        
                        // 已完成的任務
                        VStack(spacing: 16) {
                            ForEach(completedTasks, id: \.self) { task in
                                TaskRow(taskTitle: task, isCompleted: true)
                            }
                        }
                        .padding(.top, 10)
                        
                        // 未完成任務標題
                        HStack {
                            Text("3 個任務尚未完成")
                                .font(.system(size: 15))
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .padding(.leading, 20)
                        .padding(.top, 30)
                        
                        // 未完成的任務
                        VStack(spacing: 16) {
                            ForEach(incompleteTasks, id: \.self) { task in
                                TaskRow(taskTitle: task, isCompleted: false)
                            }
                        }
                        
                        // 開關選項
                        HStack {
                            Text("將來完成的任務直接移至明日代辦")
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Toggle("", isOn: $moveToTomorrow)
                                .labelsHidden()
                                .scaleEffect(0.8)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // 底部按鈕
                        VStack(spacing: 20) {
                            Button(action: {
                                // 開始設定明日計畫
                            }) {
                                Text("開始設定明日計畫")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.white)
                                    .cornerRadius(25)
                            }
                            .padding(.horizontal, 20)
                            
                            // 返回按鈕
                            Button(action: {
                                // 返回操作
                            }) {
                                Text("返回")
                                    .font(.system(size: 17))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.top, 40)
                        .padding(.bottom, 30)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 60)
        }
    }
}

// 任務行組件
struct TaskRow: View {
    let taskTitle: String
    let isCompleted: Bool
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // 完成狀態圓圈
            ZStack {
                Circle()
                    .stroke(Color.green, lineWidth: 2)
                    .frame(width: 20, height: 20)
                
                if isCompleted {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 20, height: 20)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                }
            }
            
            // 任務文字
            Text(taskTitle)
                .font(.system(size: 16))
                .foregroundColor(isCompleted ? .gray : .white)
                .strikethrough(isCompleted)
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    Today()
}
