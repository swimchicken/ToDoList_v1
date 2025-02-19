//
//  ContentView.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/2/17.
//

import SwiftUI

struct ContentView: View {
    // 定義三階段對應的「綠色光暈」參數
    private let greenStages: [(width: CGFloat, height: CGFloat)] = [
        (411.59579, 411.59579),
        (522.63934, 522.63934),
        (693.85175, 693.85175)
    ]
    
    // 定義三階段對應的「灰色光暈」參數 (右下角)
    private let grayStages: [(width: CGFloat, height: CGFloat, cornerRadius: CGFloat)] = [
        (235.30211, 235.30211, 298.78375),
        (298.78375, 298.78375, 298.78375),
        (396.6629, 396.6629, 396.6629)
    ]
    
    // 每個階段對應的：文字、圖片名稱
    private let stages: [(text: String, imageName: String)] = [
        ("計畫", "Tick01"),
        ("計畫-執行", "Tick02"),
        ("計畫-執行-回顧", "Tick03")
    ]
    
    // 目前顯示的階段索引
    @State private var currentStageIndex = 0
    
    var body: some View {
        ZStack {
            // 1. 背景底色
            Color.black
                .edgesIgnoringSafeArea(.all)
            
            // 2. 綠色光暈 (背景較大)
            Rectangle()
                .foregroundColor(.clear)
                .frame(
                    width: greenStages[currentStageIndex].width,
                    height: greenStages[currentStageIndex].height
                )
                .background(Color(red: 0.2, green: 0.66, blue: 0.33))
                .cornerRadius(greenStages[currentStageIndex].width) // 讓矩形近似圓形
                .blur(radius: 81.85)
                .blendMode(.screen)
                // 切換階段時做插值動畫
                .animation(.easeInOut(duration: 0.8), value: currentStageIndex)
            
            // 3. 灰色光暈 (右下角)
            Rectangle()
                .foregroundColor(.clear)
                .frame(
                    width: grayStages[currentStageIndex].width,
                    height: grayStages[currentStageIndex].height
                )
                .background(Color(red: 0.63, green: 0.63, blue: 0.63))
                .cornerRadius(grayStages[currentStageIndex].cornerRadius)
                .blur(radius: 81.85)
                .opacity(0.4)
                .offset(x: 100, y: 150) // 可依照實際設計需要微調
                .blendMode(.screen)
                .animation(.easeInOut(duration: 0.8), value: currentStageIndex)
            
            // 4. 中心內容
            VStack {
                Spacer()
                
                // (a) 圖片區：ZStack + 條件式，做交叉淡入淡出
                ZStack {
                    if currentStageIndex == 0 {
                        Image("Tick01")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 246, height: 200)
                            .transition(.opacity)
                    } else if currentStageIndex == 1 {
                        Image("Tick02")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 246, height: 200)
                            .transition(.opacity)
                    } else {
                        Image("Tick03")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 246, height: 200)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.8), value: currentStageIndex)
                
                Spacer()
                
                // (b) 文字區：ZStack + 條件式，做交叉淡入淡出
                ZStack {
                    if currentStageIndex == 0 {
                        Text("計畫")
                            .font(.title2)
                            .foregroundColor(.white)
                            .transition(.opacity)
                    } else if currentStageIndex == 1 {
                        Text("計畫-執行")
                            .font(.title2)
                            .foregroundColor(.white)
                            .transition(.opacity)
                    } else {
                        Text("計畫-執行-回顧")
                            .font(.title2)
                            .foregroundColor(.white)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.8), value: currentStageIndex)
                
                Spacer()
            }
        }
        .onAppear {
            // 5. 計時器：每 2 秒切換到下一階段
            Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { timer in
                if currentStageIndex < stages.count - 1 {
                    // 直接用動畫切換索引
                    withAnimation {
                        currentStageIndex += 1
                    }
                } else {
                    // 已到最後階段，停止計時器
                    timer.invalidate()
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
