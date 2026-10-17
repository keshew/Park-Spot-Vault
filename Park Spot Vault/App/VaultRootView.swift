import SwiftUI

struct VaultRootView: View {
    @StateObject private var store = ParkingStore()
    @StateObject private var permissions = PermissionCenter()
    @State private var selectedTab: VaultTab = .home
    @State private var navigateMode: NavigateMode = .map
    @State private var presentedFlow: VaultPresentation?
    @State private var showingDeleteConfirmation = false
    @State private var showingInfoSheet: InfoSheet?

    var body: some View {
        ZStack {
            Group {
                switch selectedTab {
                case .home:
                    HomeScreen(
                        activeParking: store.activeParking,
                        history: store.history,
                        onSave: { presentedFlow = .save },
                        onOpenGuide: { presentedFlow = .guide },
                        onNavigate: {
                            navigateMode = .map
                            selectedTab = .navigate
                        },
                        onTimer: {
                            navigateMode = .timer
                            selectedTab = .navigate
                        },
                        onLandmarks: {
                            navigateMode = .landmarks
                            selectedTab = .navigate
                        },
                        onHistorySearch: {
                            selectedTab = .history
                        },
                        onDelete: { showingDeleteConfirmation = true }
                    )
                case .navigate:
                    NavigateScreen(activeParking: store.activeParking, mode: $navigateMode) {
                        presentedFlow = .save
                    }
                case .history:
                    HistoryScreen(
                        history: store.history,
                        onClearHistory: { store.clearHistory() },
                        onDeleteSession: { store.removeHistory($0) },
                        onSave: { presentedFlow = .save }
                    )
                case .settings:
                    SettingsScreen(
                        permissions: permissions,
                        onShowInfo: { showingInfoSheet = $0 },
                        onOpenGuide: { presentedFlow = .guide }
                    )
                }
            }
        }
        .background { VaultBackground() }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FloatingTabBar(selectedTab: $selectedTab)
                .background(LinearGradient(colors: [.vaultBackground.opacity(0), .vaultBackground], startPoint: .top, endPoint: .bottom))
        }
        .fullScreenCover(item: $presentedFlow) { presentation in
            switch presentation {
            case .save:
                SaveParkingFlow(permissions: permissions) { session in
                    store.save(session)
                }
                .preferredColorScheme(.dark)
            case .guide:
                OnboardingScreen(onClose: { presentedFlow = nil }) {
                    presentedFlow = nil
                }
            }
        }
        .confirmationDialog("Finish this parking session?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Finish parking") { store.deleteActiveParking() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your saved photo and details will stay in History.")
        }
        .sheet(item: $showingInfoSheet) { sheet in
            InfoSheetView(sheet: sheet)
                .preferredColorScheme(.dark)
        }
        .animation(.spring(response: 0.46, dampingFraction: 0.84), value: selectedTab)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: showingDeleteConfirmation)
    }
}

private enum VaultPresentation: String, Identifiable {
    case save
    case guide

    var id: String { rawValue }
}
