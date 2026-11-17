import Foundation
import UserNotifications

enum BirdReminders {
    static let opened = Notification.Name("goldenRun.care.opened")
    private static let openedKey = "goldenRun.care.pendingSelection"
    private static let prefix = "goldenRun.care."

    static func owns(_ identifier: String) -> Bool {
        identifier.hasPrefix(prefix)
    }

    static func markOpened() {
        UserDefaults.standard.set(true, forKey: openedKey)
        NotificationCenter.default.post(name: opened, object: nil)
    }

    static func takeOpened() -> Bool {
        guard UserDefaults.standard.bool(forKey: openedKey) else { return false }
        UserDefaults.standard.removeObject(forKey: openedKey)
        return true
    }

    static func cancel(_ id: UUID) {
        let identifier = prefix + id.uuidString
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    static func ensurePermission() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return try await center.requestAuthorization(options: [.alert, .sound])
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    static func schedule(_ task: BirdCareTask) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Flock care"
        content.body = task.title
        content.sound = .default
        let calendar = Calendar.current
        let date = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: task.due)
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: false)
        try await UNUserNotificationCenter.current().add(.init(
            identifier: prefix + task.id.uuidString, content: content, trigger: trigger
        ))
    }
}
