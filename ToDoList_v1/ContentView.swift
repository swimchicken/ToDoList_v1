import SwiftUI

struct ContentView: View {
    // 綠色光暈參數
    private let greenStages: [(width: CGFloat, height: CGFloat)] = [
        (411.6, 411.6),
        (522.6, 522.6),
        (693.85, 693.85)
    ]
    
    // 灰色光暈參數
    private let grayStages: [(width: CGFloat, height: CGFloat, cornerRadius: CGFloat)] = [
        (235.3, 235.3, 298.78),
        (298.78, 298.78, 298.78),
        (396.66, 396.66, 396.66)
    ]
    
    // 圖片＋文字資料
    private let stages: [(text: String, imageName: String)] = [
        ("計畫", "Tick01"),
        ("計畫-執行", "Tick02"),
        ("計畫-執行-回顧", "Tick03")
    ]
    
    // 動畫頁面階段
    @State private var currentStageIndex = 0
    // Splash 層透明度
    @State private var splashOpacity: Double = 1.0
    // Login 頁面透明度
    @State private var loginOpacity: Double = 0.0
    // 控制是否顯示 Splash 層
    @State private var showSplash: Bool = true
    
    var body: some View {
        ZStack {
            // 全螢幕黑色背景
            Color.black.ignoresSafeArea()
            
            if showSplash {
                // Splash 層 (以 transition 平滑移除)
                ZStack {
                    // 背景動畫層
                    ZStack {
                        // 綠色光暈
                        Rectangle()
                            .foregroundColor(.clear)
                            .frame(width: greenStages[currentStageIndex].width,
                                   height: greenStages[currentStageIndex].height)
                            .background(Color(red: 0.2, green: 0.66, blue: 0.33))
                            .cornerRadius(greenStages[currentStageIndex].width)
                            .blur(radius: 81.85)
                            .blendMode(.screen)
                            .animation(.easeInOut(duration: 0.8), value: currentStageIndex)
                        
                        // 灰色光暈（右下角）
                        Rectangle()
                            .foregroundColor(.clear)
                            .frame(width: grayStages[currentStageIndex].width,
                                   height: grayStages[currentStageIndex].height)
                            .background(Color(red: 0.63, green: 0.63, blue: 0.63))
                            .cornerRadius(grayStages[currentStageIndex].cornerRadius)
                            .blur(radius: 81.85)
                            .opacity(0.4)
                            .offset(x: 100, y: 150)
                            .blendMode(.screen)
                            .animation(.easeInOut(duration: 0.8), value: currentStageIndex)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 60)
                    .opacity(splashOpacity)
                    
                    // 文字搭配圖片 (依照 currentStageIndex 切換)
                    VStack {
                        Spacer()
                        if currentStageIndex == 0 {
                            Image("Tick01")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 246, height: 200)
                            Spacer().frame(height: 100)
                            Text("計畫")
                                .font(.title2)
                                .foregroundColor(.white)
                        } else if currentStageIndex == 1 {
                            Image("Tick02")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 246, height: 200)
                            Spacer().frame(height: 100)
                            Text("計畫-執行")
                                .font(.title2)
                                .foregroundColor(.white)
                        } else {
                            Image("Tick03")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 246, height: 200)
                            Spacer().frame(height: 100)
                            Text("計畫-執行-回顧")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    .opacity(splashOpacity)
                }
                .zIndex(0)
                .transition(.opacity)
            }
            
            // Login 頁面層 (預先佈局，透明度控制顯示)
            Login()
                .opacity(loginOpacity)
                .zIndex(1)
                .transition(.opacity)
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                if currentStageIndex < stages.count - 1 {
                    withAnimation {
                        currentStageIndex += 1
                    }
                }
                else {
                    showSplash = false
                    timer.invalidate()
                    withAnimation(.easeInOut(duration: 2.0)) {
//                        showSplash = false
                        splashOpacity = 0
                        loginOpacity = 1
                    }
                                   
                }
            }
        }
    }
}

#Preview {
    ContentView()
//        .modelContainer(for: Item.self, inMemory: true)
}
