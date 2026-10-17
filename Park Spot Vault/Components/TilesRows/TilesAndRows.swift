import SwiftUI

struct MetricTile: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 21, weight: .bold))
                    .foregroundColor(color)
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.vaultMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ActionTile: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: icon)
                        .font(.system(size: 25, weight: .bold))
                        .foregroundColor(color)
                    Text(title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}

struct SelectableTile: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(selected ? .vaultBackground : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 98)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(selected ? AnyShapeStyle(LinearGradient.vaultAccent) : AnyShapeStyle(Color.vaultCard.opacity(0.82)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(selected ? Color.vaultAccent.opacity(0.8) : Color.white.opacity(0.1), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct SearchField: View {
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.vaultMuted)
            TextField("Place, floor, zone or note", text: $text)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .focused($focused)
                .submitLabel(.search)
                .onSubmit { focused = false }
            if !text.isEmpty {
                Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(.vaultMuted) }
                    .accessibilityLabel("Clear search")
                    .frame(width: 32, height: 44)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 58)
        .background(GlassFill())
    }
}

struct CompactParkingCard: View {
    let session: ParkingSession

    var body: some View {
        HStack(spacing: 14) {
            ParkingThumbnail(session: session)
                .frame(width: 78, height: 78)
            VStack(alignment: .leading, spacing: 5) {
                Text(session.title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(session.note.isEmpty ? session.spotDescription : session.note)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.vaultMuted)
                    .lineLimit(1)
                Text(formattedDate(session.parkedAt))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.vaultAccent)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.vaultMuted)
        }
        .padding(14)
        .background(GlassFill())
    }
}

struct HistoryCard: View {
    let session: ParkingSession

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                ParkingThumbnail(session: session)
                    .frame(height: 168)
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(session.title)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("\(formattedDate(session.parkedAt)) at \(formattedTime(session.parkedAt))")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.vaultAccent)
                        Text(session.spotDescription + (session.note.isEmpty ? "" : " · " + session.note))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.vaultMuted)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.vaultMuted)
                }
            }
        }
    }
}

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let message: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        GlassCard {
            VStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(LinearGradient.vaultAccent)
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(message)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.vaultMuted)
                    .multilineTextAlignment(.center)
                LiquidMiniButton(title: buttonTitle, icon: "plus", action: action)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }
}

struct SettingsSegment: View {
    let title: String
    let icon: String
    @Binding var value: String
    let options: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
            Picker(title, selection: $value) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

struct ToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.vaultAccent)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Color.vaultAccent.opacity(0.12)))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.vaultMuted)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.vaultSecondary)
        }
    }
}

struct PermissionRow: View {
    let title: String
    let status: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(color)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(color.opacity(0.12)))
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text(status)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.vaultBackground)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(color))
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.vaultMuted)
            }
        }
        .buttonStyle(.plain)
    }
}

struct AboutRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.vaultMuted)
        }
    }
}

struct ReviewRow: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.vaultAccent)
            Text(value)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
