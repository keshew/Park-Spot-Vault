import SwiftUI

struct AccuracyDial: View {
    let value: Double
    let title: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 9)
            Circle()
                .trim(from: 0, to: value)
                .stroke(LinearGradient.vaultAccent, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(title)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("Q")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.vaultMuted)
            }
        }
    }
}

struct SignalLineChart: View {
    let values: [Double]

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let points = values.enumerated().map { index, value in
                CGPoint(
                    x: width * CGFloat(index) / CGFloat(max(values.count - 1, 1)),
                    y: height - (height * 0.78 * CGFloat(value)) - 12
                )
            }

            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.16))

                ChartGrid()
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: CGPoint(x: first.x, y: height))
                    for point in points {
                        path.addLine(to: point)
                    }
                    if let last = points.last {
                        path.addLine(to: CGPoint(x: last.x, y: height))
                    }
                    path.closeSubpath()
                }
                .fill(LinearGradient(colors: [.vaultAccent.opacity(0.26), .vaultSecondary.opacity(0.08), .clear], startPoint: .top, endPoint: .bottom))

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(LinearGradient.vaultAccent, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))

                ForEach(points.indices, id: \.self) { index in
                    Circle()
                        .fill(index == points.indices.last ? Color.vaultSecondary : Color.white.opacity(0.75))
                        .frame(width: index == points.indices.last ? 10 : 5, height: index == points.indices.last ? 10 : 5)
                        .position(points[index])
                }
            }
        }
    }
}

struct ChartGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for index in 1...3 {
            let y = rect.height * CGFloat(index) / 4
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        for index in 1...5 {
            let x = rect.width * CGFloat(index) / 6
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }
        return path
    }
}
