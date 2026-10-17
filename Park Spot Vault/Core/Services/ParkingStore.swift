import SwiftUI
import UserNotifications

final class ParkingStore: ObservableObject {
    @Published private(set) var activeParking: ParkingSession?
    @Published private(set) var history: [ParkingSession]
    private let defaults: UserDefaults
    private let activeKey = "parkSpotVault.activeParking"
    private let historyKey = "parkSpotVault.history"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let decoder = JSONDecoder()
        activeParking = defaults.data(forKey: activeKey).flatMap { try? decoder.decode(ParkingSession.self, from: $0) }
        history = defaults.data(forKey: historyKey).flatMap { try? decoder.decode([ParkingSession].self, from: $0) } ?? []
    }

    func save(_ session: ParkingSession) {
        if let previous = activeParking { ParkingReminders.cancel(previous.id) }
        activeParking = session
        history.removeAll { $0.id == session.id }
        history.insert(session, at: 0)
        persist()
        ParkingReminders.schedule(session)
    }

    func deleteActiveParking() {
        if let activeParking {
            ParkingReminders.cancel(activeParking.id)
            if !history.contains(where: { $0.id == activeParking.id }) { ImageStore.remove(activeParking.photoFilename) }
        }
        activeParking = nil
        persist()
    }

    func removeHistory(_ session: ParkingSession) {
        history.removeAll { $0.id == session.id }
        if session.id != activeParking?.id {
            ParkingReminders.cancel(session.id)
            ImageStore.remove(session.photoFilename)
        }
        persist()
    }

    func clearHistory() {
        let photos = history.compactMap(\.photoFilename).filter { $0 != activeParking?.photoFilename }
        history.removeAll()
        photos.forEach { ImageStore.remove($0) }
        persist()
    }

    private func persist() {
        let encoder = JSONEncoder()
        if let activeParking, let data = try? encoder.encode(activeParking) {
            defaults.set(data, forKey: activeKey)
        } else {
            defaults.removeObject(forKey: activeKey)
        }
        if let data = try? encoder.encode(history) { defaults.set(data, forKey: historyKey) }
    }
}

enum ParkingReminders {
    static func cancel(_ id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id.uuidString])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id.uuidString])
    }

    static func schedule(_ session: ParkingSession) {
        guard let date = session.reminderAt, date.timeIntervalSinceNow > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Parking reminder"
        content.body = "Time to check your parking at \(session.title). \(session.spotDescription)."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        let request = UNNotificationRequest(identifier: session.id.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
