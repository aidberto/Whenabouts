
import Foundation

enum ReminderCategory: String, Codable, CaseIterable, Identifiable {
    case grocery
    case home
    case health
    case work
    case general
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .grocery: return "Grocery"
        case .home: return "Home"
        case .health: return "Health"
        case .work: return "Work"
        case .general: return "General"
        }
    }
}
