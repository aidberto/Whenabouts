//
//  TriggerType.swift
//  contextReminder
//
//  Created by Ameen A on 29/4/2026.
//


import Foundation

enum TriggerType: String, Codable, CaseIterable, Identifiable {
    case arriving
    case leaving
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .arriving: return "Arriving"
        case .leaving: return "Leaving"
        }
    }
}
