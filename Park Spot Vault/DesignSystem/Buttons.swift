import SwiftUI

struct LiquidButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Image(systemName: icon)
            }
            .font(.system(size: 17, weight: .bold))
            .foregroundColor(.vaultBackground)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(Capsule().fill(LinearGradient.vaultAccent))
            .shadow(color: .vaultAccent.opacity(0.32), radius: 22, x: 0, y: 12)
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.4)
    }
}

struct LiquidMiniButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.vaultBackground)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Capsule().fill(LinearGradient.vaultAccent))
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.4)
    }
}

struct SecondaryButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Capsule().fill(Color.white.opacity(0.1)))
            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.4)
    }
}
