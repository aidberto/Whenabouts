
import Foundation

struct GeofenceEvent: Equatable {
    // The id of the reminder trigger that fired.
    let triggerId: UUID
    // Whether this was an "arriving" or "leaving" event.
    let kind: TriggerType
    // When the event happened.
    let timestamp: Date
}
