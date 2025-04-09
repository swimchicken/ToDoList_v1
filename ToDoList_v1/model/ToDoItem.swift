//
//  ToDoItem.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/4/9.
//
import Foundation

struct ToDoItem: Identifiable {
    let id = UUID()            // 每個項目都有唯一 ID
    var title: String          // 事項標題
    var priority: Int          // 重要程度 (1 ~ 3 類似)
    var time: Date             // 排定時間
    var isCompleted: Bool      // 是否已完成
}
