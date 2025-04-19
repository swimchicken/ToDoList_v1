//
//  TodoStatus.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/4/19.
//


// MARK: - TodoStatus.swift
import Foundation

/// 定義待辦事項狀態
enum TodoStatus: String, Codable {
    case toDoList      // 代辦佇列
    case toBeStarted   // 尚未開始
    case undone        // 進行中，但尚未完成
    case completed     // 已完成
}
