//
//  NotificationManaging.swift
//  contextReminder
//
//  Created by Ameen A on 8/5/2026.
//

import Foundation

protocol NotificationManaging {
    func requestPermission() async -> Bool
    func notificationPermissionStatus() async -> Bool
}
