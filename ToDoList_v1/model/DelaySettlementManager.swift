//
//  DelaySettlementManager.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/6/2.
//

import Foundation

/// 延遲結算管理器：用於管理結算流程
class DelaySettlementManager {
    // 單例模式
    static let shared = DelaySettlementManager()
    
    // UserDefaults 鍵值
    private let lastSettlementDateKey = "lastSettlementDate"
    private let shouldShowSettlementKey = "shouldShowSettlement"
    
    private init() {}
    
    /// 保存最後一次結算日期
    func saveLastSettlementDate() {
        let currentDate = Date()
        
        // 使用日期格式器保存日期
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: currentDate)
        
        UserDefaults.standard.set(dateString, forKey: lastSettlementDateKey)
        UserDefaults.standard.set(false, forKey: shouldShowSettlementKey) // 剛結算完，設為不需顯示
        
        print("保存最後結算日期: \(dateString)")
    }
    
    /// 獲取最後一次結算日期
    func getLastSettlementDate() -> Date? {
        guard let dateString = UserDefaults.standard.string(forKey: lastSettlementDateKey) else {
            return nil // 沒有保存過日期
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter.date(from: dateString)
    }
    
    /// 檢查是否需要顯示結算畫面
    /// - Returns: 如果需要顯示返回true，否則返回false
    func shouldShowSettlement() -> Bool {
        // 如果已經標記為需要顯示，直接返回true
        if UserDefaults.standard.bool(forKey: shouldShowSettlementKey) {
            print("已經標記為需要顯示結算")
            return true
        }
        
        // 檢查最後結算日期
        guard let lastDate = getLastSettlementDate() else {
            // 沒有保存過日期，表示這是首次使用應用
            // 首次使用不需要顯示結算頁面
            print("首次使用應用，沒有上次結算記錄，不需要顯示結算頁面")
            return false
        }
        
        // 獲取當前日期和最後結算日期的日期部分
        let calendar = Calendar.current
        let currentDateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        let lastDateComponents = calendar.dateComponents([.year, .month, .day], from: lastDate)
        
        // 創建只包含日期部分的日期對象
        guard let currentDateOnly = calendar.date(from: currentDateComponents),
              let lastDateOnly = calendar.date(from: lastDateComponents) else {
            return false
        }
        
        // 計算日期差異
        let differenceInDays = calendar.dateComponents([.day], from: lastDateOnly, to: currentDateOnly).day ?? 0
        
        // 檢查是否需要顯示結算
        // 如果是昨天結算的，不需要顯示結算視圖，直接進入Home
        // 如果超過1天未結算，則顯示結算視圖
        let isYesterday = differenceInDays == 1
        let needToShow = differenceInDays > 1
        
        if needToShow {
            UserDefaults.standard.set(true, forKey: shouldShowSettlementKey)
            print("檢查是否需要顯示結算畫面: 距離上次結算 \(differenceInDays) 天, 需要顯示: true (超過1天)")
            return true
        } else if isYesterday {
            print("檢查是否需要顯示結算畫面: 距離上次結算剛好1天(昨天), 不需要顯示")
            return false
        } else {
            print("檢查是否需要顯示結算畫面: 距離上次結算 \(differenceInDays) 天, 不需要顯示")
            return false
        }
    }
    
    /// 獲取上次結算與當前日期的時間差異
    /// - Returns: 返回時間差異字典 [.day: Int, .month: Int, .year: Int]
    func getTimeDifference() -> [Calendar.Component: Int] {
        guard let lastDate = getLastSettlementDate() else {
            // 沒有上次結算日期，返回空字典
            return [:]
        }
        
        let calendar = Calendar.current
        let components: Set<Calendar.Component> = [.day, .month, .year]
        let difference = calendar.dateComponents(components, from: lastDate, to: Date())
        
        var result: [Calendar.Component: Int] = [:]
        if let days = difference.day { result[.day] = days }
        if let months = difference.month { result[.month] = months }
        if let years = difference.year { result[.year] = years }
        
        return result
    }
    
    /// 標記結算流程完成
    /// 當用戶完成結算流程時調用此方法
    func markSettlementCompleted() {
        saveLastSettlementDate() // 更新最後結算日期為當前日期
        UserDefaults.standard.set(false, forKey: shouldShowSettlementKey) // 設置為不需要顯示
    }
    
    /// 檢查是否為當天結算
    /// - Parameter isActiveEndDay: 是否是用戶主動點擊"end today"按鈕
    /// - Returns: 如果是當天結算返回true，否則返回false
    func isSameDaySettlement(isActiveEndDay: Bool = false) -> Bool {
        // 如果是用戶主動點擊"end today"按鈕，則視為當天結算
        if isActiveEndDay {
            return true
        }
        
        // 否則檢查上次結算日期是否為今天
        guard let lastDate = getLastSettlementDate() else {
            return false // 沒有上次結算日期，肯定不是當天
        }
        
        let calendar = Calendar.current
        return calendar.isDateInToday(lastDate)
    }
}
