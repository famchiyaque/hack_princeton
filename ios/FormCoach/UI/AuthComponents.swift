import SwiftUI

struct AuthTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String = ""
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 12) {
            if !icon.isEmpty {
                Image(systemName: icon)
                    .foregroundStyle(KineticColor.textMuted)
                    .frame(width: 20)
            }
            TextField(placeholder, text: $text)
                .font(KineticFont.body(15))
                .foregroundStyle(.white)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(16)
        .background(KineticColor.bgCard, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct AuthSecureField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String = ""

    var body: some View {
        HStack(spacing: 12) {
            if !icon.isEmpty {
                Image(systemName: icon)
                    .foregroundStyle(KineticColor.textMuted)
                    .frame(width: 20)
            }
            SecureField(placeholder, text: $text)
                .font(KineticFont.body(15))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
        }
        .padding(16)
        .background(KineticColor.bgCard, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
