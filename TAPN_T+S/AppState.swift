import Foundation
import SwiftUI
import Combine
import CoreNFC

@MainActor
final class AppState: ObservableObject {
    let api: TAPNAPI

    private var pollEvery: TimeInterval?
    private var poller: AnyCancellable?

    @Published var role: UserRole = .none
    @Published var teacherName: String = ""
    @Published var studentName: String = "You"

    @Published var classes: [ClassSession] = []
    @Published var activeClassID: UUID? = nil

    private var ticker: AnyCancellable?

    init(api: TAPNAPI, pollingInterval: TimeInterval? = nil) {
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
        } catch {
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

    func resetToRoleSelection() { role = .none; teacherName = "" }
    func setRole(_ r: UserRole) { role = r }

    func addClass(subject: String, timeLabel: String) {
        Task {
            if let created = try? await api.createClass(subject: subject, timeLabel: timeLabel) {
                classes.insert(created, at: 0)
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
