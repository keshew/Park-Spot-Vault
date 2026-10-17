import SwiftUI
import MapKit

struct ParkingMapView: View {
    let session: ParkingSession
    @State private var region: MKCoordinateRegion

    init(session: ParkingSession) {
        self.session = session
        _region = State(initialValue: MKCoordinateRegion(
            center: session.mapCoordinate ?? CLLocationCoordinate2D(),
            span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004)
        ))
    }

    var body: some View {
        Group {
            if let coordinate = session.mapCoordinate {
                Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: [SavedMapPin(id: session.id, coordinate: coordinate)]) { pin in
                    MapAnnotation(coordinate: pin.coordinate) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.vaultBackground)
                            .padding(12)
                            .background(Circle().fill(Color.vaultSecondary))
                            .overlay(Circle().stroke(Color.white, lineWidth: 3))
                            .shadow(radius: 5)
                            .accessibilityLabel("Saved car location")
                    }
                }
                .overlay(alignment: .topTrailing) {
                    Button {
                        withAnimation { region.center = coordinate }
                    } label: {
                        Image(systemName: "scope")
                            .font(.system(size: 18, weight: .bold))
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Center on parking spot")
                    .padding(12)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "location.slash")
                        .font(.system(size: 32))
                        .foregroundColor(.vaultAccent)
                    Text("No GPS location saved")
                        .font(.headline)
                    Text("Use your photo, floor and notes to find this spot.")
                        .font(.subheadline)
                        .foregroundColor(.vaultMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.vaultCard)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct SavedMapPin: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
}

func openParkingDirections(_ session: ParkingSession) {
    guard let coordinate = session.mapCoordinate else { return }
    let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
    item.name = session.title
    item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
}

struct CompassDial: View {
    let direction: Double

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle().fill(Color.vaultCard)
                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                ForEach(0..<60) { tick in
                    Capsule()
                        .fill(Color.white.opacity(tick.isMultiple(of: 5) ? 0.6 : 0.18))
                        .frame(width: 2, height: tick.isMultiple(of: 5) ? 14 : 6)
                        .offset(y: -size / 2 + 16)
                        .rotationEffect(.degrees(Double(tick) * 6))
                }
                ForEach(0..<4) { index in
                    Text(["N", "E", "S", "W"][index])
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(index == 0 ? .vaultSecondary : .vaultMuted)
                        .position(
                            x: size / 2 + sin(Double(index) * .pi / 2) * (size / 2 - 42),
                            y: size / 2 - cos(Double(index) * .pi / 2) * (size / 2 - 42)
                        )
                }
                Image(systemName: "location.north.fill")
                    .font(.system(size: size * 0.28, weight: .bold))
                    .foregroundStyle(LinearGradient.vaultAccent)
                    .rotationEffect(.degrees(direction))
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("Direction to your car")
    }
}
