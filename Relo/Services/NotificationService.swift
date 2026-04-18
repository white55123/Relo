//
//  NotificationService.swift
//  Relo
//

import UserNotifications

class NotificationService {
    static let shared = NotificationService()
    
    /// 请求通知权限
    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("请求通知权限失败: \(error)")
            return false
        }
    }
    
    /// 检查通知权限状态
    func checkPermission() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }
    
    /// 设置提醒
    func scheduleReminder(id: UUID, title: String, body: String, date: Date) async -> Bool {
        let hasPermission = await checkPermission()
        if !hasPermission {
            let granted = await requestPermission()
            if !granted {
                print("用户拒绝了通知权限")
                return false
            }
        }
        
        if date <= Date() {
            print("提醒时间已过，无法设置提醒")
            return false
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        content.subtitle = "到期时间: \(formatter.string(from: date))"
        
        let timeInterval = date.timeIntervalSinceNow
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(identifier: id.uuidString, content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("提醒设置成功，将在 \(formatter.string(from: date)) 提醒")
            return true
        } catch {
            print("设置提醒失败: \(error)")
            return false
        }
    }
    
    /// 取消提醒
    func cancelReminder(for id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id.uuidString])
        print("提醒已取消")
    }
}
