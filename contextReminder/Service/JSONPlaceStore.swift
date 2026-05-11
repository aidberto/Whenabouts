
import Foundation
import Combine

final class JSONPlaceStore: PlaceStore {
    // The current list of Places. SwiftUI views watch this for changes. Outside callers can read it but only this class can change it.
    @Published private(set) var places: [Place] = []

    // Path to the JSON file. Set once when the store is created.
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        // Use the given path (handy for tests) or the default location on disk.
        self.fileURL = fileURL ?? Self.defaultFileURL()
        load()
    }

    func add(_ place: Place) {
        places.append(place)
        save()
    }

    func update(_ place: Place) {
        // Find the matching Place by id and replace it. Bail if not found.
        guard let index = places.firstIndex(where: { $0.id == place.id }) else {
            return
        }
        places[index] = place
        save()
    }

    func delete(id: UUID) {
        places.removeAll { $0.id == id }
        save()
    }

    // Read saved Places from disk; missing or corrupted files leave the list empty.
    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            places = try JSONDecoder().decode([Place].self, from: data)
        } catch {
            print("PlaceStore load failed: \(error)")
        }
    }

    // Write the current `places` array back to the JSON file. Creates the folder first if it doesn't exist (happens on first launch).
    private func save() {
        do {
            let data = try JSONEncoder().encode(places)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            // `.atomic` writes to a temp file first then renames it, so a crash mid-write can't leave us with a half-written corrupt file.
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("PlaceStore save failed: \(error)")
        }
    }

    // Where the JSON file lives on the user's device. `<App's private folder>/Library/Application Support/places.json`.
    private static func defaultFileURL() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent("places.json")
    }
}
