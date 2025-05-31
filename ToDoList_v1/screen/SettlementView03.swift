import SwiftUI

// MARK: - Page03ProgressBarSegment (在 SettlementView03.swift 中定義，或從共用檔案引用)
// 如果您決定將 ProgressBarSegment 做成共用檔案，請確保 SettlementView03 能存取到它
// 並且其 isActive 的行為符合 SettlementView03 的需求：
// isActive = true: 綠色實心
// isActive = false: 深灰底綠框
struct Page03ProgressBarSegment: View { // 此處使用之前為 S03 設計的進度條
    let isActive: Bool
    private let segmentWidth: CGFloat = 160
    private let segmentHeight: CGFloat = 11
    private let segmentCornerRadius: CGFloat = 29

    var body: some View {
        if isActive {
            Rectangle()
                .fill(Color(red: 0, green: 0.72, blue: 0.41))
                .frame(width: segmentWidth, height: segmentHeight)
                .cornerRadius(segmentCornerRadius)
        } else {
            Rectangle()
                .fill(Color(red: 0.13, green: 0.13, blue: 0.13))
                .frame(width: segmentWidth, height: segmentHeight)
                .cornerRadius(segmentCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: segmentCornerRadius)
                        .inset(by: 0.5)
                        .stroke(Color(red: 0, green: 0.72, blue: 0.41), lineWidth: 1)
                )
        }
    }
}

// MARK: - SettlementView03.swift
struct SettlementView03: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedHour: Int = 8
    @State private var selectedMinute: Int = 0
    @State private var selectedAmPm: Int = 1
    @State private var isAlarmDisabled: Bool = false
    @State private var navigateToHome: Bool = false
    
    // 用於將設置傳遞給 Home 視圖
    class SleepSettings: ObservableObject {
        static let shared = SleepSettings()
        @Published var isSleepMode: Bool = false
        @Published var alarmTime: String = "9:00 AM"
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
        VStack(alignment: .leading, spacing: 15) {
            topHeaderSection // 使用分解後的子視圖

            MultiComponentPicker(
                hour: $selectedHour,
                minute: $selectedMinute,
                ampm: $selectedAmPm
            )
            .frame(height: 216)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 20)

            alarmToggleSection

            Spacer()

            bottomNavigationButtons
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.black.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .background(
            // 使用 isDetailLink: false 可以讓導航回到根視圖
            NavigationLink(
                destination: Home()
                    .navigationBarHidden(true)
                    .navigationBarBackButtonHidden(true)
                    .toolbar(.hidden, for: .navigationBar), 
                isActive: $navigateToHome,
                label: { EmptyView() }
            )
            .isDetailLink(false) // 這會重置導航堆疊
        )
    }

    // MARK: - Sub-views for SettlementView03
    private var topHeaderSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            progressAndCheckmarkView
            grayDivider
            whatToDoText
            dateDisplayView
            sunAndTempView
            greenLineImageView
        }
    }

    private var progressAndCheckmarkView: some View {
        // *** 修改此處佈局以避免重疊 ***
        HStack {
            Spacer() // 左邊 Spacer，用於輔助居中進度條

            // 進度條組
            HStack(spacing: 8) {
                Page03ProgressBarSegment(isActive: true) // SettlementView03 使用自己的進度條定義
                Page03ProgressBarSegment(isActive: false)
            }
            
            Spacer() // 中間 Spacer，將打勾圖示推到最右邊

            Image(systemName: "checkmark")
                .foregroundColor(.gray)
                .padding(5)
                .background(Color.gray.opacity(0.3))
                .clipShape(Circle())
        }
        .padding(.top, 5)
    }

    private var grayDivider: some View {
        Rectangle()
            .frame(height: 1)
            .foregroundColor(Color(red: 0.34, green: 0.34, blue: 0.34))
            .padding(.vertical, 10)
    }

    private var whatToDoText: some View {
        HStack {
            Text("What do you want to at")
                .font(Font.custom("Instrument Sans", size: 13).weight(.semibold))
                .foregroundColor(.white)
            Spacer()
        }
    }

    private var dateDisplayView: some View {
        let tomorrowParts = formatDateForDisplay(tomorrow)
        return HStack(alignment: .bottom) {
            Text("Tomorrow")
                .font(Font.custom("Instrument Sans", size: 31.79449).weight(.bold))
                .foregroundColor(.white)
            Spacer()
            HStack(spacing: 0) {
                Text(tomorrowParts.monthDay)
                    .font(Font.custom("Instrument Sans", size: 20.65629).weight(.bold))
                    .foregroundColor(.white)
                Text("   ")
                Text(tomorrowParts.weekday)
                    .font(Font.custom("Instrument Sans", size: 20.65629).weight(.bold))
                    .foregroundColor(.gray)
            }
        }
    }

    private var sunAndTempView: some View {
        HStack {
            Image(systemName: "sun.max.fill")
                .foregroundColor(.yellow)
            Text("26°C")
                .font(Font.custom("Inria Sans", size: 11.73462))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.top, 2)
    }

    private var greenLineImageView: some View {
        Image("Vector 81")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity)
            .padding(.top, 5)
    }

    private var alarmToggleSection: some View {
        HStack {
            Text("不使用鬧鐘")
                .font(Font.custom("Inter", size: 16))
                .foregroundColor(.white)
            Spacer()
            Toggle("", isOn: $isAlarmDisabled)
                .labelsHidden()
                .tint(.green)
        }
        .padding()
        .background(Color(white: 0.15))
        .cornerRadius(10)
    }

    private var bottomNavigationButtons: some View {
        HStack {
            Button(action: {
                // 返回上一頁
                self.presentationMode.wrappedValue.dismiss()
            }) { 
                Text("返回").font(Font.custom("Inria Sans", size: 20)).foregroundColor(.white) 
            }.padding()
            Spacer()
            Button(action: {
                // 保存鬧鐘設置
                let hourToSave = selectedHour
                let minuteToSave = selectedMinute
                let ampmToSave = selectedAmPm == 0 ? "AM" : "PM"
                let alarmEnabled = !isAlarmDisabled
                
                // 格式化時間字符串，確保分鐘有兩位數字
                let formattedMinute = String(format: "%02d", minuteToSave)
                let alarmTimeFormatted = "\(hourToSave):\(formattedMinute) \(ampmToSave)"
                
                print("保存鬧鐘設置: \(alarmTimeFormatted), 啟用: \(alarmEnabled)")
                
                // 保存到共享設置
                SleepSettings.shared.isSleepMode = true
                SleepSettings.shared.alarmTime = alarmTimeFormatted
                
                // 保存到 UserDefaults，以便在應用重啟後仍能保持狀態
                UserDefaults.standard.set(true, forKey: "isSleepMode")
                UserDefaults.standard.set(alarmTimeFormatted, forKey: "alarmTimeString")
                
                // 完成設置並回到 Home 頁面
                navigateToHome = true
            }) { 
                Text("Finish").font(Font.custom("Inria Sans", size: 20).weight(.bold)).multilineTextAlignment(.center).foregroundColor(.black).frame(width: 87.68571, alignment: .top) 
            }
            .frame(width: 279, height: 60).background(.white).cornerRadius(40.5)
        }
        .padding(.bottom, 10)
    }
}

#Preview {
    SettlementView03()
}
