import SwiftUI

struct FloatingTabBar: View {
    @Binding var selectedTab: VaultTab
    @Namespace private var tabNamespace

    var body: some View {
        HStack(spacing: 6) {
            ForEach(VaultTab.allCases) { tab in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    selectedTab = tab
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: .bold))
                        Text(tab.title)
                            .font(.system(size: 11, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .foregroundColor(selectedTab == tab ? .vaultBackground : .vaultMuted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background {
                        if selectedTab == tab {
                            Capsule()
                                .fill(LinearGradient.vaultAccent)
                                .matchedGeometryEffect(id: "tabIndicator", in: tabNamespace)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tab." + tab.rawValue)
            }
        }
        .padding(8)
        .background(
            Capsule()
                .fill(Color.vaultSurface.opacity(0.96))
        )
        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.24), radius: 16, x: 0, y: 10)
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}

struct HeaderBlock: View {
    let kicker: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(kicker.uppercased())
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.vaultAccent)
            Text(title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.76)
            Text(subtitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.vaultMuted)
        }
    }
}

struct SectionHeader: View {
    let title: String
    let action: String?

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Spacer()
            if let action {
                Text(action)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.vaultAccent)
            }
        }
    }
}

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(GlassFill())
            .shadow(color: .black.opacity(0.22), radius: 16, x: 0, y: 10)
    }
}

struct GlassFill: View {
    var isActive = false

    var body: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        isActive ? Color.vaultAccent.opacity(0.24) : Color.white.opacity(0.08),
                        isActive ? Color.vaultSecondary.opacity(0.1) : Color.vaultCard.opacity(0.94),
                        Color.vaultSurface.opacity(0.92)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(isActive ? Color.vaultAccent.opacity(0.55) : Color.white.opacity(0.1), lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(LinearGradient(colors: [.white.opacity(0.24), .clear], startPoint: .topLeading, endPoint: .center), lineWidth: 1)
                    .blendMode(.screen)
            }
    }
}

struct VaultBackground: View {
    var body: some View {
        ZStack {
            Color.vaultBackground.ignoresSafeArea(.container)

            LinearGradient(
                colors: [
                    Color.vaultAccent.opacity(0.16),
                    Color.vaultSecondary.opacity(0.08),
                    Color.vaultWarning.opacity(0.025),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(.container)

            PremiumBackgroundGrid()
                .stroke(Color.white.opacity(0.018), lineWidth: 1)
                .ignoresSafeArea(.container)

            RadialGradient(colors: [.vaultAccent.opacity(0.18), .clear], center: .topTrailing, startRadius: 20, endRadius: 420)
                .ignoresSafeArea(.container)
                .opacity(0.7)

            RadialGradient(colors: [.vaultSecondary.opacity(0.12), .clear], center: .bottomLeading, startRadius: 30, endRadius: 360)
                .ignoresSafeArea(.container)
                .opacity(0.55)
        }
    }
}

struct PremiumBackgroundGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for x in stride(from: rect.minX, through: rect.maxX, by: 42) {
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x - rect.width * 0.24, y: rect.maxY))
        }
        for y in stride(from: rect.minY, through: rect.maxY, by: 42) {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y + rect.height * 0.08))
        }
        return path
    }
}

struct LogoMark: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient.vaultAccent)
            Circle()
                .stroke(Color.white.opacity(0.35), lineWidth: size * 0.035)
                .padding(size * 0.14)
            Image(systemName: "location.fill")
                .font(.system(size: size * 0.45, weight: .black))
                .foregroundColor(.vaultBackground)
        }
        .frame(width: size, height: size)
        .shadow(color: .vaultAccent.opacity(0.32), radius: size * 0.22, x: 0, y: size * 0.12)
    }
}

struct VaultPagePadding: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: 680, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

extension View {
    func vaultPagePadding() -> some View { modifier(VaultPagePadding()) }
}
