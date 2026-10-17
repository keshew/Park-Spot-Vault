import SwiftUI
import CoreLocation

struct ParkingSession: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var floor: String
    var zone: String
    var note: String
    var coordinate: String
    var accuracy: String
    var distance: String
    var heading: Double
    var parkedAt: Date
    var photoStyle: Int = 0
    var photoFilename: String?
    var landmarks: [String]
    var reminderAt: Date? = nil

    var mapCoordinate: CLLocationCoordinate2D? {
        let parts = coordinate.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 2, parts.allSatisfy({ $0.isFinite }), abs(parts[0]) <= 90, abs(parts[1]) <= 180 else { return nil }
        return CLLocationCoordinate2D(latitude: parts[0], longitude: parts[1])
    }

    var spotDescription: String {
        let parts = [floor.isEmpty ? nil : floor, zone.isEmpty ? nil : "Zone \(zone)"].compactMap { $0 }
        return parts.isEmpty ? "Saved parking spot" : parts.joined(separator: " · ")
    }

    var photoColors: [Color] { [.vaultAccent, .vaultSecondary, .vaultCard] }
}
