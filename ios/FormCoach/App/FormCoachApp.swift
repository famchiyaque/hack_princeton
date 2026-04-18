import SwiftUI

@main
struct FormCoachApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    // Handles the OAuth callback when Google sign-in redirects
                    // back to the app via the custom URL scheme.
                    Task {
                        try? await AuthManager.shared.client.auth.session(from: url)
                    }
                }
        }
    }
}
