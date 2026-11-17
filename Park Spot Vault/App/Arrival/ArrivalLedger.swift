import Foundation

struct NoticeArrival: Sendable {
    let identifier: String?
}

struct ArrivalRequests {
    enum Reason {
        case session
        case registrationChange
    }

    private(set) var isForeground = false
    private var sessionPending = false
    private var lastToken: String?

    mutating func setForeground(_ active: Bool) {
        guard isForeground != active else { return }
        isForeground = active
        if active { sessionPending = true }
    }

    mutating func next(token: String, hasNotice: Bool) -> Reason? {
        guard isForeground, sessionPending || hasNotice || lastToken != token else { return nil }
        let reason: Reason = sessionPending || hasNotice ? .session : .registrationChange
        sessionPending = false
        lastToken = token
        return reason
    }
}

enum ArrivalLedger {
    private enum Slot {
        static let installation = "parkSpotVault.arrival.installation"
        static let client = "parkSpotVault.arrival.client"
        static let serverClient = "parkSpotVault.arrival.serverClient"
        static let directory = "parkSpotVault.arrival.directory"
        static let page = "parkSpotVault.arrival.page"
        static let registration = "parkSpotVault.arrival.registration"
        static let messagingProject = "parkSpotVault.arrival.messagingProject"
        static let campaign = "parkSpotVault.arrival.campaign"
        static let queuedNotice = "parkSpotVault.arrival.queuedNotice"
    }

    static let registrationChanged = Notification.Name("parkSpotVault.arrival.registrationChanged")
    static let noticeSelected = Notification.Name("parkSpotVault.arrival.noticeSelected")

    static func installationIdentifier(in defaults: UserDefaults = .standard) -> String {
        identifier(for: Slot.installation, in: defaults)
    }

    static func clientIdentifier(in defaults: UserDefaults = .standard) -> String {
        identifier(for: Slot.client, in: defaults)
    }

    static func requestClientIdentifier(in defaults: UserDefaults) -> String {
        if let stored = defaults.string(forKey: Slot.serverClient), UUID(uuidString: stored) != nil {
            return stored
        }
        return clientIdentifier(in: defaults)
    }

    static func saveServerIdentifier(_ value: String?, in defaults: UserDefaults) {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              UUID(uuidString: value) != nil else { return }
        defaults.set(value, forKey: Slot.serverClient)
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
        get {
            guard let token = UserDefaults.standard.string(forKey: Slot.registration),
                  !token.isEmpty, token != "null" else { return nil }
            return token
        }
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
