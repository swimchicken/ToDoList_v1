//
//  TodoStatus.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/4/19.
//


// MARK: - TodoStatus.swift
import Foundation

/// 新的任務類型定義
enum TaskType: String, Codable {
    case scheduled = "scheduled"    // 有具體日期時間的事件
    case memo = "memo"             // 備忘錄（用戶主動創建）
    case uncompleted = "uncompleted" // 未完成（結算產生）
}

/// 新的完成狀態定義
enum CompletionStatus: String, Codable {
    case pending = "pending"       // 待完成
    case completed = "completed"   // 已完成
}

/// 原有狀態枚舉（保留向後兼容）
enum TodoStatus: String, Codable {
    case toDoList      // 代辦佇列
    case toBeStarted   // 尚未開始
    case undone        // 進行中，但尚未完成
    case completed     // 已完成
}
