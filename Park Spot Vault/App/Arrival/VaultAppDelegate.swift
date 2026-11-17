import AdjustSdk
import AppTrackingTransparency
import FirebaseCore
import FirebaseMessaging
import UIKit
import UserNotifications

final class VaultAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    private let campaignToken = "jvvbjzohdt6o"
    private let campaignRecorder = VaultCampaignRecorder()
    private var registrationTask: Task<Void, Never>?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        _ = ArrivalLedger.installationIdentifier()
        _ = ArrivalLedger.clientIdentifier()

        FirebaseApp.configure()
        if let project = FirebaseApp.app()?.options.googleAppID {
            ArrivalLedger.useMessagingProject(project)
        }
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        Messaging.messaging().isAutoInitEnabled = true
        application.registerForRemoteNotifications()

        if let config = ADJConfig(appToken: campaignToken, environment: ADJEnvironmentProduction) {
            config.delegate = campaignRecorder
            config.logLevel = .info
            config.attConsentWaitingInterval = 30
            Adjust.initSdk(config)
        }

        if let payload = options?[.remoteNotification] as? [AnyHashable: Any] {
            ArrivalLedger.enqueueNotice(identifier: Self.noticeIdentifier(in: payload))
        }
        return true
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken token: String?) {
        guard messaging.apnsToken != nil else { return }
        DispatchQueue.main.async { Self.retainRegistration(token) }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken token: Data) {
        let messaging = Messaging.messaging()
        messaging.apnsToken = token
        registrationTask?.cancel()
        registrationTask = Task { @MainActor in
            for delay in [0, 2, 5] {
                do {
                    if delay > 0 { try await Task.sleep(for: .seconds(delay)) }
                    try Task.checkCancellation()
                    let registration = try await messaging.token()
                    try Task.checkCancellation()
                    Self.retainRegistration(registration)
                    return
                } catch {
                    if Task.isCancelled { return }
                }
            }
            print("Golden Run: could not retrieve FCM registration after APNs")
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Golden Run: APNs registration failed")
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if notification.request.trigger is UNPushNotificationTrigger {
            Messaging.messaging().appDidReceiveMessage(notification.request.content.userInfo)
            completionHandler([.banner, .list, .sound, .badge])
        } else if BirdReminders.owns(notification.request.identifier) {
            completionHandler([.banner, .list, .sound])
        } else {
            completionHandler([])
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        guard response.notification.request.trigger is UNPushNotificationTrigger else {
            if BirdReminders.owns(response.notification.request.identifier) {
                DispatchQueue.main.async { BirdReminders.markOpened() }
            }
            completionHandler()
            return
        }
        let payload = response.notification.request.content.userInfo
        Messaging.messaging().appDidReceiveMessage(payload)
        let identifier = Self.noticeIdentifier(in: payload)
        DispatchQueue.main.async {
            ArrivalLedger.enqueueNotice(identifier: identifier)
            NotificationCenter.default.post(name: ArrivalLedger.noticeSelected, object: nil)
        }
        completionHandler()
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification payload: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Messaging.messaging().appDidReceiveMessage(payload)
        completionHandler(.newData)
    }

    @MainActor
    private static func retainRegistration(_ raw: String?) {
        guard let token = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty, token != "null", token != ArrivalLedger.registrationToken else { return }
        ArrivalLedger.registrationToken = token
        NotificationCenter.default.post(name: ArrivalLedger.registrationChanged, object: nil)
    }

    private static func noticeIdentifier(in object: Any) -> String? {
        if let payload = object as? [AnyHashable: Any] {
            for key in ["push_id", "gcm.notification.push_id"] {
                guard let value = payload[key] else { continue }
                let identifier = String(describing: value).trimmingCharacters(in: .whitespacesAndNewlines)
                if !identifier.isEmpty { return identifier }
            }
            for key in ["push_data", "data"] {
                if let value = payload[key], let identifier = noticeIdentifier(in: value) {
                    return identifier
                }
            }
        } else if let text = object as? String,
                  let data = text.data(using: .utf8),
                  let payload = try? JSONSerialization.jsonObject(with: data) {
            return noticeIdentifier(in: payload)
        }
        return nil
    }
}

final class VaultCampaignRecorder: NSObject, AdjustDelegate {
    func adjustAttributionChanged(_ attribution: ADJAttribution?) {
        DispatchQueue.main.async { Self.record(attribution) }
    }

    @MainActor
    static func record(_ attribution: ADJAttribution?) {
        guard ATTrackingManager.trackingAuthorizationStatus == .authorized,
              let values = attribution?.jsonResponse, JSONSerialization.isValidJSONObject(values),
              let data = try? JSONSerialization.data(withJSONObject: values) else { return }
        ArrivalLedger.campaignSnapshot = String(data: data, encoding: .utf8)
    }
}
