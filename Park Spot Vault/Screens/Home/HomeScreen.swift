import SwiftUI

struct HomeScreen: View {
    let activeParking: ParkingSession?
    let history: [ParkingSession]
    let onSave: () -> Void
    let onOpenGuide: () -> Void
    let onNavigate: () -> Void
    let onTimer: () -> Void
    let onLandmarks: () -> Void
    let onHistorySearch: () -> Void
    let onDelete: () -> Void
    @State private var selectedSession: ParkingSession?

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    HeaderBlock(kicker: "Park Spot Vault", title: greeting, subtitle: activeParking == nil ? "Make your next return a little easier." : "Your car's details, all in one place.")
                    Spacer(minLength: 8)
                    Button(action: onSave) {
                        Image(systemName: "plus").font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.vaultBackground).frame(width: 44, height: 44)
                            .background(Circle().fill(LinearGradient.vaultAccent))
                    }
                    .accessibilityLabel("Save a new parking spot")
                    .accessibilityIdentifier("parking.add")
                }
                ParkingBuddyGuideCard(onOpen: onOpenGuide)

                if let activeParking {
                    CurrentParkingCard(session: activeParking, onNavigate: onNavigate, onDelete: onDelete)
                } else { NoActiveParkingCard(onSave: onSave) }

                if activeParking != nil {
                    SectionHeader(title: "Quick actions", action: nil)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ActionTile(title: "Parking timer", icon: "timer", color: .vaultSecondary, action: onTimer)
                        ActionTile(title: "Saved landmarks", icon: "mappin.and.ellipse", color: .vaultAccent, action: onLandmarks)
                    }
                }
                HStack {
                    SectionHeader(title: "Recent stops", action: nil)
                    if !history.isEmpty {
                        Button("See all", action: onHistorySearch).font(.subheadline.weight(.semibold)).tint(.vaultAccent)
                            .frame(minHeight: 44)
                    }
                }
                if history.isEmpty {
                    Text("Saved parking sessions will appear here after your first stop.")
                        .font(.subheadline).foregroundColor(.vaultMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20).background(GlassFill())
                } else {
                    ForEach(history.prefix(3)) { session in
                        Button { selectedSession = session } label: { CompactParkingCard(session: session) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .vaultPagePadding()
        }
        .sheet(item: $selectedSession) { HistoryDetailScreen(session: $0).preferredColorScheme(.dark) }
    }
}
