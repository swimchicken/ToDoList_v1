//
//  CircleView.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/4/15.
//

import SwiftUI

struct CircleView: View {
    var body: some View {
        // 使用 SwiftUI 內建的 Circle() 形狀
        Circle()
            .fill(Color.gray)
            .frame(width: 70, height: 70) // 指定寬高
            .shadow(radius: 4)       // 加入陰影（選用）
    }
}

#Preview {
    CircleView()
}


//struct CircleView_Previews: PreviewProvider {
//    static var previews: some View {
//        CircleView()
//            .previewLayout(.sizeThatFits)
//            .padding()
//    }
//}
