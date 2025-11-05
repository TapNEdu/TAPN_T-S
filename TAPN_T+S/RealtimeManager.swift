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

    /// Debounce timers to prevent excessive refreshes
    private var debounceTimers: [UUID: Task<Void, Never>] = [:]

    /// Callback invoked when a class session changes
    /// Parameter: classID that changed
    var onClassChanged: ((UUID) async -> Void)?

    /// Callback invoked when student attendance changes
    /// Parameter: classID where student attendance changed
    var onStudentChanged: ((UUID) async -> Void)?

    /// Callback invoked when roster changes
    /// Parameter: classID where roster changed
    var onRosterChanged: ((UUID) async -> Void)?

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

        // Listen to class_sessions table changes
        let classFilter = "id=eq.\(classID.uuidString)"
        channel
            .on(.postgresChanges(
                event: .all,
                schema: "public",
                table: "class_sessions",
                filter: classFilter
            )) { [weak self] payload in
                print("🔴 RealtimeManager: Class session changed for \(classID)")
                self?.handleClassChange(classID: classID)
            }

        // Listen to students table changes
        let studentsFilter = "class_session_id=eq.\(classID.uuidString)"
        channel
            .on(.postgresChanges(
                event: .all,
                schema: "public",
                table: "students",
                filter: studentsFilter
            )) { [weak self] payload in
                print("🔴 RealtimeManager: Student attendance changed for class \(classID)")
                self?.handleStudentChange(classID: classID)
            }

        // Listen to class_rosters table changes
        let rosterFilter = "class_session_id=eq.\(classID.uuidString)"
        channel
            .on(.postgresChanges(
                event: .all,
                schema: "public",
                table: "class_rosters",
                filter: rosterFilter
            )) { [weak self] payload in
                print("🔴 RealtimeManager: Roster changed for class \(classID)")
                self?.handleRosterChange(classID: classID)
            }

        // Subscribe and store the channel
        channel.subscribe { [weak self] status, error in
            if let error = error {
                print("❌ RealtimeManager: Subscription error for class \(classID): \(error.localizedDescription)")
            } else {
                print("✅ RealtimeManager: Subscribed to class \(classID) with status: \(status)")
            }
        }

        classChannels[classID] = channel
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

        // Unsubscribe from the channel
        Task {
            await supabase.removeChannel(channel)
            print("✅ RealtimeManager: Unsubscribed from class \(classID)")
        }

        classChannels.removeValue(forKey: classID)
    }

    /// Unsubscribe from all active channels
    /// Called during sign out or app cleanup
    func cleanup() {
        print("🔴 RealtimeManager: Cleaning up all subscriptions")

        let classIDs = Array(classChannels.keys)
        for classID in classIDs {
            unsubscribeFromClass(classID: classID)
        }

        // Cancel all debounce timers
        debounceTimers.values.forEach { $0.cancel() }
        debounceTimers.removeAll()

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