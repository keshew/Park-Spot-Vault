import SwiftUI

struct ParkingBuddyGuideCard: View {
    let onOpen: () -> Void
    var title = "Your parking buddy"

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                ParkingArtwork(.permissions)
                    .frame(width: 84, height: 90)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("I'll show you around. Open the guide.")
                        .font(.system(size: 13))
                        .foregroundColor(.vaultMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.vaultSecondary)
            }
            .padding(.leading, 4)
            .padding(.trailing, 16)
            .padding(.vertical, 6)
            .background(GlassFill())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Your parking buddy. Open the app guide.")
    }
}

struct ParkingBuddyTip: View {
    let artwork: ParkingArtwork.Kind
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ParkingArtwork(artwork)
                .frame(width: 78, height: 90)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.vaultSecondary)
                Text(message)
                    .font(.system(size: 13))
                    .foregroundColor(.vaultMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(GlassFill())
        .accessibilityElement(children: .combine)
    }
}
