import SwiftUI

/// Username input field with a label, email keyboard, and rounded border.
struct UsernameFieldView: View {
    @Binding var username: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Username")
                .font(.subheadline)
                .foregroundStyle(Color(.label))

            TextField("name@acmebank.com", text: $username)
                .keyboardType(.emailAddress)
                .textContentType(.username)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityLabel("Username")
                .padding(.horizontal, 12)
                .frame(height: 50)
                .background(Color.fieldBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.fieldBorder, lineWidth: 1)
                )
        }
    }
}

#Preview {
    UsernameFieldView(username: .constant(""))
        .padding()
}
