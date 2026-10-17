import SwiftUI

struct StatusPill: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(size: 11, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundColor(.vaultBackground)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Capsule().fill(color))
    }
}

struct MicroStat: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundColor(.vaultMuted)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(color.opacity(0.08)))
    }
}

struct CurrentParkingCard: View {
    let session: ParkingSession
    let onNavigate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    StatusPill(title: "Parked", icon: "parkingsign", color: .vaultSecondary)
                    Spacer()
                    Text(formattedTime(session.parkedAt))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.vaultMuted)
                }
                PremiumParkingScene(colors: session.photoColors, image: ImageStore.load(session.photoFilename))
                    .aspectRatio(1.6, contentMode: .fit)

                VStack(alignment: .leading, spacing: 7) {
                    Text(session.title)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(session.spotDescription)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.vaultSecondary)
                    if !session.note.isEmpty {
                        Text(session.note).font(.system(size: 15)).foregroundColor(.vaultMuted).lineLimit(3)
                    }
                }
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    HStack(spacing: 8) {
                        MicroStat(title: "Parked for", value: parkingDuration(since: session.parkedAt, now: context.date), color: .vaultSecondary)
                        MicroStat(title: "Location", value: session.mapCoordinate == nil ? "Not saved" : "GPS saved", color: .vaultAccent)
                    }
                }
                HStack(spacing: 10) {
                    LiquidMiniButton(title: "Find my car", icon: "location.north.fill", action: onNavigate)
                    Button(action: onDelete) {
                        Image(systemName: "checkmark.flag.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.vaultSecondary)
                            .frame(width: 50, height: 50)
                            .background(Circle().fill(Color.vaultSecondary.opacity(0.1)))
                    }
                    .accessibilityLabel("Finish parking")
                    .accessibilityIdentifier("parking.finish")
                }
            }
        }
    }
}

struct NoActiveParkingCard: View {
    let onSave: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                PremiumEmptyIllustration().frame(height: 190)
                Text("Ready for your next stop")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                Text("Save a photo, a location and a few details. We'll keep them together for your return.")
                    .font(.system(size: 15))
                    .foregroundColor(.vaultMuted)
                    .fixedSize(horizontal: false, vertical: true)
                LiquidMiniButton(title: "Save parking", icon: "plus", action: onSave)
            }
        }
    }
}

struct NavigationMapCard: View {
    let session: ParkingSession
    var distance = "—"

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text(session.title).font(.system(size: 24, weight: .bold, design: .rounded))
                Text(session.spotDescription).font(.subheadline).foregroundColor(.vaultSecondary)
                ParkingMapView(session: session).frame(height: 240)
                if session.mapCoordinate != nil {
                    if distance != "—" {
                        Label("\(distance) away in a straight line", systemImage: "location")
                            .font(.subheadline).foregroundColor(.vaultMuted)
                    }
                    LiquidMiniButton(title: "Walking directions", icon: "arrow.triangle.turn.up.right.diamond.fill") {
                        openParkingDirections(session)
                    }
                    Text("Opens Apple Maps for a walking route.")
                        .font(.caption).foregroundColor(.vaultMuted)
                }
            }
        }
    }
}

struct ParkingTimerCard: View {
    let session: ParkingSession

    var body: some View {
        GlassCard {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(spacing: 18) {
                    Image(systemName: "timer").font(.system(size: 44)).foregroundColor(.vaultSecondary)
                    Text("Time parked").font(.headline).foregroundColor(.vaultMuted)
                    Text(timerText(now: context.date))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
                    Text("Since \(formattedTime(session.parkedAt)) · \(formattedDate(session.parkedAt))")
                        .font(.subheadline).foregroundColor(.vaultMuted).multilineTextAlignment(.center)
                    if let reminder = session.reminderAt {
                        Label(reminder > context.date ? "Reminder at \(formattedTime(reminder))" : "Reminder time has passed", systemImage: "bell")
                            .font(.subheadline).foregroundColor(.vaultAccent)
                    }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 20)
            }
        }
    }

    private func timerText(now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(session.parkedAt)))
        return String(format: "%02d:%02d:%02d", seconds / 3600, seconds % 3600 / 60, seconds % 60)
    }
}

struct NearbyLandmarksCard: View {
    let landmarks: [String]
    var note = ""

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("Your landmarks & notes", systemImage: "mappin.and.ellipse")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                if !note.isEmpty { Text(note).font(.body).foregroundColor(.vaultMuted) }
                ForEach(Array(landmarks.enumerated()), id: \.offset) { _, landmark in
                    Label(landmark, systemImage: "mappin.circle.fill")
                        .font(.subheadline).foregroundColor(.vaultSecondary)
                }
                if note.isEmpty && landmarks.isEmpty {
                    Text("No landmarks saved for this spot. Add an entrance, pillar or nearby sign next time you park.")
                        .font(.subheadline).foregroundColor(.vaultMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
