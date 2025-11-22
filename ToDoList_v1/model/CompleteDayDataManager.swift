//
//  CompleteDayDataManager.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/6/1.
//

import Foundation
import CloudKit

/// CompleteDayDataManager - 管理已完成日期的數據
class CompleteDayDataManager {
    // MARK: - 單例模式
    static let shared = CompleteDayDataManager()
    
    // MARK: - 常量
    private let completedDaysKey = "completedDays"
    private let cloudKitService = CloudKitService.shared
    private let apiDataManager = APIDataManager.shared
    
    // MARK: - Properties
    // 使用日期字符串作為標識（格式：yyyy-MM-dd）
    private var completedDays: [String] = []
    
    // MARK: - 初始化
    private init() {
        print("DEBUG: 初始化 CompleteDayDataManager")
        loadCompletedDaysFromLocal()
        setupAccountChangeObserver()
    }
    
    // MARK: - 設置帳號變化觀察者
    private func setupAccountChangeObserver() {
        // 監聽 iCloud 用戶變更通知
        NotificationCenter.default.addObserver(
            forName: Notification.Name("iCloudUserChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            
            print("NOTICE: CompleteDayDataManager 收到用戶變更通知")
            
            // 清除本地完成日期數據
            self.clearCompletedDaysData()
            
            // 重新從本地加載（新用戶的數據將為空）
            self.loadCompletedDaysFromLocal()
            
            // 發送數據變更通知
            self.notifyDataChanged()
        }
        
        // 監聽 iCloud 帳號不可用通知
        NotificationCenter.default.addObserver(
            forName: Notification.Name("iCloudAccountUnavailable"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            
            print("NOTICE: CompleteDayDataManager 收到 iCloud 帳號不可用通知")
            
            // 清除本地完成日期數據
            self.clearCompletedDaysData()
            
            // 重新從本地加載（將為空）
            self.loadCompletedDaysFromLocal()
            
            // 發送數據變更通知
            self.notifyDataChanged()
        }
    }
    
    // MARK: - 本地儲存操作
    
    /// 從本地加載已完成日期數據
    private func loadCompletedDaysFromLocal() {
        if let savedDays = UserDefaults.standard.stringArray(forKey: completedDaysKey) {
            completedDays = savedDays
            // print("DEBUG: 從本地加載 \(completedDays.count) 個已完成日期")
        } else {
            completedDays = []
            print("DEBUG: 本地無已完成日期數據")
        }
    }
    
    /// 保存已完成日期數據到本地
    private func saveCompletedDaysToLocal() {
        UserDefaults.standard.set(completedDays, forKey: completedDaysKey)
        print("DEBUG: 已保存 \(completedDays.count) 個已完成日期到本地")
    }
    
    /// 清除本地已完成日期數據
    func clearCompletedDaysData() {
        completedDays = []
        UserDefaults.standard.removeObject(forKey: completedDaysKey)
        print("DEBUG: 已清除本地已完成日期數據")
    }
    
    // MARK: - 公共方法
    
    /// 標記一天為已完成
    /// - Parameter date: 要標記的日期
    func markDayAsCompleted(date: Date) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        // 檢查日期是否已存在
        if !completedDays.contains(dateString) {
            completedDays.append(dateString)
            saveCompletedDaysToLocal()
            print("INFO: 已標記日期 \(dateString) 為已完成")
            
            // 發送數據變更通知
            notifyDataChanged()
        } else {
            print("INFO: 日期 \(dateString) 已經標記為完成")
        }
    }
    
    /// 取消標記一天為已完成
    /// - Parameter date: 要取消標記的日期
    func unmarkDayAsCompleted(date: Date) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        if let index = completedDays.firstIndex(of: dateString) {
            completedDays.remove(at: index)
            saveCompletedDaysToLocal()
            print("INFO: 已取消日期 \(dateString) 的完成標記")
            
            // 發送數據變更通知
            notifyDataChanged()
        } else {
            print("INFO: 日期 \(dateString) 未被標記為完成，無需取消")
        }
    }
    
    /// 檢查一天是否已完成
    /// - Parameter date: 要檢查的日期
    /// - Returns: 是否已完成
    func isDayCompleted(date: Date) -> Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        return completedDays.contains(dateString)
    }
    
    /// 獲取所有已完成的日期
    /// - Returns: 已完成的日期數組
    func getAllCompletedDays() -> [Date] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        return completedDays.compactMap { dateString in
            dateFormatter.date(from: dateString)
        }
    }
    
    /// 獲取特定月份已完成的日期
    /// - Parameters:
    ///   - year: 年份
    ///   - month: 月份 (1-12)
    /// - Returns: 已完成的日期數組
    func getCompletedDaysForMonth(year: Int, month: Int) -> [Date] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // 創建月份前綴，例如 "2025-06-"
        let monthPrefix = String(format: "%04d-%02d-", year, month)
        
        return completedDays
            .filter { $0.hasPrefix(monthPrefix) }
            .compactMap { dateFormatter.date(from: $0) }
    }
    
    /// 獲取本月已完成的天數
    /// - Returns: 已完成的天數
    func getCompletedDaysCountForCurrentMonth() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        
        return getCompletedDaysForMonth(year: year, month: month).count
    }
    
    /// 獲取特定月份的已完成天數
    /// - Parameters:
    ///   - year: 年份
    ///   - month: 月份 (1-12)
    /// - Returns: 已完成的天數
    func getCompletedDaysCountForMonth(year: Int, month: Int) -> Int {
        return getCompletedDaysForMonth(year: year, month: month).count
    }
    
    /// 獲取特定月份的完成率（已完成天數 / 總天數）
    /// - Parameters:
    ///   - year: 年份
    ///   - month: 月份 (1-12)
    /// - Returns: 完成率（0.0 - 1.0）
    func getCompletionRateForMonth(year: Int, month: Int) -> Double {
        let completedDaysCount = getCompletedDaysCountForMonth(year: year, month: month)
        
        // 獲取該月的總天數
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = month
        
        if let date = calendar.date(from: components),
           let range = calendar.range(of: .day, in: .month, for: date) {
            let totalDays = range.count
            return Double(completedDaysCount) / Double(totalDays)
        }
        
        return 0.0
    }
    
    /// 獲取連續完成的天數（截至今天）
    /// - Returns: 連續完成的天數
    func getCurrentStreak() -> Int {
        var streak = 0
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // 將日期字符串轉換為日期對象並排序
        let sortedDates = completedDays
            .compactMap { dateFormatter.date(from: $0) }
            .sorted(by: >)  // 降序排列，最近日期在前
        
        // 檢查今天是否已完成
        if let latestDate = sortedDates.first,
           calendar.isDate(latestDate, inSameDayAs: today) {
            streak = 1
            
            // 從昨天開始向前檢查
            var currentDate = calendar.date(byAdding: .day, value: -1, to: today)!
            
            while true {
                let dateString = dateFormatter.string(from: currentDate)
                if completedDays.contains(dateString) {
                    streak += 1
                    currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
                } else {
                    break
                }
            }
        }
        
        return streak
    }
    
    /// 標記今天為已完成
    func markTodayAsCompleted() {
        markDayAsCompleted(date: Date())
    }
    
    /// 檢查今天是否已完成
    /// - Returns: 是否已完成
    func isTodayCompleted() -> Bool {
        return isDayCompleted(date: Date())
    }
    
    // MARK: - 輔助方法
    
    /// 發送數據變更通知
    private func notifyDataChanged() {
        NotificationCenter.default.post(
            name: Notification.Name("CompletedDaysDataChanged"),
            object: nil
        )
    }
}