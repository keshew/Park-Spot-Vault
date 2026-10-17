import SwiftUI

struct SettingsScreen: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var permissions: PermissionCenter
    let onShowInfo: (InfoSheet) -> Void
    let onOpenGuide: () -> Void
    @AppStorage("parkSpotVault.units") private var units = "Meters"

    private var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HeaderBlock(kicker: "Settings", title: "Make it yours", subtitle: "A few preferences for your way back.")
                SectionHeader(title: "Help & getting started", action: nil)
                ParkingBuddyGuideCard(onOpen: onOpenGuide, title: "Parking guide")

                GlassCard {
                    SettingsSegment(title: "Distance units", icon: "ruler", value: $units, options: ["Meters", "Feet"])
                }
                SectionHeader(title: "Access & reminders", action: nil)
                GlassCard {
                    VStack(spacing: 20) {
                        PermissionRow(title: "Camera", status: permissions.cameraStatus, icon: "camera", color: .vaultAccent) { permissions.requestCamera() }
                        PermissionRow(title: "Location", status: permissions.locationStatus, icon: "location", color: .vaultSecondary) { permissions.requestLocation() }
                        PermissionRow(title: "Notifications", status: permissions.notificationStatus, icon: "bell", color: .vaultWarning) { permissions.requestNotifications() }
                    }
                }
                Text("All access is optional. Set a reminder while saving a parking spot; it is cancelled when you finish parking.")
                    .font(.subheadline).foregroundColor(.vaultMuted)
                SectionHeader(title: "About your vault", action: nil)
                GlassCard {
                    VStack(spacing: 0) {
                        infoButton(.about, title: "Version", value: version)
                        Divider().overlay(Color.white.opacity(0.05))
                        infoButton(.privacy, title: "Privacy", value: "On this device")
                        Divider().overlay(Color.white.opacity(0.05))
                        infoButton(.terms, title: "Using the app", value: "Parking companion")
                    }
                }
                Label("Your saved photos and parking details stay on this device.", systemImage: "internaldrive")
                    .font(.footnote).foregroundColor(.vaultMuted)
            }
            .vaultPagePadding()
        }
        .onAppear { permissions.refresh() }
        .onChange(of: scenePhase) { if $0 == .active { permissions.refresh() } }
    }

    private func infoButton(_ sheet: InfoSheet, title: String, value: String) -> some View {
        Button { onShowInfo(sheet) } label: { AboutRow(title: title, value: value).padding(.vertical, 16) }
            .buttonStyle(.plain)
    }
}

struct InfoSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let sheet: InfoSheet

    var body: some View {
        ZStack {
            VaultBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .top) {
                        HeaderBlock(kicker: "Park Spot Vault", title: sheet.title, subtitle: "Your parking companion")
                        Spacer(minLength: 8)
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.headline).frame(width: 44, height: 44)
                                .background(Circle().fill(Color.white.opacity(0.1)))
                        }
                        .accessibilityLabel("Close information")
                    }
                    GlassCard {
                        Text(sheet.bodyText).font(.body).foregroundColor(.vaultMuted).lineSpacing(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .vaultPagePadding()
            }
        }
    }
}
