import SwiftUI

struct RoadLoadingScene: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var startedAt = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || scenePhase != .active)) { context in
            RoadLoadingComposition(
                elapsed: context.date.timeIntervalSince(startedAt),
                reduceMotion: reduceMotion
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading your parking vault")
        .allowsHitTesting(false)
    }
}

struct RoadLoadingComposition: View {
    let elapsed: TimeInterval
    var reduceMotion = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                Image("LoadingRoad")
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()

                // The artwork's vanishing point is at (0.5, 0.22).
                // Increasing depth moves objects toward the viewer on that road plane.
                ForEach(0..<4) { index in
                    let depth = CGFloat(0.24 + Double(index) * 0.19)
                    let lane: CGFloat = index.isMultiple(of: 2) ? -1 : 1
                    let width = size.width * (0.03 + depth * 0.18)

                    Image("LoadingManhole")
                        .resizable()
                        .scaledToFit()
                        .frame(width: width)
                        .scaleEffect(reduceMotion ? 1 : 0.85 + 0.15 * manholeOpacity(index))
                        .opacity(reduceMotion ? 1 : manholeOpacity(index))
                        .position(
                            x: size.width * (0.5 + lane * (0.02 + depth * 0.27)),
                            y: size.height * (0.24 + depth * 0.62)
                        )
                }

                ForEach(0..<2) { index in
                    let depth = carDepth(index)
                    let visibleDepth = min(depth, 1)
                    let lane: CGFloat = index == 0 ? -1 : 1
                    let width = size.width * 0.655 * visibleDepth
                    let height = width * 0.75
                    let roadY = size.height * (0.22 + depth * 0.64)

                    ZStack(alignment: .bottom) {
                        Ellipse()
                            .fill(Color.black.opacity(0.45))
                            .frame(width: width * 0.65, height: height * 0.1)
                            .blur(radius: width * 0.025)
                            .offset(y: -height * 0.04)

                        Image("LoadingCarRear")
                            .resizable()
                            .scaledToFit()
                    }
                    .frame(width: width, height: height)
                    .position(
                        x: size.width * (0.5 + lane * visibleDepth * 0.29),
                        y: roadY - height * 0.4
                            + (reduceMotion ? 0 : sin(elapsed * 4 + Double(index)) * Double(visibleDepth) * 0.5)
                    )
                }

                LinearGradient(
                    colors: [.black.opacity(0.08), .clear, .vaultBackground.opacity(0.3)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .clipped()
    }

    private func carDepth(_ index: Int) -> CGFloat {
        guard !reduceMotion else { return index == 0 ? 0.75 : 0.35 }
        let drivingTime = max(0, elapsed - Double(index) * 1.3)
        let progress = (drivingTime / 10).truncatingRemainder(dividingBy: 1)
        // Start completely below the clipped road and shrink to the vanishing point.
        return CGFloat(1.85 * pow(1 - progress, 1.5))
    }

    private func manholeOpacity(_ index: Int) -> Double {
        return min(1, max(0, (elapsed - Double(index) * 0.22) / 0.2))
    }
}

#Preview("Road loading") {
    LoadingScreen()
        .background(Color.vaultBackground)
        .preferredColorScheme(.dark)
}
