import SwiftUI

/// Password input field with a label, show/hide toggle, and rounded border.
struct PasswordFieldView: View {
    @Binding var password: String
    @State private var isPasswordVisible: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Password")
                .font(.subheadline)
                .foregroundStyle(Color(.label))

            HStack {
                if isPasswordVisible {
                    TextField("Password", text: $password)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .accessibilityLabel("Password")
                } else {
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .accessibilityLabel("Password")
                }

                Button {
                    isPasswordVisible.toggle()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                        .foregroundStyle(Color(.secondaryLabel))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password")
            }
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
    PasswordFieldView(password: .constant(""))
        .padding()
}
