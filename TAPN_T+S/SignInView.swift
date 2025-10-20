import SwiftUI
import GoogleSignInSwift

struct SignInView: View {
    @EnvironmentObject var app: AppState
    @StateObject private var authManager = GoogleAuthManager.shared
    @State private var showError = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App branding
            VStack(spacing: 16) {
                Text("TAPN")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.blue)

                Text("Classroom Attendance Tracker")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Sign in section
            VStack(spacing: 20) {
                Text("Sign in to continue")
                    .font(.title3)
                    .fontWeight(.medium)

                // Google Sign-In Button
                GoogleSignInButton(action: signIn)
                    .frame(width: 280, height: 50)
                    .disabled(authManager.isSigningIn)
                    .opacity(authManager.isSigningIn ? 0.6 : 1.0)

                if authManager.isSigningIn {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                }

                if let errorMessage = authManager.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }

            Spacer()

            // Footer
            Text("Sign in with your Google account to access the app")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
        }
        .padding()
    }

    private func signIn() {
        Task {
            do {
                try await authManager.signIn()
                // After sign-in, load the user profile
                await app.loadUserProfile()
            } catch {
                authManager.errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    SignInView()
        .environmentObject(AppState(api: MockAPIClient()))
}
