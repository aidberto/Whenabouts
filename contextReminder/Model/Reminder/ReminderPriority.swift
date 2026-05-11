
import Foundation

enum ReminderPriority: String, Codable, CaseIterable, Identifiable {
    case low
    case normal
    case high
    case urgent
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }
}
