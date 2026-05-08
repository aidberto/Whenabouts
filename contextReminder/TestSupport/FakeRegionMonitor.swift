//
//  FakeRegionMonitor.swift
//  contextReminder
//
//  Created by Brian Jones Porianto on 3/5/2026.
//

import Foundation

final class FakeRegionMonitor: RegionMonitoring {
    private(set) var monitoredRegionIds: Set<UUID> = []
    var onRegionTransition: ((UUID, RegionTransition) -> Void)?

    private(set) var startedRegions: [UUID: (LocationCoordinate, Double)] = [:]
    private(set) var startCount: Int = 0
    private(set) var stopCount: Int = 0

    func startMonitoring(id: UUID, coordinate: LocationCoordinate, radius: Double) {
        monitoredRegionIds.insert(id)
        startedRegions[id] = (coordinate, radius)
        startCount += 1
    }

    func stopMonitoring(id: UUID) {
        monitoredRegionIds.remove(id)
        startedRegions.removeValue(forKey: id)
        stopCount += 1
    }

    func simulateTransition(_ id: UUID, _ transition: RegionTransition) {
        onRegionTransition?(id, transition)
    }
}
