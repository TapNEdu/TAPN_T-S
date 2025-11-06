import Foundation
import Supabase
import Combine

/// Manages Supabase Realtime subscriptions for live data synchronization
/// Handles subscriptions to class sessions, student attendance, and roster changes
@MainActor
final class RealtimeManager: ObservableObject {
    static let shared = RealtimeManager()

    // MARK: - Properties

    /// Active channel subscriptions keyed by class ID
    private var classChannels: [UUID: RealtimeChannelV2] = [:]

    /// Active realtime subscriptions to keep them alive
    private var realtimeSubscriptions: [UUID: [RealtimeSubscription]] = [:]

    /// User roster channel (one per user)
    private var userRosterChannel: RealtimeChannelV2?
    private var userRosterSubscriptions: [RealtimeSubscription] = []

    /// Debounce timers to prevent excessive refreshes
    private var debounceTimers: [UUID: Task<Void, Never>] = [:]
    private var userRosterDebounceTimer: Task<Void, Never>?

    /// Callback invoked when a class session changes
    /// Parameter: classID that changed
    var onClassChanged: ((UUID) async -> Void)?

    /// Callback invoked when student attendance changes
    /// Parameter: classID where student attendance changed
    var onStudentChanged: ((UUID) async -> Void)?

    /// Callback invoked when roster changes
    /// Parameter: classID where roster changed
    var onRosterChanged: ((UUID) async -> Void)?

    /// Callback invoked when a user's roster membership changes (for students)
    var onUserRosterChanged: (() async -> Void)?

    private init() {
        print("🔴 RealtimeManager: Initialized")
    }

    // MARK: - Subscription Management

    /// Subscribe to real-time updates for a specific class
    /// Listens to class_sessions, students, and class_rosters tables
    /// - Parameter classID: The UUID of the class to subscribe to
    func subscribeToClass(classID: UUID) {
        // Prevent duplicate subscriptions
        guard classChannels[classID] == nil else {
            print("🔴 RealtimeManager: Already subscribed to class \(classID)")
            return
        }

        print("🔴 RealtimeManager: Subscribing to class \(classID)")

        let channelName = "class-\(classID.uuidString)"
        let channel = supabase.channel(channelName)

        var subscriptions: [RealtimeSubscription] = []

        // Listen to class_sessions table changes
        let classFilter = "id=eq.\(classID.uuidString)"
        let classSubscription = channel.onPostgresChange(
            AnyAction.self,
            schema: "public",
            table: "class_sessions",
            filter: classFilter
        ) { [weak self] _ in
            print("🔴 RealtimeManager: Class session changed for \(classID)")
            Task { @MainActor in
                self?.handleClassChange(classID: classID)
            }
        }
        subscriptions.append(classSubscription)

        // Listen to students table changes
        let studentsFilter = "class_session_id=eq.\(classID.uuidString)"
        let studentsSubscription = channel.onPostgresChange(
            AnyAction.self,
            schema: "public",
            table: "students",
            filter: studentsFilter
        ) { [weak self] _ in
            print("🔴 RealtimeManager: Student attendance changed for class \(classID)")
            Task { @MainActor in
                self?.handleStudentChange(classID: classID)
            }
        }
        subscriptions.append(studentsSubscription)

        // Listen to class_rosters table changes
        let rosterFilter = "class_session_id=eq.\(classID.uuidString)"
        let rosterSubscription = channel.onPostgresChange(
            AnyAction.self,
            schema: "public",
            table: "class_rosters",
            filter: rosterFilter
        ) { [weak self] _ in
            print("🔴 RealtimeManager: Roster changed for class \(classID)")
            Task { @MainActor in
                self?.handleRosterChange(classID: classID)
            }
        }
        subscriptions.append(rosterSubscription)

        // Store subscriptions and channel
        realtimeSubscriptions[classID] = subscriptions
        classChannels[classID] = channel

        // Subscribe to the channel
        Task {
            do {
                try await channel.subscribeWithError()
                print("✅ RealtimeManager: Subscribed to class \(classID)")
            } catch {
                print("❌ RealtimeManager: Subscription error for class \(classID): \(error.localizedDescription)")
            }
        }
    }

    /// Unsubscribe from real-time updates for a specific class
    /// - Parameter classID: The UUID of the class to unsubscribe from
    func unsubscribeFromClass(classID: UUID) {
        guard let channel = classChannels[classID] else {
            print("🔴 RealtimeManager: No active subscription for class \(classID)")
            return
        }

        print("🔴 RealtimeManager: Unsubscribing from class \(classID)")

        // Cancel any pending debounce timer
        debounceTimers[classID]?.cancel()
        debounceTimers.removeValue(forKey: classID)

        // Clean up subscriptions
        realtimeSubscriptions.removeValue(forKey: classID)

        // Unsubscribe from the channel
        Task {
            await supabase.removeChannel(channel)
            print("✅ RealtimeManager: Unsubscribed from class \(classID)")
        }

        classChannels.removeValue(forKey: classID)
    }

    /// Subscribe to roster changes for a specific user (for students)
    /// Notifies when the user is added/removed from any class roster
    /// - Parameter userId: The user ID to monitor roster changes for
    func subscribeToUserRoster(userId: UUID) {
        // Prevent duplicate subscriptions
        guard userRosterChannel == nil else {
            print("🔴 RealtimeManager: Already subscribed to user roster for \(userId)")
            return
        }

        print("🔴 RealtimeManager: Subscribing to user roster for \(userId)")

        let channelName = "user-roster-\(userId.uuidString)"
        let channel = supabase.channel(channelName)

        var subscriptions: [RealtimeSubscription] = []

        // Listen to class_rosters table changes for this user
        let rosterFilter = "student_user_id=eq.\(userId.uuidString)"
        let rosterSubscription = channel.onPostgresChange(
            AnyAction.self,
            schema: "public",
            table: "class_rosters",
            filter: rosterFilter
        ) { [weak self] _ in
            print("🔴 RealtimeManager: User roster changed for \(userId)")
            Task { @MainActor in
                self?.handleUserRosterChange()
            }
        }
        subscriptions.append(rosterSubscription)

        // Store subscriptions and channel
        userRosterSubscriptions = subscriptions
        userRosterChannel = channel

        // Subscribe to the channel
        Task {
            do {
                try await channel.subscribeWithError()
                print("✅ RealtimeManager: Subscribed to user roster for \(userId)")
            } catch {
                print("❌ RealtimeManager: User roster subscription error: \(error.localizedDescription)")
            }
        }
    }

    /// Unsubscribe from user roster changes
    func unsubscribeFromUserRoster() {
        guard let channel = userRosterChannel else {
            print("🔴 RealtimeManager: No active user roster subscription")
            return
        }

        print("🔴 RealtimeManager: Unsubscribing from user roster")

        // Cancel debounce timer
        userRosterDebounceTimer?.cancel()
        userRosterDebounceTimer = nil

        // Clean up subscriptions
        userRosterSubscriptions.removeAll()

        // Unsubscribe from the channel
        Task {
            await supabase.removeChannel(channel)
            print("✅ RealtimeManager: Unsubscribed from user roster")
        }

        userRosterChannel = nil
    }

    /// Unsubscribe from all active channels
    /// Called during sign out or app cleanup
    func cleanup() {
        print("🔴 RealtimeManager: Cleaning up all subscriptions")

        let classIDs = Array(classChannels.keys)
        for classID in classIDs {
            unsubscribeFromClass(classID: classID)
        }

        // Unsubscribe from user roster
        unsubscribeFromUserRoster()

        // Cancel all debounce timers
        debounceTimers.values.forEach { $0.cancel() }
        debounceTimers.removeAll()
        userRosterDebounceTimer?.cancel()
        userRosterDebounceTimer = nil

        // Clear all subscriptions
        realtimeSubscriptions.removeAll()

        print("✅ RealtimeManager: Cleanup complete")
    }

    // MARK: - Change Handlers

    /// Handle class session changes with debouncing
    private func handleClassChange(classID: UUID) {
        debouncedRefresh(classID: classID) { [weak self] in
            await self?.onClassChanged?(classID)
        }
    }

    /// Handle student attendance changes with debouncing
    private func handleStudentChange(classID: UUID) {
        debouncedRefresh(classID: classID) { [weak self] in
            await self?.onStudentChanged?(classID)
        }
    }

    /// Handle roster changes with debouncing
    private func handleRosterChange(classID: UUID) {
        debouncedRefresh(classID: classID) { [weak self] in
            await self?.onRosterChanged?(classID)
        }
    }

    /// Handle user roster changes with debouncing
    private func handleUserRosterChange() {
        // Cancel existing timer
        userRosterDebounceTimer?.cancel()

        // Create new debounced task
        let task = Task { @MainActor in
            // Wait 300ms before executing
            try? await Task.sleep(nanoseconds: 300_000_000)

            // Check if task was cancelled
            guard !Task.isCancelled else { return }

            // Execute the action
            await onUserRosterChanged?()

            // Clean up timer
            userRosterDebounceTimer = nil
        }

        userRosterDebounceTimer = task
    }

    /// Debounce refresh calls to prevent excessive updates
    /// - Parameters:
    ///   - classID: The class ID to refresh
    ///   - action: The async action to perform after debounce delay
    private func debouncedRefresh(classID: UUID, action: @escaping () async -> Void) {
        // Cancel existing timer for this class
        debounceTimers[classID]?.cancel()

        // Create new debounced task
        let task = Task { @MainActor in
            // Wait 300ms before executing
            try? await Task.sleep(nanoseconds: 300_000_000)

            // Check if task was cancelled
            guard !Task.isCancelled else { return }

            // Execute the action
            await action()

            // Clean up timer
            debounceTimers.removeValue(forKey: classID)
        }

        debounceTimers[classID] = task
    }

    // MARK: - Status

    /// Check if currently subscribed to a specific class
    /// - Parameter classID: The class ID to check
    /// - Returns: True if subscribed, false otherwise
    func isSubscribed(to classID: UUID) -> Bool {
        return classChannels[classID] != nil
    }

    /// Get count of active subscriptions
    var activeSubscriptionCount: Int {
        return classChannels.count
    }
}