import SwiftUI

@main
struct GoldenRunApp: App {
    @UIApplicationDelegateAdaptor(VaultAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            VaultLaunchView()
        }
    }
}
