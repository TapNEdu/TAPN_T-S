import SwiftUI

@main
struct TAPN_TeachersApp: App {
    @StateObject private var app = AppState(api: MockAPIClient())  // swap to RemoteAPIClient later
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .preferredColorScheme(.light)
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
