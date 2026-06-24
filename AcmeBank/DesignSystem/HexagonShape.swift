import SwiftUI

/// A regular hexagon `Shape` centred in its bounding rectangle.
/// Used by `HexLogoView` for the Acme "A" badge.
struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cx = rect.midX
        let cy = rect.midY
        let r = min(rect.width, rect.height) / 2

        var path = Path()

        for i in 0..<6 {
            // Flat-top orientation: first vertex at 0° (right of centre)
            let angleDeg = Double(i) * 60.0 - 30.0
            let angleRad = angleDeg * .pi / 180.0
            let x = cx + r * CGFloat(cos(angleRad))
            let y = cy + r * CGFloat(sin(angleRad))

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        path.closeSubpath()
        return path
    }
}

#Preview {
    HexagonShape()
        .fill(Color.acmeNavy)
        .frame(width: 72, height: 72)
}
