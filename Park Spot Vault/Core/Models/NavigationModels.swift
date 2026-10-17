import Foundation

enum VaultTab: String, CaseIterable, Identifiable {
    case home
    case navigate
    case history
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .navigate: return "Navigate"
        case .history: return "History"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .navigate: return "location.north.line.fill"
        case .history: return "folder.fill"
        case .settings: return "gearshape.fill"
        }
    }
}


enum NavigateMode: Int, CaseIterable, Identifiable {
    case map
    case compass
    case timer
    case landmarks

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .map: return "Map"
        case .compass: return "Compass"
        case .timer: return "Timer"
        case .landmarks: return "Places"
        }
    }
}



enum InfoSheet: String, Identifiable {
    case privacy
    case terms
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privacy: return "Privacy"
        case .terms: return "Using the app"
        case .about: return "About"
        }
    }

    var bodyText: String {
        switch self {
        case .privacy:
            return "Park Spot Vault stores parking sessions locally on this device. Location and camera access are optional. Notifications are used for reminders you choose. Opening walking directions shares the destination with Apple Maps."
        case .terms:
            return "Use Park Spot Vault as a parking aid. Always follow local signage, garage rules, and safe navigation practices when returning to your car."
        case .about:
            return "Park Spot Vault helps you save parking locations, photos, floors and notes, set a reminder and find the way back. Your history is stored locally on this device."
        }
    }
}
