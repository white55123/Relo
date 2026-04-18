//
//  ReloApp.swift
//  Relo
//
//  Created by reol on 2025/12/3.
//

import SwiftUI
import CoreData
import UserNotifications

@main
struct ReloApp: App {
    let persistenceController = PersistenceController.shared
    
    init() {
        // 设置 UserDefaults 默认值
        let defaults: [String: Any] = [
            "enableAutoSentiment": true,
            "enableAutoTodoExtraction": true
        ]
        UserDefaults.standard.register(defaults: defaults)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(context: persistenceController.container.viewContext)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .task {
                    await checkNotificationPermission()
                }
        }
    }
    
    private func checkNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        
        if settings.authorizationStatus == .notDetermined {
            // 首次使用，请求权限
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                if granted {
                    print("通知权限已授予")
                } else {
                    print("用户拒绝了通知权限")
                }
            } catch {
                print("请求通知权限失败: \(error)")
            }
        }
    }
}
