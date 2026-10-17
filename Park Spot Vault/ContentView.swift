import SwiftUI

struct ContentView: View {
    @AppStorage("parkSpotVault.hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage(ParkingGuide.versionKey) private var completedGuideVersion = 0
    @State private var phase: LaunchPhase = .loading

    var body: some View {
        ZStack {
            switch phase {
            case .loading:
                LoadingScreen()
                    .transition(.opacity)
            case .onboarding:
                OnboardingScreen {
                    hasCompletedOnboarding = true
                    completedGuideVersion = ParkingGuide.version
                    withAnimation(.spring(response: 0.7, dampingFraction: 0.86)) {
                        phase = .app
                    }
                }
                .transition(.opacity)
            case .app:
                VaultRootView()
                    .transition(.opacity)
            }
        }
        .background { VaultBackground() }
        .preferredColorScheme(.dark)
        .tint(.vaultAccent)
        .task {
            do {
                try await Task.sleep(nanoseconds: 4_000_000_000)
            } catch {
                return
            }

            withAnimation(.easeOut(duration: 0.3)) {
                phase = hasCompletedOnboarding && completedGuideVersion >= ParkingGuide.version ? .app : .onboarding
            }
        }
    }
}

enum LaunchPhase {
    case loading
    case onboarding
    case app
}


#Preview {
    ContentView()
}
