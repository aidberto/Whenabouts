
import Foundation

// translate CLLocation(Apple corelocation type to this) safety measure
struct LocationCoordinate: Equatable {
    let latitude: Double
    let longitude: Double
}
