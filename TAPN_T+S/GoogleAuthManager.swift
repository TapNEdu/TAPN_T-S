import Foundation
import GoogleSignIn
import Supabase
import UIKit

@MainActor
class GoogleAuthManager: ObservableObject {
    static let shared = GoogleAuthManager()

    @Published var isSigningIn = false
    @Published var errorMessage: String?

    private init() {}

    func signIn() async throws {
        isSigningIn = true
        errorMessage = nil

        defer { isSigningIn = false }

        // Get the root view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw AuthError.noViewController
        }

        // Perform Google Sign-In
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

        // Get the ID token
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.noIdToken
        }

        // Sign in to Supabase with Google ID token
        try await supabase.auth.signInWithIdToken(
            credentials: .init(
                provider: .google,
                idToken: idToken
            )
        )
    }

    func signOut() async throws {
        // Sign out from Google
        GIDSignIn.sharedInstance.signOut()

        // Sign out from Supabase
        try await supabase.auth.signOut()
    }

    func restorePreviousSignIn() async throws {
        // Restore Google Sign-In session if available
        if GIDSignIn.sharedInstance.hasPreviousSignIn() {
            try await GIDSignIn.sharedInstance.restorePreviousSignIn()
        }
    }
}

enum AuthError: LocalizedError {
    case noViewController
    case noIdToken

    var errorDescription: String? {
        switch self {
        case .noViewController:
            return "Unable to find view controller for sign-in"
        case .noIdToken:
            return "Failed to get ID token from Google"
        }
    }
}
