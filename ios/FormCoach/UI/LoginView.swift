import SwiftUI

struct LoginView: View {
    var onSuccess: () -> Void
    var onSwitchToSignUp: () -> Void
    var onBack: () -> Void

    @StateObject private var authManager = AuthManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isLoading = false

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
                    Text("WELCOME BACK")
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
                        placeholder: "Password",
                        text: $password,
                        icon: "lock.fill"
                    )
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

                // Sign in button
                VStack(spacing: 16) {
                    Button {
                        Task { await signIn() }
                    } label: {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView().tint(.white)
                            }
                            Text("Sign In")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(email.isEmpty || password.isEmpty || isLoading)
                    .opacity(email.isEmpty || password.isEmpty ? 0.5 : 1)

                    // Divider
                    HStack {
                        Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                        Text("OR").font(KineticFont.caption(10)).foregroundStyle(KineticColor.textMuted)
                        Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                    }

                    // Google sign-in
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

                // Switch to sign up
                Button(action: onSwitchToSignUp) {
                    HStack(spacing: 4) {
                        Text("Don't have an account?")
                            .foregroundStyle(KineticColor.textSecondary)
                        Text("Sign Up")
                            .foregroundStyle(KineticColor.orange)
                    }
                    .font(KineticFont.body(14))
                }
                .padding(.bottom, 40)
            }
        }
    }

    private func signIn() async {
        isLoading = true
        errorMessage = ""
        do {
            try await authManager.signIn(email: email, password: password)
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
