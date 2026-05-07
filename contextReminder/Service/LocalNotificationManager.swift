//
//  LocalNotificationManager.swift
//  contextReminder
//
//  Created by Ameen A on 8/5/2026.
//

import Foundation
import UserNotifications

final class LocalNotificationManager: NotificationManaging {
    
    static let shared = LocalNotificationManager()
    
    private init() {}
    
    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Notification Permission Error: \(error)")
            return false
        }
    }
    
    func notificationPermissionStatus() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        
        return settings.authorizationStatus == .authorized
    }
}
