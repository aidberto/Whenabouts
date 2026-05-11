//
//  ReminderMonitoringService.swift
//  contextReminder
//
//  Created by Ameen A on 10/5/2026.
//


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
                self?.refreshMonitoring()
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
                    id: UUID(),
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
    
}
