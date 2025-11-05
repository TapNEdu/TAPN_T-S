import Foundation
import SwiftUI
import Combine
import CoreNFC
import Supabase

enum AppStateError: LocalizedError {
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in with your school email to record attendance"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState(api: TAPNAPI_Local())
    
    let api: TAPNAPI

    private var pollEvery: TimeInterval?
    private var poller: AnyCancellable?
    private var authStateListener: Task<Void, Never>?

    @Published var isAuthenticated: Bool = false
    @Published var isLoadingProfile: Bool = false
    @Published var currentUser: User?
    @Published var userProfile: UserProfile?

    @Published var role: UserRole = .none
    @Published var teacherName: String = ""
    @Published var studentName: String = "You"

    @Published var classes: [ClassSession] = []
    @Published var activeClassID: UUID? = nil

    // Global store for LegacyClass instances
    @Published var legacyClasses: [LegacyClass] = []

    private var ticker: AnyCancellable?

    init(api: TAPNAPI, pollingInterval: TimeInterval? = nil) {
        print("📚 AppState: INIT CALLED - Creating new AppState instance")
        self.api = api
        self.pollEvery = pollingInterval

        Task {
            await checkAuthSession()
            await bootstrap()
            setupAuthStateListener()
        }
    }

    private func checkAuthSession() async {
        do {
            let session = try await supabase.auth.session
            currentUser = session.user
            isAuthenticated = true
            await loadUserProfile()
        } catch {
            currentUser = nil
            isAuthenticated = false
            userProfile = nil
        }
    }

    func loadUserProfile() async {
        guard let userId = currentUser?.id else {
            userProfile = nil
            role = .none
            isLoadingProfile = false
            return
        }

        isLoadingProfile = true
        do {
            if let apiClient = api as? SupabaseAPIClient {
                userProfile = try await apiClient.getUserProfile(userId: userId)
                role = userProfile?.role ?? .none
            }
        } catch {
            userProfile = nil
            role = .none
        }
        isLoadingProfile = false
    }

    private func setupAuthStateListener() {
        authStateListener = Task {
            for await (event, session) in supabase.auth.authStateChanges {
                await handleAuthStateChange(event, session: session)
            }
        }
    }

    private func handleAuthStateChange(_ event: AuthChangeEvent, session: Session?) async {
        switch event {
        case .signedIn, .tokenRefreshed, .userUpdated:
            if let session = session {
                currentUser = session.user
                isAuthenticated = true
                await loadUserProfile()

                // Reload classes after sign in
                if event == .signedIn {
                    await bootstrap()
                }
            } else {
                currentUser = nil
                isAuthenticated = false
            }
        case .signedOut:
            currentUser = nil
            isAuthenticated = false
            userProfile = nil
            role = .none
        default:
            break
        }
    }

    func createUserProfile(role: UserRole?, name: String) async throws {
        guard let userId = currentUser?.id,
              let email = currentUser?.email else {
            throw AppStateError.notAuthenticated
        }

        if let apiClient = api as? SupabaseAPIClient {
            userProfile = try await apiClient.createUserProfile(
                userId: userId,
                email: email,
                role: role,
                name: name
            )
            self.role = userProfile?.role ?? .none
        }
    }

    func switchRole(to newRole: UserRole) async throws {
        guard let userId = currentUser?.id else {
            throw AppStateError.notAuthenticated
        }

        if let apiClient = api as? SupabaseAPIClient {
            userProfile = try await apiClient.updateUserRole(userId: userId, role: newRole)
            role = newRole
        }
    }

    func signOut() async {
        do {
            try await GoogleAuthManager.shared.signOut()
        } catch {
            // Handle error silently for now
        }
    }

    deinit {
        authStateListener?.cancel()
    }

    func bootstrap() async {
        do {
            let list = try await api.bootstrap()
            classes = list
            print("📚 AppState: Bootstrap loaded \(list.count) classes")
            
            // Also create LegacyClass objects for pre-existing classes
            for classSession in list {
                let legacyClass = LegacyClass(
                    teacher: LegacyTeacher(name: "Teacher", preferedName: "Teacher"),
                    ID: classSession.id.uuidString
                )
                addLegacyClass(legacyClass)
                print("📚 AppState: Created LegacyClass for bootstrap class: \(classSession.subject) with ID: \(classSession.id.uuidString)")
            }
            
            print("📚 AppState: Bootstrap complete - legacyClasses.count: \(legacyClasses.count)")
            for (index, legacyClass) in legacyClasses.enumerated() {
                print("📚 AppState: legacyClasses[\(index)]: \(legacyClass.ID)")
            }
        } catch {
            print("📚 AppState: Bootstrap error: \(error)")
            // ignore for prototype
        }
    }

    var activeClass: ClassSession? {
        guard let id = activeClassID else { return nil }
        return classes.first(where: { $0.id == id })
    }

    func enableAPIPolling(every seconds: TimeInterval = 3.0) {
        pollEvery = seconds
        startPollerIfNeeded()
    }

    func disableAPIPolling() {
        pollEvery = nil
        stopPoller()
    }


    func resetToRoleSelection() { 
        role = .none
        teacherName = ""
        activeClassID = nil  // Clear active class when resetting
    }
    func setRole(_ r: UserRole) { 
        role = r
        if r != .student {
            // Clear student's active class when switching away from student role
            activeClassID = nil
        }
    }
    
    // MARK: - LegacyClass Management
    
    func findClass(byID id: String) -> LegacyClass? {
        print("📚 AppState: findClass called with ID: \(id) - legacyClasses.count: \(legacyClasses.count)")
        return legacyClasses.first { $0.ID == id }
    }
    
    func addLegacyClass(_ class: LegacyClass) {
        legacyClasses.append(`class`)
        print("📚 AppState: Added LegacyClass with ID: \(`class`.ID) - legacyClasses.count now: \(legacyClasses.count)")
    }
    
    func updateLegacyClass(_ class: LegacyClass) {
        if let index = legacyClasses.firstIndex(where: { $0.ID == `class`.ID }) {
            legacyClasses[index] = `class`
            print("📚 AppState: Updated LegacyClass with ID: \(`class`.ID)")
        }
    }

    func addClass(subject: String, timeLabel: String) {
        guard let teacherId = currentUser?.id else {
            print("❌ addClass failed: No teacherId")
            return
        }

        print("🔄 Creating class: \(subject) at \(timeLabel)")
        print("   Teacher ID: \(teacherId)")
        print("   Is authenticated: \(isAuthenticated)")

        Task {
            do {
                guard let apiClient = api as? SupabaseAPIClient else {
                    print("❌ API client is not SupabaseAPIClient")
                    return
                }

                let created = try await apiClient.createClass(subject: subject, timeLabel: timeLabel, teacherId: teacherId)
                print("✅ Class created successfully: \(created.id)")
                classes.insert(created, at: 0)

                // Also create and store the corresponding LegacyClass for app blocking
                let teacherNameToUse = userProfile?.name ?? teacherName
                let legacyClass = LegacyClass(
                    teacher: LegacyTeacher(name: teacherNameToUse, preferedName: teacherNameToUse),
                    ID: created.id.uuidString
                )
                addLegacyClass(legacyClass)
                print("📚 AppState: Created LegacyClass for new class: \(created.subject) with ID: \(created.id.uuidString)")
            } catch {
                print("❌ Failed to create class:")
                print("   Error: \(error)")
                print("   Localized: \(error.localizedDescription)")
            }
        }
    }

    func deleteClass(_ classID: UUID) {
        // Safety check: don't delete active class
        guard activeClassID != classID else {
            print("❌ Cannot delete active class. End the class first.")
            return
        }

        Task {
            do {
                try await api.deleteClass(classID: classID)
                print("✅ Class deleted successfully: \(classID)")

                // Remove from local state
                classes.removeAll { $0.id == classID }

                // Also remove from legacyClasses
                legacyClasses.removeAll { $0.ID == classID.uuidString }
            } catch {
                print("❌ Failed to delete class: \(error.localizedDescription)")
            }
        }
    }

    func setCategories(for classID: UUID, _ categories: Set<AppCategory>) {
        Task {
            if let updated = try? await api.setCategories(classID: classID, categories: categories) {
                replace(updated)
            }
        }
    }

    func setDuration(for classID: UUID, minutes: Int) {
        Task {
            if let updated = try? await api.setDuration(classID: classID, minutes: minutes) {
                replace(updated)
            }
        }
    }

    func setAllowedApps(for classID: UUID, allowed: Set<AllowedApp>) {
        Task {
            if let updated = try? await api.setAllowedApps(classID: classID, allowed: allowed) {
                replace(updated)
            }
        }
    }

    func startClass(_ classID: UUID) {
        Task {
            do {
                // End current class if there is one
                if let current = activeClassID, current != classID {
                    do {
                        let endedClass = try await api.endClass(classID: current)
                        replace(endedClass)
                        print("✅ Previous class ended: \(current)")
                    } catch {
                        print("⚠️ Failed to end previous class: \(error.localizedDescription)")
                    }
                }

                // Start the new class
                let updated = try await api.startClass(classID: classID)
                print("✅ Class started successfully: \(classID)")
                replace(updated)
                activeClassID = classID
                startTicker()
                startPollerIfNeeded()
            } catch {
                print("❌ Failed to start class: \(error.localizedDescription)")
            }
        }
    }

    func endClass(_ classID: UUID) {
        print("🔴 endClass() CALLED for class: \(classID)")
        Task {
            do {
                let updated = try await api.endClass(classID: classID)
                print("✅ Class ended successfully: \(classID)")
                print("🔴 Updated class isActive: \(updated.isActive)")
                print("🔴 Updated class endTime: \(String(describing: updated.endTime))")
                replace(updated)

                // If this was the active class, clear it
                if activeClassID == classID {
                    print("🔴 This was the active class, clearing activeClassID")
                    activeClassID = nil
                    stopTicker()
                    stopPoller()
                }
                print("🔴 State cleanup complete")
            } catch {
                print("❌ Failed to end class: \(error)")
                print("❌ Error localized: \(error.localizedDescription)")
                // Force refresh the class to get latest state
                if let fresh = try? await api.getClass(id: classID) {
                    print("🔄 Refreshed class, isActive: \(fresh.isActive)")
                    replace(fresh)
                }
            }
        }
    }

    func endActiveClass() {
        print("🔴 endActiveClass() CALLED")
        print("🔴 activeClassID: \(String(describing: activeClassID))")

        guard let id = activeClassID else {
            print("❌ endActiveClass: activeClassID is nil, returning early")
            return
        }

        endClass(id)
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }
    private func stopTicker() { ticker?.cancel(); ticker = nil }

    private func tick() {
        guard let id = activeClassID,
              let cls = classes.first(where: { $0.id == id }) else { return }
        if let secs = cls.secondsRemaining, secs <= 0 {
            endActiveClass()
        }
    }

    private func startPollerIfNeeded() {
        stopPoller()
        guard let seconds = pollEvery, seconds > 0, activeClassID != nil else { return }
        poller = Timer.publish(every: seconds, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let id = self.activeClassID else { return }
                Task {
                    if let fresh = try? await self.api.getClass(id: id) {
                        self.replace(fresh)
                    }
                }
            }
    }

    private func stopPoller() {
        poller?.cancel()
        poller = nil
    }

    func studentTapIn(classID: UUID) async throws {
        guard let userId = currentUser?.id,
              let studentName = userProfile?.name else {
            throw AppStateError.notAuthenticated
        }

        guard let apiClient = api as? SupabaseAPIClient else { return }
        let updated = try await apiClient.studentTapIn(classID: classID, userId: userId, studentName: studentName)
        replace(updated)

        // Set this as the active class after successful tap-in
        activeClassID = classID
    }
    func studentTapOut() {
        guard let id = activeClassID,
              let userId = currentUser?.id else { return }
        Task {
            if let apiClient = api as? SupabaseAPIClient,
               let updated = try? await apiClient.studentTapOut(classID: id, userId: userId) {
                replace(updated)
            }
        }
    }

    // MARK: - Roster Management

    func addStudentToRoster(classId: UUID, studentEmail: String) async throws {
        guard let userId = currentUser?.id else {
            throw AppStateError.notAuthenticated
        }

        if let apiClient = api as? SupabaseAPIClient {
            let updated = try await apiClient.addStudentToRoster(
                classId: classId,
                studentEmail: studentEmail,
                addedBy: userId
            )
            replace(updated)
        }
    }

    func removeStudentFromRoster(classId: UUID, studentUserId: UUID) async throws {
        if let apiClient = api as? SupabaseAPIClient {
            let updated = try await apiClient.removeStudentFromRoster(
                classId: classId,
                studentUserId: studentUserId
            )
            replace(updated)
        }
    }

    func loadStudentClasses() async {
        guard let userId = currentUser?.id else { return }

        if let apiClient = api as? SupabaseAPIClient {
            do {
                classes = try await apiClient.getStudentClasses(userId: userId)
            } catch {
                // Handle error silently for now
            }
        }
    }

    func searchUsersByEmail(query: String) async throws -> [UserProfile] {
        guard let apiClient = api as? SupabaseAPIClient else {
            return []
        }
        return try await apiClient.searchUsersByEmail(query: query)
    }

    private func replace(_ cls: ClassSession) {
        if let idx = classes.firstIndex(where: { $0.id == cls.id }) {
            classes[idx] = cls
        } else {
            classes.append(cls)
        }
    }
}
