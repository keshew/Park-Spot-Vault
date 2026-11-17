import AdjustSdk
import AdSupport
import AppTrackingTransparency
import SwiftUI
import UserNotifications

struct VaultLaunchView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var page: URL?
    @State private var resolvedLaunch = false
    @State private var prefersJournal = false
    @State private var permissionsPrepared = false
    @State private var requests = ArrivalRequests()
    @State private var lookup: Task<Void, Never>?
    private static let pages = ParkingPageClient()

    var body: some View {
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
        .fullScreenCover(isPresented: Binding(get: { page != nil && !prefersJournal }, set: { _ in })) {
            DestinationSurface(address: $page)
                .ignoresSafeArea()
                .safeAreaInset(edge: .top, spacing: 0) {
                    Button {
                        prefersJournal = true
                    } label: {
                        Label("Back to journal", systemImage: "chevron.left")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .padding(.horizontal, 20)
                    }
                    .buttonStyle(.plain)
                    .background(.regularMaterial)
                }
                .interactiveDismissDisabled()
        }
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
        let allowsTracking = ATTrackingManager.trackingAuthorizationStatus == .authorized
        var attributionID = ""
        var advertisingID = ""
        if allowsTracking {
            VaultCampaignRecorder.record(await Adjust.attribution(withTimeout: 1_000))
            attributionID = await Adjust.adid(withTimeout: 1_000) ?? ""
            advertisingID = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        } else {
            ArrivalLedger.campaignSnapshot = nil
        }

        let signals = ArrivalSignals(
            attributionJSON: allowsTracking ? ArrivalLedger.campaignSnapshot : nil,
            registrationToken: token,
            attributionID: attributionID,
            advertisingID: advertisingID,
            hardware: UIDevice.current.model,
            notice: notice
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
    private func preparePermissions() async {
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined,
           UIApplication.shared.applicationState == .active {
            _ = await Adjust.requestAppTrackingAuthorization()
        }

        let notifications = UNUserNotificationCenter.current()
        if await notifications.notificationSettings().authorizationStatus == .notDetermined {
            _ = try? await notifications.requestAuthorization(options: [.alert, .badge, .sound])
        }
        if !UIApplication.shared.isRegisteredForRemoteNotifications {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
}
