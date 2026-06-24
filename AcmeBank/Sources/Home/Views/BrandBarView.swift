import SwiftUI

/// Top-of-screen brand bar showing the Acme Bank hexagonal logo and
/// wordmark. Rendered as a white/system-background strip with a
/// `Divider` below to separate it from scrollable content.
struct BrandBarView: View {

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                // Hexagonal "A" logo: SF Symbol `hexagon.fill` in
                // brand navy with a white "A" overlaid.
                ZStack {
                    Image(systemName: "hexagon.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.acmeBrandNavy)
                    Text("A")
                        .font(.headline)
                        .bold()
                        .foregroundColor(.white)
                }

                Text("Acme Bank")
                    .font(.title3)
                    .bold()
                    .foregroundColor(.acmeBrandNavy)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))

            Divider()
        }
    }
}

#Preview {
    BrandBarView()
}
