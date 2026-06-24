import SwiftUI

/// Acme Bank logo badge: a navy hexagon with a bold white "A" centred inside.
struct HexLogoView: View {
    var body: some View {
        ZStack {
            HexagonShape()
                .fill(Color.acmeNavy)

            Text("A")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 72, height: 72)
    }
}

#Preview {
    HexLogoView()
        .padding()
}
