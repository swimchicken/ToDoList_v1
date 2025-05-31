import SwiftUI

struct Sleep01View: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var currentDate = Date()
    @State private var dayProgress: Double = 0.0
    @State private var isAlarmTimePassedToday: Bool = false
    @State private var navigateToHome: Bool = false

    let alarmTimeString = "9:00 AM"

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var taipeiCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return calendar
    }

    private var alarmStringParser: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return formatter
    }
    
    private var topDateMonthDayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return formatter
    }

    private var topDateDayOfWeekFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return formatter
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"
        formatter.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return formatter
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .lastTextBaseline, spacing: 5) {
                    Text(currentDate, formatter: topDateMonthDayFormatter)
                        .font(Font.custom("Instrument Sans", size: 17.31818).weight(.bold))
                        .foregroundColor(.white)
                    Text(currentDate, formatter: topDateDayOfWeekFormatter)
                        .font(Font.custom("Instrument Sans", size: 17.31818).weight(.bold))
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal, 37).padding(.top, 15)
                Rectangle().frame(height: 1).foregroundColor(Color(red: 0.34, green: 0.34, blue: 0.34)).padding(.vertical, 12)
                HStack {
                    Text(currentDate, formatter: timeFormatter)
                        .font(Font.custom("Inria Sans", size: 47.93416).weight(.bold))
                        .multilineTextAlignment(.center).foregroundColor(.white)
                    Spacer()
                    Text("...").font(.system(size: 30, weight: .bold)).foregroundColor(.white).padding(.trailing, 10)
                }.padding(.leading, 37)
                HStack(spacing: 8) {
                    Image(systemName: "bell.and.waves.left.and.right")
                        .font(.system(size: 18)).foregroundColor(.gray)
                    Text(alarmTimeString)
                        .font(Font.custom("Inria Sans", size: 18.62571).weight(.light))
                        .multilineTextAlignment(.center).foregroundColor(.gray)
                }.padding(.leading, 40).padding(.top, 8)
                Spacer()
                
                VStack {
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
                                .cornerRadius(2)
                                .clipped()
                            }
                            .frame(height: 4)

                            Image(systemName: "bell.and.waves.left.and.right").font(.system(size: 16)).foregroundColor(.gray)
                            Text(alarmTimeString)
                                .font(Font.custom("Inria Sans", size: 18.62571).weight(.light))
                                .multilineTextAlignment(.center).foregroundColor(.gray)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        Button(action: {
                            UserDefaults.standard.set(true, forKey: "isSleepMode")
                            UserDefaults.standard.set(alarmTimeString, forKey: "alarmTimeString")
                            navigateToHome = true
                        }) {
                            Text("back to home page")
                                .font(Font.custom("Inria Sans", size: 20).weight(.bold))
                                .foregroundColor(.white)
                        }
                        // --- ERROR FIX ---
                        .frame(maxWidth: .infinity) // Set max width
                        .frame(height: 60)          // THEN set fixed height
                        // --- END ERROR FIX ---
                        .background(Color(white: 0.35, opacity: 0.9))
                        .cornerRadius(30)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 32).fill(Color.white.opacity(0.15)))
                    .padding(.bottom, 30)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
            .navigationBarBackButtonHidden(true)
            .navigationBarHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .background(
                NavigationLink(
                    destination: Home()
                        .navigationBarHidden(true)
                        .navigationBarBackButtonHidden(true)
                        .toolbar(.hidden, for: .navigationBar),
                    isActive: $navigateToHome,
                    label: { EmptyView() }
                )
                .isDetailLink(false)
            )
            .onReceive(timer) { receivedTime in
                self.currentDate = receivedTime

                let calendar = self.taipeiCalendar
                let localAlarmStringParser = self.alarmStringParser
                var newProgress = 0.0

                guard let parsedAlarmTime = localAlarmStringParser.date(from: alarmTimeString) else {
                    self.dayProgress = 0.0
                    self.isAlarmTimePassedToday = false
                    return
                }
                let alarmHourMinuteComponents = calendar.dateComponents([.hour, .minute], from: parsedAlarmTime)
                guard let alarmHour = alarmHourMinuteComponents.hour,
                      let alarmMinute = alarmHourMinuteComponents.minute else {
                    self.dayProgress = 0.0
                    self.isAlarmTimePassedToday = false
                    return
                }

                var todayAlarmDateComponents = calendar.dateComponents([.year, .month, .day], from: receivedTime)
                todayAlarmDateComponents.hour = alarmHour
                todayAlarmDateComponents.minute = alarmMinute
                todayAlarmDateComponents.second = 0
                guard let alarmTimeOnCurrentDay = calendar.date(from: todayAlarmDateComponents) else {
                    self.dayProgress = 0.0
                    self.isAlarmTimePassedToday = false
                    return
                }

                self.isAlarmTimePassedToday = receivedTime >= alarmTimeOnCurrentDay
                
                let cycleStart: Date
                let cycleEnd: Date

                if receivedTime < alarmTimeOnCurrentDay {
                    cycleEnd = alarmTimeOnCurrentDay
                    guard let yesterdayAlarmTime = calendar.date(byAdding: .day, value: -1, to: cycleEnd) else {
                        self.dayProgress = 0.0; return
                    }
                    cycleStart = yesterdayAlarmTime
                } else {
                    cycleStart = alarmTimeOnCurrentDay
                    guard let tomorrowAlarmTime = calendar.date(byAdding: .day, value: 1, to: cycleStart) else {
                        self.dayProgress = 0.0; return
                    }
                    cycleEnd = tomorrowAlarmTime
                }

                let totalCycleDuration = cycleEnd.timeIntervalSince(cycleStart)
                let elapsedInCycle = receivedTime.timeIntervalSince(cycleStart)

                if totalCycleDuration > 0 {
                    newProgress = elapsedInCycle / totalCycleDuration
                }
                
                self.dayProgress = min(max(newProgress, 0.0), 1.0)
            }
        }
    }
}

// Assuming you have Home struct defined elsewhere in your project.
// struct Home: View { ... }

#Preview {
    NavigationView {
        Sleep01View()
    }
}
