import Foundation

/**
 * 任務資料模型 (已更名為 TaskEntry)
 *
 * 這個結構定義了任務的核心屬性，並遵循 Identifiable 和 Equatable 協議，
 * 以便在 SwiftUI 列表中使用和進行比較。
 *
 * - `id`: 每個任務的唯一標識符。
 * - `title`: 任務的標題。
 * - `notes`: 任務的詳細備註 (可選)。
 * - `date`: 任務的日期字串，格式為 "yyyy-MM-dd" (可選)。
 * - `time`: 任務的時間字串，格式為 "HH:mm" (可選)。
 * - `priority`: 任務的優先級 (星等)，0 代表沒有星號。
 */
struct TaskEntry: Identifiable, Equatable { // <-- 已更名
    var id = UUID()
    var title: String
    var notes: String?
    var date: String?
    var time: String?
    var priority: Int = 0
}
