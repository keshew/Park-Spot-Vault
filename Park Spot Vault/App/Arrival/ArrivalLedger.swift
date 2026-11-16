import Foundation

struct NoticeArrival: Sendable {
    let identifier: String?
}

enum ArrivalLedger {
    private enum Slot {
        static let installation = "parkSpotVault.arrival.installation"
        static let client = "parkSpotVault.arrival.client"
        static let directory = "parkSpotVault.arrival.directory"
        static let page = "parkSpotVault.arrival.page"
        static let registration = "parkSpotVault.arrival.registration"
        static let messagingProject = "parkSpotVault.arrival.messagingProject"
        static let campaign = "parkSpotVault.arrival.campaign"
        static let queuedNotice = "parkSpotVault.arrival.queuedNotice"
    }

    static let noticeSelected = Notification.Name("parkSpotVault.arrival.noticeSelected")

    static func installationIdentifier(in defaults: UserDefaults = .standard) -> String {
        identifier(for: Slot.installation, in: defaults)
    }

    static func clientIdentifier(in defaults: UserDefaults = .standard) -> String {
        identifier(for: Slot.client, in: defaults)
    }

    static func savedDirectory(in defaults: UserDefaults) -> URL? {
        ArrivalDirectory.address(defaults.string(forKey: Slot.directory))
    }

    static func saveDirectory(_ address: URL, in defaults: UserDefaults) {
        defaults.set(address.absoluteString, forKey: Slot.directory)
    }

    static var lastPage: URL? {
        get { ArrivalDirectory.address(UserDefaults.standard.string(forKey: Slot.page)) }
        set { UserDefaults.standard.set(newValue?.absoluteString, forKey: Slot.page) }
    }

    static var registrationToken: String? {
        get { UserDefaults.standard.string(forKey: Slot.registration) }
        set { UserDefaults.standard.set(newValue, forKey: Slot.registration) }
    }

    static var campaignSnapshot: String? {
        get { UserDefaults.standard.string(forKey: Slot.campaign) }
        set { UserDefaults.standard.set(newValue, forKey: Slot.campaign) }
    }

    static var hasQueuedNotice: Bool {
        UserDefaults.standard.string(forKey: Slot.queuedNotice) != nil
    }

    static func useMessagingProject(_ identifier: String) {
        guard UserDefaults.standard.string(forKey: Slot.messagingProject) != identifier else { return }
        registrationToken = nil
        UserDefaults.standard.set(identifier, forKey: Slot.messagingProject)
    }

    static func enqueueNotice(identifier: String?) {
        UserDefaults.standard.set(identifier ?? "", forKey: Slot.queuedNotice)
    }

    static func takeNotice() -> NoticeArrival? {
        guard let queued = UserDefaults.standard.string(forKey: Slot.queuedNotice) else { return nil }
        UserDefaults.standard.removeObject(forKey: Slot.queuedNotice)
        return NoticeArrival(identifier: queued.isEmpty ? nil : queued)
    }

    private static func identifier(for key: String, in defaults: UserDefaults) -> String {
        if let saved = defaults.string(forKey: key), UUID(uuidString: saved) != nil {
            return saved
        }
        let identifier = UUID().uuidString.lowercased()
        defaults.set(identifier, forKey: key)
        return identifier
    }
}
