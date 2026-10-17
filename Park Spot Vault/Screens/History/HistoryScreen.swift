import SwiftUI

struct HistoryScreen: View {
    let history: [ParkingSession]
    let onClearHistory: () -> Void
    let onDeleteSession: (ParkingSession) -> Void
    let onSave: () -> Void
    @State private var searchText = ""
    @State private var selected: ParkingSession?
    @State private var showingClearConfirmation = false
    @State private var pendingDelete: ParkingSession?

    private var filtered: [ParkingSession] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return history }
        return history.filter { [$0.title, $0.note, $0.floor, $0.zone, formattedDate($0.parkedAt)] .contains { $0.localizedCaseInsensitiveContains(query) } }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    HeaderBlock(kicker: "History", title: "Your past stops", subtitle: "Find a place, floor, zone or note.")
                    Spacer(minLength: 8)
                    if !history.isEmpty {
                        Button { showingClearConfirmation = true } label: {
                            Image(systemName: "trash").frame(width: 44, height: 44)
                                .foregroundColor(.vaultDanger).background(Circle().fill(Color.vaultDanger.opacity(0.1)))
                        }
                        .accessibilityLabel("Clear parking history")
                    }
                }
                if !history.isEmpty { SearchField(text: $searchText) }
                if history.isEmpty {
                    EmptyStateCard(icon: "clock.arrow.circlepath", title: "Your story starts here", message: "Save your first spot to build a history of places you've parked.", buttonTitle: "Save parking", action: onSave)
                } else if filtered.isEmpty {
                    EmptyStateCard(icon: "magnifyingglass", title: "No matching stops", message: "Try another place, floor, zone or note.", buttonTitle: "Clear search", action: { searchText = "" })
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(filtered) { session in
                            Button { selected = session } label: { HistoryCard(session: session) }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("history.entry")
                                .contextMenu {
                                    Button(role: .destructive) { pendingDelete = session } label: { Label("Delete from history", systemImage: "trash") }
                                }
                        }
                    }
                }
            }
            .vaultPagePadding()
        }
        .scrollDismissesKeyboard(.interactively)
        .sheet(item: $selected) { session in
            HistoryDetailScreen(session: session, onDelete: {
                onDeleteSession(session)
                selected = nil
            })
                .preferredColorScheme(.dark)
        }
        .confirmationDialog("Clear parking history?", isPresented: $showingClearConfirmation, titleVisibility: .visible) {
            Button("Clear history", role: .destructive) { onClearHistory(); searchText = "" }
        } message: { Text("This removes saved history and its photos. Your active parking is kept.") }
        .alert("Delete this history entry?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("Cancel", role: .cancel) { pendingDelete = nil }
            Button("Delete", role: .destructive) {
                if let session = pendingDelete { onDeleteSession(session) }
                selected = nil
                pendingDelete = nil
            }
        } message: { Text("Your active parking, if any, is kept.") }
    }
}

struct HistoryDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    let session: ParkingSession
    var onDelete: (() -> Void)? = nil
    @State private var confirmingDelete = false

    var body: some View {
        ZStack {
            VaultBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top) {
                        HeaderBlock(kicker: formattedDate(session.parkedAt), title: session.title, subtitle: session.spotDescription)
                        Spacer(minLength: 8)
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.headline).frame(width: 44, height: 44)
                                .background(Circle().fill(Color.white.opacity(0.1)))
                        }
                        .accessibilityLabel("Close parking details")
                    }
                    PremiumParkingScene(colors: session.photoColors, image: ImageStore.load(session.photoFilename))
                        .aspectRatio(1.4, contentMode: .fit)
                    GlassCard {
                        VStack(spacing: 16) {
                            ReviewRow(title: "Floor", value: session.floor.isEmpty ? "Not specified" : session.floor, icon: "square.stack")
                            ReviewRow(title: "Zone", value: session.zone.isEmpty ? "Not specified" : session.zone, icon: "number")
                            ReviewRow(title: "Saved", value: formattedTime(session.parkedAt), icon: "clock")
                            ReviewRow(title: "Location", value: session.mapCoordinate == nil ? "Not saved" : session.coordinate, icon: "location")
                        }
                    }
                    NearbyLandmarksCard(landmarks: session.landmarks, note: session.note)
                    if session.mapCoordinate != nil { NavigationMapCard(session: session) }
                    if onDelete != nil {
                        Button(role: .destructive, action: { confirmingDelete = true }) { Label("Delete from history", systemImage: "trash").frame(maxWidth: .infinity, minHeight: 48) }
                    }
                }
                .vaultPagePadding()
            }
        }
        .alert("Delete this history entry?", isPresented: $confirmingDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { onDelete?() }
        } message: { Text("Your active parking, if any, is kept.") }
    }
}
