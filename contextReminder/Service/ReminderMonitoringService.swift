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
    
    private var cancellables = Set<AnyCancellable>()
    
    init(
        reminderStore: any ReminderStore,
        geofenceCoordinator: GeofenceCoordinator,
        locationProvider: any LocationProviding
    ) {
        self.reminderStore = reminderStore
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
        
        var seenTriggerIds = Set<UUID>()
        
        let triggers = reminderStore.reminders.compactMap { reminder -> MonitoredTrigger? in
            
            guard !reminder.isCompleted else {
                return nil
            }
            
            guard seenTriggerIds.insert(reminder.trigger.id).inserted else {
                return nil
            }
            
            switch reminder.trigger.target {
                
            case .place(let place):
                
                return MonitoredTrigger(
                    id: reminder.trigger.id,
                    coordinate: LocationCoordinate(
                        latitude: place.latitude,
                        longitude: place.longitude
                    ),
                    radius: place.radius,
                    triggerType: reminder.trigger.triggerType,
                    lastTriggeredAt: nil
                    )
                
            case .placeType:
                return nil
            }
        }
        
        
        
        geofenceCoordinator.setActiveTriggers(
            triggers,
            userLocation: locationProvider.currentCoordinate
        )
    }
}
