

import Foundation
import Combine

@MainActor
final class ReminderMonitoringService{
    private let reminderStore: any ReminderStore
    private let geofenceCoordinator: GeofenceCoordinator
    private let locationProvider: any LocationProviding
    private let placeStore: any PlaceStore
    
    private var cancellables = Set<AnyCancellable>()
    
    init(
        reminderStore: any ReminderStore,
        placeStore: any PlaceStore,
        geofenceCoordinator: GeofenceCoordinator,
        locationProvider: any LocationProviding
    ) {
        self.reminderStore = reminderStore
        self.placeStore = placeStore
        self.geofenceCoordinator = geofenceCoordinator
        self.locationProvider = locationProvider
        
        reminderStore.objectWillChange
            .sink{[weak self] _ in
                DispatchQueue.main.async {
                    self?.refreshMonitoring()
                }
            }
            .store(in: &cancellables)

        placeStore.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.refreshMonitoring()
                }
            }
            .store(in: &cancellables)

        locationProvider.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.refreshMonitoring()
                }
            }
            .store(in: &cancellables)
        
        refreshMonitoring()
    }
    
    func refreshMonitoring() {
        
        print("Reminder Count: \(reminderStore.reminders.count)")
        
        let triggers = reminderStore.reminders.flatMap { reminder -> [MonitoredTrigger] in
            
            
            
            guard !reminder.isCompleted else {
                return []
            }
            
            switch reminder.trigger.target {
                
            case .place(let place):
                
                return [
                        MonitoredTrigger(
                    id: reminder.trigger.id,
                    reminderTriggerId: reminder.trigger.id,
                    coordinate: LocationCoordinate(
                        latitude: place.latitude,
                        longitude: place.longitude
                    ),
                    radius: place.radius,
                    triggerType: reminder.trigger.triggerType,
                    lastTriggeredAt: nil
                    )
                ]
                
            case .placeType(let placeType):
                let matchingPlaces = placeStore.places.filter {
                    $0.placeType == placeType
                }
                
                return matchingPlaces.map { place in
                    
                    MonitoredTrigger(
                    id: regionId(
                    reminderTriggerId: reminder.trigger.id,
                    placeId: place.id
                    ),
                    reminderTriggerId: reminder.trigger.id,
                    coordinate: LocationCoordinate(
                    latitude: place.latitude,
                    longitude: place.longitude
                    ),
                    radius: place.radius,
                    triggerType: reminder.trigger.triggerType,
                    lastTriggeredAt: nil
                    )

                }
            }
        }
        
        print("Generated \(triggers.count) monitored triggers")
        
        geofenceCoordinator.setActiveTriggers(
            triggers,
            userLocation: locationProvider.currentCoordinate
        )
    }

    private func regionId(reminderTriggerId: UUID, placeId: UUID) -> UUID {
        let reminderBytes = reminderTriggerId.uuid
        let placeBytes = placeId.uuid

        return UUID(uuid: (
            reminderBytes.0 ^ placeBytes.0,
            reminderBytes.1 ^ placeBytes.1,
            reminderBytes.2 ^ placeBytes.2,
            reminderBytes.3 ^ placeBytes.3,
            reminderBytes.4 ^ placeBytes.4,
            reminderBytes.5 ^ placeBytes.5,
            reminderBytes.6 ^ placeBytes.6,
            reminderBytes.7 ^ placeBytes.7,
            reminderBytes.8 ^ placeBytes.8,
            reminderBytes.9 ^ placeBytes.9,
            reminderBytes.10 ^ placeBytes.10,
            reminderBytes.11 ^ placeBytes.11,
            reminderBytes.12 ^ placeBytes.12,
            reminderBytes.13 ^ placeBytes.13,
            reminderBytes.14 ^ placeBytes.14,
            reminderBytes.15 ^ placeBytes.15
        ))
    }
    
}
