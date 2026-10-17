import SwiftUI

struct LoadingScreen: View {
    var body: some View {
        GeometryReader { proxy in
            let width = max(1, min(proxy.size.width - 40, (proxy.size.height - 140) / 1.5, 410))

            VStack(spacing: 22) {
                RoadLoadingScene()
                    .frame(width: width, height: width * 1.5)

                VStack(spacing: 8) {
                    Text("Park Spot Vault")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Getting your vault ready…")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.vaultMuted)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}
