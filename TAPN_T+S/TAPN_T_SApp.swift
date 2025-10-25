import SwiftUI
import GoogleSignIn

@main
struct TAPN_TeachersApp: App {
    @StateObject private var app = AppState(api: SupabaseAPIClient())

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}

private struct RootView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        Group {
            if !app.isAuthenticated {
                // Not signed in - show sign-in view
                SignInView()
            } else if app.userProfile?.role == nil || app.userProfile?.role == .none {
                // Signed in but no role set - show role setup
                RoleSetupView()
            } else {
                // Signed in with role - show appropriate view
                switch app.role {
                case .teacher:
                    TeacherHomeView()
                case .student:
                    StudentHomeView()
                case .none:
                    RoleSetupView()
                }
            }
        }
    }
}
