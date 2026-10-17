import SwiftUI
import UIKit

struct ParkingArtwork: View {
    enum Kind: String {
        case drive = "ParkingDrive"
        case capture = "ParkingCapture"
        case returning = "ParkingReturn"
        case permissions = "ParkingPermissions"
        case garage = "ParkingGarage"
    }

    let kind: Kind

    init(_ kind: Kind) {
        self.kind = kind
    }

    var body: some View {
        Image(kind.rawValue)
            .resizable()
            .scaledToFit()
            .mask {
                // Soften the artwork's dark edges into any surrounding surface.
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.07),
                        .init(color: .black, location: 0.91),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.06),
                            .init(color: .black, location: 0.94),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
            }
            .accessibilityHidden(true)
    }
}

struct PremiumEmptyIllustration: View {
    var body: some View {
        ParkingArtwork(.drive)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PremiumParkingScene: View {
    let colors: [Color]
    var image: UIImage? = nil

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)

                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                    } else {
                        Image(ParkingArtwork.Kind.garage.rawValue)
                            .resizable()
                    }
                }
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.65)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                Label(image == nil ? "Parking illustration" : "Parking photo", systemImage: image == nil ? "sparkles" : "camera.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(16)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

struct ParkingThumbnail: View {
    let session: ParkingSession

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let image = ImageStore.load(session.photoFilename) {
                        Image(uiImage: image)
                            .resizable()
                    } else {
                        Image(ParkingArtwork.Kind.garage.rawValue)
                            .resizable()
                    }
                }
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .overlay(Color.black.opacity(0.18))

                HStack(spacing: 5) {
                    Text(session.floor)
                    Text(session.zone)
                }
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(.vaultBackground)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.vaultSecondary))
                .padding(10)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

struct CheckmarkBadge: View {
    let color: Color

    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 58, weight: .black))
            .foregroundColor(.vaultBackground)
            .frame(width: 126, height: 126)
            .background(Circle().fill(color))
            .shadow(color: color.opacity(0.34), radius: 22, x: 0, y: 12)
    }
}
