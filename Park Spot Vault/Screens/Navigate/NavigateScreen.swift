import SwiftUI

struct NavigateScreen: View {
    let activeParking: ParkingSession?
    @Binding var mode: NavigateMode
    let onSave: () -> Void
    @StateObject private var location = LocationProvider()
    @AppStorage("parkSpotVault.units") private var units = "Meters"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HeaderBlock(kicker: "Navigate", title: "Back to your car", subtitle: "Your saved spot, photo and directions.")
                if let session = activeParking {
                    Picker("Navigation view", selection: $mode) {
                        ForEach(NavigateMode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if mode == .map {
                        ParkingBuddyTip(
                            artwork: .returning,
                            title: "Let's find your car",
                            message: session.mapCoordinate == nil
                                ? "There's no GPS point for this stop. Open Places to see your photo, floor and saved landmarks."
                                : "Tap Walking directions to follow a route in Apple Maps. Your photo and landmarks are under Places."
                        )
                        NavigationMapCard(session: session, distance: distanceText(session))
                    } else if mode == .compass {
                        compassCard(session)
                    } else if mode == .timer {
                        ParkingTimerCard(session: session)
                    }
                    if mode == .landmarks {
                        NearbyLandmarksCard(landmarks: session.landmarks, note: session.note)
                        PremiumParkingScene(colors: session.photoColors, image: ImageStore.load(session.photoFilename))
                            .aspectRatio(1.4, contentMode: .fit)
                        Text(session.spotDescription).font(.headline).foregroundColor(.vaultSecondary)
                    }
                    if mode == .map && session.mapCoordinate != nil && !location.isAuthorized {
                        SecondaryButton(title: "Enable live distance", icon: "location") { location.startTracking() }
                    }
                    if let error = location.errorMessage {
                        Text(error).font(.subheadline).foregroundColor(.vaultWarning)
                    }
                } else {
                    EmptyStateCard(icon: "parkingsign.circle", title: "No active parking", message: "Save a spot first. Your location, photo and details will be ready here.", buttonTitle: "Save parking", action: onSave)
                }
            }
            .vaultPagePadding()
        }
        .onAppear { location.startTracking(requestPermission: false) }
        .onDisappear { location.stop() }
    }

    private func distanceText(_ session: ParkingSession) -> String {
        parkingDistance(session.mapCoordinate.flatMap { location.distance(to: $0) }, units: units)
    }

    private func compassCard(_ session: ParkingSession) -> some View {
        GlassCard {
            VStack(spacing: 18) {
                if let coordinate = session.mapCoordinate, let bearing = location.bearing(to: coordinate), let heading = location.heading {
                    CompassDial(direction: bearing - heading).frame(maxWidth: 260)
                    Text("\(distanceText(session)) to your car").font(.title3.bold())
                    Text("The arrow shows the straight-line direction. Use Maps to follow a walking route.")
                        .font(.subheadline).foregroundColor(.vaultMuted).multilineTextAlignment(.center)
                } else {
                    Image(systemName: "safari").font(.system(size: 56)).foregroundColor(.vaultAccent)
                    Text(session.mapCoordinate == nil ? "No GPS location saved" : "Waiting for location & compass")
                        .font(.title3.bold()).multilineTextAlignment(.center)
                    Text("Live direction needs a saved location, location access and a device with a compass. Your parking photo and notes are always available.")
                        .font(.subheadline).foregroundColor(.vaultMuted).multilineTextAlignment(.center)
                    if session.mapCoordinate != nil {
                        SecondaryButton(title: "Update location", icon: "location") { location.startTracking() }
                    }
                }
                if session.mapCoordinate != nil {
                    LiquidMiniButton(title: "Open walking directions", icon: "map") { openParkingDirections(session) }
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 8)
        }
    }
}
