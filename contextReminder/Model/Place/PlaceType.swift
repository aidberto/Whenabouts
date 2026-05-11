
import Foundation

enum PlaceType: String, Codable, CaseIterable, Identifiable {
    case supermarket
    case pharmacy
    case home
    case work
    case postOffice
    case custom
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .supermarket: return "Supermarket"
        case .pharmacy: return "Pharmacy"
        case .home: return "Home"
        case .work: return "Work"
        case .postOffice: return "Post Office"
        case .custom: return "Custom"
        }
    }
}
