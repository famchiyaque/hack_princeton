import Foundation
import Supabase

/// Manages Supabase authentication state.
///
/// How auth works at a high level:
/// 1. User signs up or signs in → Supabase returns a Session containing
///    an access token (JWT) and the user's UUID + email.
/// 2. The supabase-swift SDK auto-persists this session in the iOS Keychain,
///    so on next app launch we can restore it without re-logging in.
/// 3. The access token is short-lived (~1hr). The SDK auto-refreshes it
///    using a long-lived refresh token — you don't need to handle this.
/// 4. We attach the access token to every API request (see APIClient).
///    The backend verifies it using the shared JWT secret.
@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    let client = SupabaseClient(
        supabaseURL: URL(string: "https://itqrhuwxuibxnjxlboxg.supabase.co")!,
        supabaseKey: "sb_publishable_9LXcxvRS4uCH4rLIxXNSUg_qr-NqnIX"
    )

    @Published var session: Session?
    @Published var isLoading = true

    var isAuthenticated: Bool { session != nil }
    var accessToken: String? { session?.accessToken }
    var userId: String? { session?.user.id.uuidString }
    var userEmail: String? { session?.user.email }

    private init() {
        Task { await restoreSession() }
    }

    func restoreSession() async {
        do {
            session = try await client.auth.session
        } catch {
            session = nil
        }
        isLoading = false
    }

    func signUp(email: String, password: String) async throws {
        let result = try await client.auth.signUp(email: email, password: password)
        session = result.session
    }

    func signIn(email: String, password: String) async throws {
        session = try await client.auth.signIn(email: email, password: password)
    }

    func signInWithGoogle() async throws {
        session = try await client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: URL(string: "\(Bundle.main.bundleIdentifier ?? "com.formcoach.app")://login-callback")
        )
    }

    func signOut() async throws {
        try await client.auth.signOut()
        session = nil
    }
}
