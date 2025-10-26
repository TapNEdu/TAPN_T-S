import SwiftUI

@main
struct TAPN_TeachersApp: App {
    @StateObject private var app = AppState(api: MockAPIClient())  // swap to RemoteAPIClient later
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .preferredColorScheme(.light)
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
            switch app.role {
            case .none:    RoleSelectionView()
            case .teacher: TeacherHomeView()
            case .student: StudentHomeView()
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
