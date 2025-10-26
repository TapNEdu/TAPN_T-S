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
                .onAppear {
                    // Configure navigation bar appearance
                    configureNavigationBar()

                    // Request Family Controls authorization on app launch
                    Task {
                        await AppBlockingManager.shared.requestAuthorization()
                    }
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

// MARK: - Navigation Bar Configuration
private func configureNavigationBar() {
    let appearance = UINavigationBarAppearance()
    appearance.configureWithOpaqueBackground()
    
    // Set background color to cream
    appearance.backgroundColor = UIColor(red: 250/255, green: 248/255, blue: 242/255, alpha: 1.0)
    
    // Set title text color to dark sage
    appearance.titleTextAttributes = [
        .foregroundColor: UIColor(red: 45/255, green: 55/255, blue: 50/255, alpha: 1.0)
    ]
    
    // Set back button color to much darker for better visibility
    appearance.backButtonAppearance.normal.titleTextAttributes = [
        .foregroundColor: UIColor(red: 45/255, green: 55/255, blue: 50/255, alpha: 1.0)
    ]
    
    // Apply to navigation bar
    UINavigationBar.appearance().standardAppearance = appearance
    UINavigationBar.appearance().scrollEdgeAppearance = appearance
    UINavigationBar.appearance().compactAppearance = appearance
    
    // Set tint color for back buttons and other controls to much darker
    UINavigationBar.appearance().tintColor = UIColor(red: 45/255, green: 55/255, blue: 50/255, alpha: 1.0)
}
