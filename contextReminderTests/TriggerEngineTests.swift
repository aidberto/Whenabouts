//
//  TriggerEngineTests.swift
//  contextReminderTests
//
//  Full unit test suite for TriggerEngine + GeofenceCoordinator.
//  Every test runs entirely in memory — no GPS, no network, no real
//  notifications. All dependencies are replaced with the fakes from
//  TestSupport/.
//
//  To run: ⌘ + U  (or Product → Test)
//

import XCTest
@testable import contextReminder

// @MainActor matches TriggerEngine, which is itself @MainActor.
// This lets us call await engine.refresh() without data-race warnings.
@MainActor
final class TriggerEngineTests: XCTestCase {

    // -------------------------------------------------------------------------
    // MARK: - Shared fakes
    // Rebuilt fresh in setUp() before every single test so nothing bleeds through.
    // -------------------------------------------------------------------------

    var locationProvider: ScriptedLocationProvider!
    var monitor:          FakeRegionMonitor!
    var notifications:    FakeNotificationService!
    var placeStore:       InMemoryPlaceStore!
    var reminderStore:    InMemoryReminderStore!
    var poiDiscovery:     StaticPOIDiscovery!
    var coordinator:      GeofenceCoordinator!
    var engine:           TriggerEngine!

    // Default user location: Sydney CBD
    let sydney = LocationCoordinate(latitude: -33.8688, longitude: 151.2093)

    override func setUp() async throws {
        try await super.setUp()

        locationProvider = ScriptedLocationProvider(
            authorization:     LocationAuthorization.full,
            currentCoordinate: sydney
        )
        monitor       = FakeRegionMonitor()
        notifications = FakeNotificationService()
        placeStore    = InMemoryPlaceStore()
        reminderStore = InMemoryReminderStore()
        poiDiscovery  = StaticPOIDiscovery()   // hardcoded Sydney-area POIs, no network

        coordinator = GeofenceCoordinator(monitor: monitor! as! RegionMonitoring)
        engine = TriggerEngine(
            reminderStore: reminderStore! as! (any ReminderStore),
            placeStore:    placeStore! as! (any PlaceStore),
            location:      locationProvider! as! (any LocationProviding),
            coordinator:   coordinator,
            poiDiscovery:  poiDiscovery! as! POIDiscovering,
            notifications: notifications!
        )
    }

    override func tearDown() async throws {
        engine           = nil
        coordinator      = nil
        reminderStore    = nil
        placeStore       = nil
        notifications    = nil
        monitor          = nil
        locationProvider = nil
        try await super.tearDown()
    }

    // =========================================================================
    // MARK: - Helpers
    // =========================================================================

    /// Build a saved Place at the given coordinate.
    private func makePlace(
        name:      String  = "Test Place",
        type:      PlaceType = .custom,
        latitude:  Double,
        longitude: Double,
        radius:    Double  = 100
    ) -> Place {
        Place(name: name, placeType: type, latitude: latitude, longitude: longitude, radius: radius)
    }

    /// Build a Reminder tied to a specific saved Place.
    private func makeReminder(
        title:       String      = "Test Reminder",
        triggerType: TriggerType = .arriving,
        place:       Place
    ) -> Reminder {
        Reminder(
            title:   title,
            trigger: ReminderTrigger(triggerType: triggerType, target: .place(place))
        )
    }

    /// Build a Reminder tied to a category of place (e.g. "any supermarket").
    private func makeReminder(
        title:       String      = "Test Reminder",
        triggerType: TriggerType = .arriving,
        placeType:   PlaceType
    ) -> Reminder {
        Reminder(
            title:   title,
            trigger: ReminderTrigger(triggerType: triggerType, target: .placeType(placeType))
        )
    }

    /// Simulate the user entering the first (and usually only) registered geofence.
    private func enterFirstGeofence() {
        guard let id = monitor.startedRegions.keys.first else {
            XCTFail("No geofences were registered — nothing to enter")
            return
        }
        monitor.simulateTransition(id, RegionTransition.enter)
    }

    /// Simulate the user leaving the first registered geofence.
    private func exitFirstGeofence() {
        guard let id = monitor.startedRegions.keys.first else {
            XCTFail("No geofences were registered — nothing to exit")
            return
        }
        monitor.simulateTransition(id, RegionTransition.exit)
    }

    // =========================================================================
    // MARK: - Test 1: Arriving at a saved place fires a notification
    //
    // A reminder tied to a specific Place with triggerType = .arriving should
    // fire exactly one notification when the user enters the geofence circle.
    // =========================================================================

    func test_arrivingAtSavedPlace_firesNotification() async {
        // Arrange
        let home = makePlace(name: "Home", latitude: -33.9000, longitude: 151.2000)
        placeStore.add(home)
        reminderStore.add(makeReminder(title: "Take the bins out", triggerType: .arriving, place: home))

        // Act
        await engine.refresh()
        enterFirstGeofence()

        // Assert
        XCTAssertEqual(notifications.firedReminders.count, 1)
        XCTAssertEqual(notifications.firedReminders.first?.reminder.title, "Take the bins out")
    }

    // =========================================================================
    // MARK: - Test 2: Leaving a saved place fires a notification
    //
    // Same as Test 1 but with triggerType = .leaving and a simulated .exit.
    // Verifies the engine correctly handles the leaving case end-to-end.
    // =========================================================================

    func test_leavingASavedPlace_firesNotification() async {
        // Arrange
        let office = makePlace(name: "Office", latitude: -33.8700, longitude: 151.2070)
        placeStore.add(office)
        reminderStore.add(makeReminder(title: "Log hours", triggerType: .leaving, place: office))

        // Act
        await engine.refresh()
        exitFirstGeofence()

        // Assert
        XCTAssertEqual(notifications.firedReminders.count, 1)
        XCTAssertEqual(notifications.firedReminders.first?.reminder.title, "Log hours")
    }

    // =========================================================================
    // MARK: - Test 3: Wrong transition direction does NOT fire
    //
    // A reminder set to .arriving should never fire on an .exit crossing.
    // Checks that the direction-matching guard inside GeofenceCoordinator works.
    // =========================================================================

    func test_wrongTransitionDirection_doesNotFire() async {
        // Arrange
        let park = makePlace(name: "Park", latitude: -33.8800, longitude: 151.2100)
        placeStore.add(park)
        reminderStore.add(makeReminder(title: "Walk the dog", triggerType: .arriving, place: park))

        // Act
        await engine.refresh()
        exitFirstGeofence()   // wrong direction — reminder wants .arriving

        // Assert
        XCTAssertEqual(
            notifications.firedReminders.count, 0,
            "An arriving reminder must not fire when the user exits the geofence"
        )
    }

    // =========================================================================
    // MARK: - Test 4: Leaving reminder does NOT fire on entry
    //
    // Symmetric counterpart to Test 3 — a .leaving reminder must not fire
    // when the user enters the geofence.
    // =========================================================================

    func test_leavingReminder_doesNotFireOnEntry() async {
        // Arrange
        let gym = makePlace(name: "Gym", latitude: -33.8750, longitude: 151.2050)
        placeStore.add(gym)
        reminderStore.add(makeReminder(title: "Pack gym bag", triggerType: .leaving, place: gym))

        // Act
        await engine.refresh()
        enterFirstGeofence()   // wrong direction — reminder wants .leaving

        // Assert
        XCTAssertEqual(
            notifications.firedReminders.count, 0,
            "A leaving reminder must not fire when the user enters the geofence"
        )
    }

    // =========================================================================
    // MARK: - Test 5: PlaceType reminder creates one geofence per POI
    //
    // A reminder targeting .placeType(.supermarket) triggers a POI search.
    // StaticPOIDiscovery returns 3 supermarket fixtures for Sydney, so the
    // engine should register exactly 3 geofences.
    // =========================================================================

    func test_placeTypeReminder_createsOneGeofencePerPOI() async {
        // Arrange
        reminderStore.add(makeReminder(title: "Buy milk", triggerType: .arriving, placeType: .supermarket))

        // Act
        await engine.refresh()

        // Assert — StaticPOIDiscovery has 3 supermarket fixtures
        XCTAssertEqual(
            monitor.startedRegions.count, 3,
            "Expected one geofence per POI returned by StaticPOIDiscovery"
        )
    }

    // =========================================================================
    // MARK: - Test 6: Entering any one POI geofence fires the notification
    //
    // After geofences are registered for a POI-type reminder, entering any
    // one of the 3 circles should fire the reminder.
    // =========================================================================

    func test_placeTypeReminder_enteringAnyGeofence_firesNotification() async {
        // Arrange
        reminderStore.add(makeReminder(title: "Buy milk", triggerType: .arriving, placeType: .supermarket))

        // Act
        await engine.refresh()
        enterFirstGeofence()

        // Assert
        XCTAssertEqual(notifications.firedReminders.count, 1)
        XCTAssertEqual(notifications.firedReminders.first?.reminder.title, "Buy milk")
    }

    // =========================================================================
    // MARK: - Test 7: No GPS fix means no geofences for PlaceType reminders
    //
    // triggersFor() returns [] for .placeType when userLocation is nil.
    // Without a location a POI search can't run, so nothing should be
    // registered and no crash should occur.
    // =========================================================================

    func test_placeTypeReminder_noLocation_registersNoGeofences() async {
        // Arrange
        locationProvider.setCoordinate(Optional<LocationCoordinate>.none)
        reminderStore.add(makeReminder(title: "Pick up prescription", triggerType: .arriving, placeType: .pharmacy))

        // Act
        await engine.refresh()

        // Assert
        XCTAssertEqual(
            monitor.startedRegions.count, 0,
            "Cannot register POI geofences without a user location"
        )
    }

    // =========================================================================
    // MARK: - Test 8: Cold-start fires immediately when already inside geofence
    //
    // GeofenceCoordinator has a cold-start check: if the user is already
    // inside a newly-registered geofence for an .arriving trigger it emits
    // the event right away. iOS only fires crossing events when the user
    // actually crosses the boundary, so without this the reminder would be
    // silently missed if the user launches the app while already inside.
    // =========================================================================

    func test_coldStart_alreadyInsideGeofence_firesImmediately() async {
        // Arrange — place is centred exactly where the user is standing
        let here = makePlace(
            name:      "Current Spot",
            latitude:  sydney.latitude,
            longitude: sydney.longitude,
            radius:    500              // big enough to be unambiguously inside
        )
        placeStore.add(here)
        reminderStore.add(makeReminder(title: "Call Mum", triggerType: .arriving, place: here))

        // Act — no simulated transition; cold-start check fires on setActiveTriggers
        await engine.refresh()

        // Assert
        XCTAssertEqual(
            notifications.firedReminders.count, 1,
            "Cold-start: already inside an arriving geofence should fire immediately"
        )
    }

    // =========================================================================
    // MARK: - Test 9: Cold-start does NOT fire for a leaving trigger
    //
    // Being inside a geofence at app launch is not the same as leaving it.
    // A .leaving trigger must not fire during the cold-start check.
    // =========================================================================

    func test_coldStart_insideGeofence_doesNotFireForLeavingTrigger() async {
        // Arrange
        let here = makePlace(
            name:      "Current Spot",
            latitude:  sydney.latitude,
            longitude: sydney.longitude,
            radius:    500
        )
        placeStore.add(here)
        reminderStore.add(makeReminder(title: "Lock the door", triggerType: .leaving, place: here))

        // Act
        await engine.refresh()

        // Assert
        XCTAssertEqual(
            notifications.firedReminders.count, 0,
            "Cold-start must not fire a leaving trigger"
        )
    }

    // =========================================================================
    // MARK: - Test 10: Completed reminders are skipped entirely
    //
    // refresh() filters out completed reminders before building geofences.
    // A done reminder must not register any geofence.
    // =========================================================================

    func test_completedReminder_doesNotRegisterGeofence() async {
        // Arrange
        let place = makePlace(name: "Store", latitude: -33.8836, longitude: 151.1959)
        placeStore.add(place)

        var reminder = makeReminder(title: "Buy milk", triggerType: .arriving, place: place)
        // Mark it done before adding
        reminder = Reminder(
            id:          reminder.id,
            title:       reminder.title,
            trigger:     reminder.trigger,
            isCompleted: true
        )
        reminderStore.add(reminder)

        // Act
        await engine.refresh()

        // Assert
        XCTAssertEqual(
            monitor.startedRegions.count, 0,
            "Completed reminders must not have geofences"
        )
    }

    // =========================================================================
    // MARK: - Test 11: Multiple reminders each get their own geofence
    //
    // If there are two active reminders with different places, both should
    // be registered after a refresh. Tests that the engine loops over all
    // reminders, not just the first one.
    // =========================================================================

    func test_multipleReminders_registersGeofenceForEach() async {
        // Arrange
        let home   = makePlace(name: "Home",   latitude: -33.9000, longitude: 151.2000)
        let office = makePlace(name: "Office", latitude: -33.8700, longitude: 151.2070)
        placeStore.add(home)
        placeStore.add(office)

        reminderStore.add(makeReminder(title: "Bins",     triggerType: .arriving, place: home))
        reminderStore.add(makeReminder(title: "Stand-up", triggerType: .arriving, place: office))

        // Act
        await engine.refresh()

        // Assert
        XCTAssertEqual(
            monitor.startedRegions.count, 2,
            "Two reminders targeting different places should produce two geofences"
        )
    }

    // =========================================================================
    // MARK: - Test 12: Deleting a reminder stops its geofence
    //
    // When a reminder is deleted and refresh() runs again, the engine should
    // stop monitoring the now-orphaned circle. Verifies the diff logic inside
    // GeofenceCoordinator.setActiveTriggers.
    // =========================================================================

    func test_deletingReminder_stopsItsGeofence() async {
        // Arrange
        let place = makePlace(name: "Gym", latitude: -33.8750, longitude: 151.2050)
        placeStore.add(place)
        let reminder = makeReminder(title: "Pack gym bag", triggerType: .leaving, place: place)
        reminderStore.add(reminder)

        await engine.refresh()
        XCTAssertEqual(monitor.startedRegions.count, 1, "Pre-condition: geofence should be registered")

        // Act
        reminderStore.delete(id: reminder.id)
        await engine.refresh()

        // Assert
        XCTAssertEqual(
            monitor.startedRegions.count, 0,
            "Geofence should be stopped after its reminder is deleted"
        )
        XCTAssertGreaterThan(
            monitor.stopCount, 0,
            "stopMonitoring should have been called at least once"
        )
    }

    // =========================================================================
    // MARK: - Test 13: iOS 20-region cap is enforced
    //
    // iOS allows at most 20 monitored regions at once. GeofenceCoordinator
    // enforces this cap. When given 25 reminders it must register exactly 20.
    // =========================================================================

    func test_geofenceCap_onlyRegisters20Regions() async {
        // Arrange — 25 places spread across Sydney
        for i in 0..<25 {
            let place = makePlace(
                name:      "Place \(i)",
                latitude:  -33.8688 + Double(i) * 0.001,
                longitude: 151.2093 + Double(i) * 0.001
            )
            placeStore.add(place)
            reminderStore.add(makeReminder(title: "Reminder \(i)", place: place))
        }

        // Act
        await engine.refresh()

        // Assert
        XCTAssertEqual(
            monitor.startedRegions.count, 20,
            "GeofenceCoordinator must cap active regions at 20 (iOS limit)"
        )
    }

    // =========================================================================
    // MARK: - Test 14: Moving >500m triggers a fresh refresh
    //
    // TriggerEngine subscribes to location changes via Combine. When the user
    // moves more than 500m, refreshIfMoved() should rebuild the geofence set.
    // We verify startCount goes up after the large location change.
    // =========================================================================

    func test_significantLocationMove_triggersRefresh() async throws {
        // Arrange
        let place = makePlace(name: "Store", latitude: -33.8836, longitude: 151.1959)
        placeStore.add(place)
        reminderStore.add(makeReminder(title: "Buy bread", place: place))

        await engine.refresh()
        let countBefore = monitor.startCount

        // Act — move the user more than 500m south
        locationProvider.setCoordinate(
            LocationCoordinate(latitude: -33.9300, longitude: 151.2093)
        )

        // Give the Combine pipeline a moment to deliver the change and the
        // async Task inside the sink to execute.
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 s

        // Assert
        XCTAssertGreaterThan(
            monitor.startCount, countBefore,
            "Moving >500m should trigger a geofence refresh"
        )
    }

    // =========================================================================
    // MARK: - Test 15: Moving <500m does NOT trigger a refresh
    //
    // Small movements (walking around the same block) must not trigger a
    // POI re-query or geofence rebuild — that would be expensive and noisy.
    // =========================================================================

    func test_smallLocationMove_doesNotTriggerRefresh() async throws {
        // Arrange
        let place = makePlace(name: "Store", latitude: -33.8836, longitude: 151.1959)
        placeStore.add(place)
        reminderStore.add(makeReminder(title: "Buy bread", place: place))

        await engine.refresh()
        let countBefore = monitor.startCount

        // Act — move only ~50m north (well under the 500m threshold)
        locationProvider.setCoordinate(
            LocationCoordinate(latitude: -33.8684, longitude: 151.2093)
        )

        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 s

        // Assert
        XCTAssertEqual(
            monitor.startCount, countBefore,
            "Moving <500m must NOT trigger a geofence refresh"
        )
    }

    // =========================================================================
    // MARK: - Test 16: Small place radius is clamped to 100m minimum
    //
    // MonitoredTrigger is built with max(place.radius, 100). If a Place has
    // a very small radius the engine clamps it so iOS can reliably detect
    // the crossing (very small circles are unreliable on device).
    // =========================================================================

    func test_savedPlace_radiusBelowMinimum_isClamped() async {
        // Arrange
        let tinyPlace = makePlace(
            name:      "Tiny spot",
            latitude:  -33.8688,
            longitude: 151.2093,
            radius:    10         // well below the 100m minimum
        )
        placeStore.add(tinyPlace)
        reminderStore.add(makeReminder(title: "Tiny reminder", place: tinyPlace))

        // Act
        await engine.refresh()

        // Assert
        let (_, radius) = monitor.startedRegions.values.first!
        XCTAssertGreaterThanOrEqual(
            radius, 100,
            "Radius below 100m should be clamped up to 100m"
        )
    }

    // =========================================================================
    // MARK: - Test 17: Notification description says "Arriving at <name>"
    //
    // The description string passed to the notification service should match
    // the expected format so the user sees a sensible alert message.
    // =========================================================================

    func test_arrivingAtPlace_notificationDescriptionFormat() async {
        // Arrange
        let supermarket = makePlace(name: "Coles Broadway", latitude: -33.8836, longitude: 151.1959)
        placeStore.add(supermarket)
        reminderStore.add(makeReminder(title: "Buy milk", triggerType: .arriving, place: supermarket))

        // Act
        await engine.refresh()
        enterFirstGeofence()

        // Assert
        XCTAssertEqual(
            notifications.firedReminders.first?.1,
            "Arriving at Coles Broadway"
        )
    }

    // =========================================================================
    // MARK: - Test 18: Notification description says "Leaving <name>"
    //
    // Same as Test 17 but for the leaving case.
    // =========================================================================

    func test_leavingPlace_notificationDescriptionFormat() async {
        // Arrange
        let home = makePlace(name: "Home", latitude: -33.9000, longitude: 151.2000)
        placeStore.add(home)
        reminderStore.add(makeReminder(title: "Lock the door", triggerType: .leaving, place: home))

        // Act
        await engine.refresh()
        exitFirstGeofence()

        // Assert
        XCTAssertEqual(
            notifications.firedReminders.first?.1,
            "Leaving Home"
        )
    }

    // =========================================================================
    // MARK: - Test 19: PlaceType notification description uses category name
    //
    // When a POI-type reminder fires, the description should say
    // "Arriving at a supermarket" (not a specific place name).
    // =========================================================================

    func test_placeTypeReminder_notificationDescriptionUsesCategory() async {
        // Arrange
        reminderStore.add(makeReminder(title: "Buy milk", triggerType: .arriving, placeType: .supermarket))

        // Act
        await engine.refresh()
        enterFirstGeofence()

        // Assert
        XCTAssertEqual(
            notifications.firedReminders.first?.1,
            "Arriving at a supermarket"
        )
    }

    // =========================================================================
    // MARK: - Test 20: No reminders means no geofences registered
    //
    // Sanity check: when the reminder store is empty, refresh() should result
    // in zero geofences and must not crash.
    // =========================================================================

    func test_noReminders_registersNoGeofences() async {
        // Act
        await engine.refresh()

        // Assert
        XCTAssertEqual(monitor.startedRegions.count, 0)
        XCTAssertEqual(notifications.firedReminders.count, 0)
    }
}
