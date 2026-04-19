import SwiftUI

struct SignUpView: View {
    var onSuccess: () -> Void
    var onSwitchToLogin: () -> Void
    var onBack: () -> Void

    @StateObject private var authManager = AuthManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var isLoading = false

    private var passwordsMatch: Bool {
        !confirmPassword.isEmpty && password == confirmPassword
    }

    private var formValid: Bool {
        !email.isEmpty && password.count >= 6 && passwordsMatch
    }

    var body: some View {
        ZStack {
            KineticColor.bgDark.ignoresSafeArea()

            VStack(spacing: 0) {
                // Back button
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer().frame(height: 40)

                // Logo
                VStack(spacing: 6) {
                    Text("KINETIC")
                        .font(KineticFont.display(28))
                        .kerning(6)
                        .foregroundStyle(.white)
                    Text("CREATE YOUR ACCOUNT")
                        .font(KineticFont.caption(10))
                        .kerning(3)
                        .foregroundStyle(KineticColor.textSecondary)
                }

                Spacer().frame(height: 48)

                // Form fields
                VStack(spacing: 16) {
                    AuthTextField(
                        placeholder: "Email",
                        text: $email,
                        icon: "envelope.fill",
                        keyboardType: .emailAddress
                    )

                    AuthSecureField(
                        placeholder: "Password (min 6 chars)",
                        text: $password,
                        icon: "lock.fill"
                    )

                    AuthSecureField(
                        placeholder: "Confirm Password",
                        text: $confirmPassword,
                        icon: "lock.fill"
                    )

                    // Password match indicator
                    if !confirmPassword.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(passwordsMatch ? KineticColor.success : KineticColor.danger)
                            Text(passwordsMatch ? "Passwords match" : "Passwords don't match")
                                .font(KineticFont.caption(12))
                                .foregroundStyle(passwordsMatch ? KineticColor.success : KineticColor.danger)
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 24)

                // Error
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(KineticFont.caption(12))
                        .foregroundStyle(KineticColor.danger)
                        .padding(.top, 12)
                        .padding(.horizontal, 24)
                }

                Spacer().frame(height: 32)

                // Create account button
                VStack(spacing: 16) {
                    Button {
                        Task { await signUp() }
                    } label: {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView().tint(.white)
                            }
                            Text("Create Account")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!formValid || isLoading)
                    .opacity(!formValid ? 0.5 : 1)

                    // Divider
                    HStack {
                        Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                        Text("OR").font(KineticFont.caption(10)).foregroundStyle(KineticColor.textMuted)
                        Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                    }

                    // Google sign-up
                    Button {
                        Task { await googleSignIn() }
                    } label: {
                        HStack(spacing: 8) {
                            Image("google_logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            Text("Continue with Google")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.horizontal, 24)

                Spacer()

                // Switch to login
                Button(action: onSwitchToLogin) {
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .foregroundStyle(KineticColor.textSecondary)
                        Text("Sign In")
                            .foregroundStyle(KineticColor.orange)
                    }
                    .font(KineticFont.body(14))
                }
                .padding(.bottom, 40)
            }
        }
    }

    private func signUp() async {
        isLoading = true
        errorMessage = ""
        do {
            try await authManager.signUp(email: email, password: password)
            onSuccess()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func googleSignIn() async {
        isLoading = true
        errorMessage = ""
        do {
            try await authManager.signInWithGoogle()
            onSuccess()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
