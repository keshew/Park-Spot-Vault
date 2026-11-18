import AdjustSdk
import AdSupport
import AppTrackingTransparency
import OSLog
import SwiftUI
import UserNotifications

struct VaultLaunchView: View {
    @State private var loadedPage: URL?
    @Environment(\.scenePhase) private var scenePhase
    @State private var page: URL?
    @State private var resolvedLaunch = false
    @State private var prefersJournal = false
    @State private var permissionsPrepared = false
    @State private var requests = ArrivalRequests()
    @State private var lookup: Task<Void, Never>?
    private static let pages = ParkingPageClient()
    private static let attributionTimeoutMilliseconds = 15_000
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "GoldenRun", category: "Registration")

    var body: some View {
        let webContentIsReady = isPageVisible
        ZStack {
            if resolvedLaunch {
                JournalView(canOpenPage: page != nil, openPage: { prefersJournal = false })
            }
            if !resolvedLaunch || (page != nil && !prefersJournal) {
                ArrivalLoadingPlate()
            }
        }
        .task(id: waitsForRegistration) {
            guard waitsForRegistration else { return }
            do {
                try await Task.sleep(for: .seconds(15))
                if waitsForRegistration { finishLaunch() }
            } catch {
                return
            }
        }
        .onAppear {
            showJournalForReminder()
            updateScene(scenePhase)
        }
        .onChange(of: scenePhase) { updateScene($0) }
        .onReceive(NotificationCenter.default.publisher(for: ArrivalLedger.noticeSelected)) { _ in
            prefersJournal = false
            resolve()
        }
        .onReceive(NotificationCenter.default.publisher(for: BirdReminders.opened)) { _ in
            showJournalForReminder()
        }
        .onReceive(NotificationCenter.default.publisher(for: ArrivalLedger.registrationChanged)) { _ in
            resolve()
        }
        .fullScreenCover(isPresented: Binding(get: { page != nil && !prefersJournal }, set: { _ in }), onDismiss: { loadedPage = nil }) {
            DestinationSurface(address: page, didLoad: { loadedPage = $0 })
                .accessibilityHidden(!webContentIsReady)
                .overlay {
                    if !webContentIsReady {
                        ArrivalLoadingPlate(title: "Opening page…")
                    }
                }
                .interactiveDismissDisabled()
                .task(id: page) {
                    guard let requested = page, !isPageVisible else { return }
                    do {
                        try await Task.sleep(for: .seconds(25))
                        if page == requested, !isPageVisible {
                            page = nil
                        }
                    } catch {
                        return
                    }
                }
        }
    }

    private var isPageVisible: Bool {
        guard let requested = page else { return false }
        return loadedPage == requested
    }

    private func showJournalForReminder() {
        if BirdReminders.takeOpened() {
            prefersJournal = true
            resolvedLaunch = true
        }
    }

    @MainActor
    private func updateScene(_ phase: ScenePhase) {
        if phase == .background {
            requests.setForeground(false)
        } else if phase == .active, !requests.isForeground {
            requests.setForeground(true)
            resolve()
        }
    }

    private var waitsForRegistration: Bool {
        requests.isForeground && permissionsPrepared && !resolvedLaunch && ArrivalLedger.registrationToken == nil
    }

    @MainActor
    private func resolve() {
        guard requests.isForeground, lookup == nil else { return }
        lookup = Task { @MainActor in
            defer { lookup = nil }
            if !permissionsPrepared {
                await preparePermissions()
                permissionsPrepared = true
            }

            while let token = ArrivalLedger.registrationToken,
                  let reason = requests.next(token: token, hasNotice: ArrivalLedger.hasQueuedNotice) {
                let notice = ArrivalLedger.takeNotice()
                await findPage(token: token, notice: notice, reason: reason)
            }
        }
    }

    @MainActor
    private func findPage(token: String, notice: NoticeArrival?, reason: ArrivalRequests.Reason) async {
        await requestTrackingIfActive()
        var adid = ""
        if ATTrackingManager.trackingAuthorizationStatus == .authorized {
            async let pendingADID = Adjust.adid(withTimeout: Self.attributionTimeoutMilliseconds)
            VaultCampaignRecorder.record(await Adjust.attribution(withTimeout: Self.attributionTimeoutMilliseconds))
            adid = await pendingADID ?? ""
        }

        let trackingStatus = ATTrackingManager.trackingAuthorizationStatus
        let allowsTracking = trackingStatus == .authorized
        if !allowsTracking { ArrivalLedger.campaignSnapshot = nil }

        let signals = ArrivalSignals(
            attributionJSON: allowsTracking ? ArrivalLedger.campaignSnapshot : nil,
            registrationToken: token,
            attributionID: allowsTracking ? adid : "",
            advertisingID: allowsTracking ? ASIdentifierManager.shared().advertisingIdentifier.uuidString : "",
            hardware: UIDevice.current.model,
            notice: notice
        )

        Self.logger.notice(
            "Sending registration. ATT: \(trackingStatus.rawValue), ADID: \(!signals.attributionID.isEmpty), attribution: \(signals.attributionJSON != nil)"
        )
        do {
            if let destination = try await Self.pages.lookup(signals),
               reason == .session || page == nil {
                ArrivalLedger.lastPage = destination
                page = destination
            }
        } catch {
            print("Golden Run: could not resolve destination")
        }

        finishLaunch()
    }

    @MainActor
    private func finishLaunch() {
        if page == nil { page = ArrivalLedger.lastPage }
        resolvedLaunch = true
    }

    @MainActor
    private func requestTrackingIfActive() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        for _ in 0..<10 {
            if UIApplication.shared.applicationState == .active { break }
            try? await Task.sleep(for: .milliseconds(300))
        }
        if UIApplication.shared.applicationState == .active {
            _ = await Adjust.requestAppTrackingAuthorization()
        }
    }

    @MainActor
    private func preparePermissions() async {
        await requestTrackingIfActive()

        let notifications = UNUserNotificationCenter.current()
        if await notifications.notificationSettings().authorizationStatus == .notDetermined {
            _ = try? await notifications.requestAuthorization(options: [.alert, .badge, .sound])
        }
        if !UIApplication.shared.isRegisteredForRemoteNotifications {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
}
