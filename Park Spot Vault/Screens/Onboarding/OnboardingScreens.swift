import SwiftUI

enum ParkingGuide {
    static let version = 1
    static let versionKey = "parkSpotVault.completedGuideVersion"
}

struct OnboardingScreen: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    private let onClose: (() -> Void)?
    private let onContinue: () -> Void
    private let pages = ParkingGuidePage.all

    init(onClose: (() -> Void)? = nil, onContinue: @escaping () -> Void) {
        self.onClose = onClose
        self.onContinue = onContinue
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("YOUR PARKING BUDDY")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.4)
                        .foregroundColor(.vaultSecondary)
                    Text("A little help for every stop")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.vaultMuted)
                }
                Spacer(minLength: 8)
                if let onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .accessibilityLabel("Close parking guide")
                }
            }
            .frame(maxWidth: 640)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    ParkingGuidePageView(page: pages[index])
                        .tag(index)
                        .padding(.horizontal, 20)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 16) {
                HStack(spacing: 7) {
                    ForEach(pages.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? Color.vaultSecondary : Color.white.opacity(0.16))
                            .frame(width: index == page ? 24 : 7, height: 6)
                    }
                    Spacer()
                    Text("\(page + 1) of \(pages.count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.vaultMuted)
                        .monospacedDigit()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Guide page \(page + 1) of \(pages.count)")

                HStack(spacing: 12) {
                    if page > 0 {
                        Button { move(to: page - 1) } label: {
                            Image(systemName: "arrow.left")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(width: 52, height: 54)
                                .background(Circle().fill(Color.white.opacity(0.08)))
                        }
                        .accessibilityLabel("Previous guide page")
                    }
                    LiquidButton(title: page == pages.count - 1 ? "Open my vault" : "Next", icon: "arrow.right") {
                        if page == pages.count - 1 { onContinue() }
                        else { move(to: page + 1) }
                    }
                }
            }
            .frame(maxWidth: 640)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
        }
        .background { VaultBackground() }
        .preferredColorScheme(.dark)
        .tint(.vaultAccent)
    }

    private func move(to index: Int) {
        if reduceMotion { page = index }
        else {
            withAnimation(.easeInOut(duration: 0.3)) { page = index }
        }
    }
}

private struct ParkingGuidePage {
    let title: String
    let message: String
    let artwork: ParkingArtwork.Kind
    let instructions: [ParkingGuideInstruction]

    static let all: [ParkingGuidePage] = [
        ParkingGuidePage(
            title: "Hi! I'm your parking buddy.",
            message: "I'll help you remember your spot and find the way back. Let me show you around!",
            artwork: .drive,
            instructions: [
                ParkingGuideInstruction(icon: "plus.circle.fill", title: "Save a stop", detail: "Keep a location, photo and parking details together."),
                ParkingGuideInstruction(icon: "location.fill", title: "Find your car", detail: "Return with your saved map, photo and landmarks."),
                ParkingGuideInstruction(icon: "clock.arrow.circlepath", title: "Keep the memories", detail: "Past stops stay in History after you finish parking.")
            ]
        ),
        ParkingGuidePage(
            title: "First, save your spot.",
            message: "Just parked? Tap the + on Home. I'll help you capture a couple of useful clues.",
            artwork: .capture,
            instructions: [
                ParkingGuideInstruction(icon: "location.circle.fill", title: "Use current location", detail: "Save a GPS point when a signal is available. You can refresh it before saving."),
                ParkingGuideInstruction(icon: "camera.fill", title: "Take or choose a photo", detail: "Use Camera or Photos to capture your car and a nearby sign."),
                ParkingGuideInstruction(icon: "arrow.right.circle.fill", title: "Tap Continue", detail: "Photo and location access are optional. You can use written details instead.")
            ]
        ),
        ParkingGuidePage(
            title: "Give me a few clues.",
            message: "A floor, a space number or a colorful pillar can make a big difference in a busy garage.",
            artwork: .capture,
            instructions: [
                ParkingGuideInstruction(icon: "square.stack.fill", title: "Floor and zone", detail: "Choose a floor or type your own, then add a zone or space number."),
                ParkingGuideInstruction(icon: "note.text", title: "Notes and landmarks", detail: "Write down an entrance or lift. Separate several landmarks with commas."),
                ParkingGuideInstruction(icon: "bell.fill", title: "Review and save", detail: "Choose a reminder if you want one, check your details, then tap Save parking.")
            ]
        ),
        ParkingGuidePage(
            title: "Let's find your car.",
            message: "Ready to head back? Tap Find my car on Home. Your saved clues are waiting there.",
            artwork: .returning,
            instructions: [
                ParkingGuideInstruction(icon: "map.fill", title: "Map and walking directions", detail: "With a saved GPS point, open Walking directions to continue in Apple Maps."),
                ParkingGuideInstruction(icon: "safari.fill", title: "Compass and timer", detail: "Compass uses location and a device compass. Timer shows how long you've parked."),
                ParkingGuideInstruction(icon: "mappin.and.ellipse", title: "No GPS? Open Places", detail: "Your parking photo, floor, notes and landmarks still help you find the spot.")
            ]
        ),
        ParkingGuidePage(
            title: "I'll be here next time.",
            message: "Found your car? Finish the parking session. Your saved details stay in History for later.",
            artwork: .permissions,
            instructions: [
                ParkingGuideInstruction(icon: "checkmark.flag.fill", title: "Finish parking on Home", detail: "Tap the flag beside Find my car. This ends the active session and cancels its reminder."),
                ParkingGuideInstruction(icon: "magnifyingglass", title: "Search your history", detail: "Find a past stop by place, floor, zone or note. Tap a card to open its details."),
                ParkingGuideInstruction(icon: "questionmark.circle.fill", title: "Need me again?", detail: "Open the buddy card on Home or Parking guide in Settings to replay this tour.")
            ]
        )
    ]
}

private struct ParkingGuideInstruction {
    let icon: String
    let title: String
    let detail: String
}

private struct ParkingGuidePageView: View {
    let page: ParkingGuidePage

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    ParkingArtwork(page.artwork)
                        .frame(width: max(1, min(proxy.size.width, proxy.size.height * 0.44, 300)))
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(page.title)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        VStack(alignment: .leading, spacing: 7) {
                            Label("BUDDY'S TIP", systemImage: "bubble.left.fill")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1)
                                .foregroundColor(.vaultSecondary)
                            Text(page.message)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(GlassFill(isActive: true))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(page.instructions.indices, id: \.self) { index in
                            instruction(page.instructions[index])
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(GlassFill())
                }
                .frame(maxWidth: 640)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func instruction(_ item: ParkingGuideInstruction) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.vaultSecondary)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text(item.detail)
                    .font(.system(size: 14))
                    .foregroundColor(.vaultMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
