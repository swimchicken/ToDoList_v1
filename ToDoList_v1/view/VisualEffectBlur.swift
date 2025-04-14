//
//  VisualEffectBlur.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/4/14.
//

import SwiftUI
import UIKit

/// 可使用 UIBlurEffect.Style 來控制模糊程度與風格
struct VisualEffectBlur: UIViewRepresentable {
    let style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        // 依指定 style 建立 UIBlurEffect
        let blurEffect = UIBlurEffect(style: style)
        let view = UIVisualEffectView(effect: blurEffect)
        return view
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        // 更新時，確保 effect 保持為同一個 style
        uiView.effect = UIBlurEffect(style: style)
    }
}
