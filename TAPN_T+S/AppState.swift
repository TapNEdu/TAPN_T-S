import Foundation
import SwiftUI
import Combine
import CoreNFC

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState(api: TAPNAPI_Local())
    
    let api: TAPNAPI

    private var pollEvery: TimeInterval?
    private var poller: AnyCancellable?

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

        NFCManager.shared.onTag = { [weak self] studentName in
            guard let self else { return }
            self.handleNFCTap(studentName: studentName)
        }

        Task { await bootstrap() }
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
        Task {
            if let created = try? await api.createClass(subject: subject, timeLabel: timeLabel) {
                classes.insert(created, at: 0)
                
                // Also create and store the corresponding LegacyClass for app blocking
                let legacyClass = LegacyClass(
                    teacher: LegacyTeacher(name: teacherName, preferedName: teacherName),
                    ID: created.id.uuidString
                )
                addLegacyClass(legacyClass)
                print("📚 AppState: Created LegacyClass for new class: \(created.subject) with ID: \(created.id.uuidString)")
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
            if let current = activeClassID, current != classID {
                _ = try? await api.endClass(classID: current)
                if let updatedPrev = try? await api.getClass(id: current) { replace(updatedPrev) }
            }
            if let updated = try? await api.startClass(classID: classID) {
                replace(updated)
                activeClassID = classID
                startTicker()
                startPollerIfNeeded()
            }
        }
    }

    func endActiveClass() {
        guard let id = activeClassID else { return }
        Task {
            if let updated = try? await api.endClass(classID: id) {
                replace(updated)
            }
            activeClassID = nil
            stopTicker()
            stopPoller()
        }
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

    func studentTapIn() {
        guard let id = activeClassID else { return }
        Task {
            if let updated = try? await api.studentTapIn(classID: id, studentName: studentName) {
                replace(updated)
            }
        }
    }
    func studentTapOut() {
        guard let id = activeClassID else { return }
        Task {
            if let updated = try? await api.studentTapOut(classID: id, studentName: studentName) {
                replace(updated)
            }
        }
    }

    func handleNFCTap(studentName: String) {
        guard let id = activeClassID else { return }
        Task {
            if let updated = try? await api.studentTapIn(classID: id, studentName: studentName) {
                replace(updated)
            }
        }
    }

    private func replace(_ cls: ClassSession) {
        if let idx = classes.firstIndex(where: { $0.id == cls.id }) {
            classes[idx] = cls
        } else {
            classes.append(cls)
        }
    }
}
