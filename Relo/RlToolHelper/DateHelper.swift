//
//  DateHelper.swift
//  Relo
//
//  Created by reol on 2025/12/19.
//

import Foundation

struct DateHelper {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年MM月dd日"
        return formatter
    }()
    
    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEE"
        return formatter
    }()
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        return formatter
    }()

    /// 格式化日期显示（某年某月某日）
    /// - Parameter date: 要格式化的日期
    /// - Returns: 格式化后的日期字符串，例如："2024年12月5日"
    static func formatDate(_ date: Date) -> String {
        return dateFormatter.string(from: date)
    }
    
    /// 格式化星期显示
    /// - Parameter date: 要格式化的日期
    /// - Returns: 格式化后的星期字符串，例如："星期四"
    static func formatWeekday(_ date: Date) -> String {
        return weekdayFormatter.string(from: date)
    }
    
    /// 格式化日期和星期（组合显示）
    /// - Parameter date: 要格式化的日期
    /// - Returns: 包含日期和星期的元组，例如：("2024年12月5日", "星期四")
    static func formatDateAndWeekday(_ date: Date) -> (date: String, weekday: String) {
        return (formatDate(date), formatWeekday(date))
    }
    
    /// 格式化时间显示（时:分）
    /// - Parameter date: 要格式化的日期
    /// - Returns: 格式化后的时间字符串，例如："14:30"
    static func formatTime(_ date: Date) -> String {
        return timeFormatter.string(from: date)
    }
    
    /// 格式化日期时间显示（某年某月某日 时:分）
    /// - Parameter date: 要格式化的日期
    /// - Returns: 格式化后的日期时间字符串，例如："2024年12月5日 14:30"
    static func formatDateTime(_ date: Date) -> String {
        return dateTimeFormatter.string(from: date)
    }
    
    /// 获取日期的开始时间（去掉时间部分，只保留日期）
    /// - Parameter date: 要处理的日期
    /// - Returns: 日期的开始时间（00:00:00）
    static func startOfDay(_ date: Date) -> Date {
        return Calendar.current.startOfDay(for: date)
    }
    
    /// 格式化今天的日期（某年某月某日）
    /// - Returns: 格式化后的日期字符串，例如："2024年12月5日"
    static func formatTodayDate() -> String {
        return formatDate(Date())
    }
    
    /// 格式化今天的星期
    /// - Returns: 格式化后的星期字符串，例如："星期四"
    static func formatTodayWeekday() -> String {
        return formatWeekday(Date())
    }
}
