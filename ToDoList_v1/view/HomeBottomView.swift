import SwiftUI

/// 主頁底部視圖：包含物理場景和按鈕
struct HomeBottomView: View {
    // 數據屬性
    let todoItems: [TodoItem]
    let refreshToken: UUID
    let isCurrentDay: Bool
    let isSyncing: Bool
    
    // 回調
    let onEndTodayTapped: () -> Void
    let onReturnToTodayTapped: () -> Void
    let onAddButtonTapped: () -> Void
    
    // 是否處於睡眠模式
    let isSleepMode: Bool
    let alarmTimeString: String
    let dayProgress: Double
    let onSleepButtonTapped: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            
            // 主視圖選擇
            if !isSleepMode {
                // 非睡眠模式
                if isCurrentDay {
                    // 當天顯示
                    currentDayView
                } else {
                    // 非當天顯示
                    otherDayView
                }
            } else {
                // 睡眠模式
                sleepModeView
            }
            
            // 底部間距
            Spacer().frame(height: 20)
        }
        .animation(.spring(response: 0.3), value: isCurrentDay)
        .animation(.spring(response: 0.3), value: isSleepMode)
    }
    
    // 當天視圖
    private var currentDayView: some View {
        VStack(spacing: 10) {
            // 1. 物理場景 (BumpyCircle 掉落動畫)
            PhysicsSceneWrapper(
                todoItems: todoItems,
                refreshToken: refreshToken
            )
            
            // 2. 底下兩個按鈕
            HStack(spacing: 10) {
                // end today 按鈕
                Button(action: onEndTodayTapped) {
                    // 根據同步狀態顯示不同文字
                    if isSyncing {
                        HStack {
                            Text("同步中...")
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        }
                        .frame(maxWidth: .infinity) // 使整個按鈕區域可點擊
                    } else {
                        Text("end today")
                            .frame(maxWidth: .infinity) // 使整個按鈕區域可點擊
                    }
                }
                .font(.custom("Inria Sans", size: 20).weight(.bold))
                .foregroundColor(.black)
                .frame(width: 272, height: 60)
                .background(Color.white)
                .cornerRadius(40.5)
                
                // plus 按鈕 - 新增任務
                Button(action: onAddButtonTapped) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 77)
                            .fill(Color(red: 0, green: 0.72, blue: 0.41))
                            .frame(width: 71, height: 60)
                        Image(systemName: "plus")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(Color.gray.opacity(0.2))
        )
        .transition(.opacity.combined(with: .scale))
    }
    
    // 非當天視圖
    private var otherDayView: some View {
        HStack(spacing: 10) {
            // return to today 按鈕
            Button(action: onReturnToTodayTapped) {
                // 根據同步狀態顯示不同文字
                if isSyncing {
                    HStack {
                        Text("同步中...")
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                    }
                    .frame(maxWidth: .infinity) // 使整個按鈕區域可點擊
                } else {
                    Text("return to today")
                        .frame(maxWidth: .infinity) // 使整個按鈕區域可點擊
                }
            }
            .font(.custom("Inria Sans", size: 20).weight(.bold))
            .foregroundColor(.black)
            .frame(width: 272, height: 60)
            .background(Color.white)
            .cornerRadius(40.5)
            
            // plus 按鈕 - 新增任務
            Button(action: onAddButtonTapped) {
                ZStack {
                    RoundedRectangle(cornerRadius: 77)
                        .fill(Color(red: 0, green: 0.72, blue: 0.41))
                        .frame(width: 71, height: 60)
                    Image(systemName: "plus")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(Color.gray.opacity(0.2))
        )
        .transition(.opacity.combined(with: .scale))
    }
    
    // 睡眠模式視圖
    private var sleepModeView: some View {
        VStack(spacing: 20) {
            HStack(spacing: 15) {
                Image(systemName: "moon.fill").font(.system(size: 20)).foregroundColor(.white.opacity(0.9))
                    .shadow(color: .white.opacity(0.4), radius: 25, x: 0, y: 0)
                    .shadow(color: .white.opacity(0.7), radius: 15, x: 0, y: 0)
                    .shadow(color: .white, radius: 7, x: 0, y: 0)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle().foregroundColor(Color.gray.opacity(0.35))
                        Rectangle()
                            .frame(width: max(0, geometry.size.width * CGFloat(dayProgress)))
                            .foregroundColor(.white)
                    }
                    .frame(height: 4)
                    .cornerRadius(2)
                    .clipped()
                }.frame(height: 4)
                Image(systemName: "bell.and.waves.left.and.right").font(.system(size: 16)).foregroundColor(.gray)
                Text(alarmTimeString)
                    .font(Font.custom("Inria Sans", size: 18.62571).weight(.light))
                    .multilineTextAlignment(.center).foregroundColor(.gray)
            }.padding(.top, 20)
            
            HStack(spacing: 10) {
                // back to sleep mode 按鈕
                Button(action: onSleepButtonTapped) {
                    Text("back to sleep mode")
                        .font(.custom("Inria Sans", size: 20).weight(.bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity) // 使整個按鈕區域可點擊
                }
                .frame(width: 272, height: 60)
                .background(Color.white)
                .cornerRadius(40.5)
                
                // plus 按鈕 - 新增任務
                Button(action: onAddButtonTapped) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 77)
                            .fill(Color(red: 0, green: 0.72, blue: 0.41))
                            .frame(width: 71, height: 60)
                        Image(systemName: "plus")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 32).fill(Color.white.opacity(0.15)))
        .transition(.opacity.combined(with: .scale))
    }
}