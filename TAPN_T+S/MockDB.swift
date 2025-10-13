import Foundation

actor MockDB {
    var classes: [ClassSession] = MockData.initialClasses

    func list() -> [ClassSession] { classes }

    func insert(_ c: ClassSession) -> ClassSession {
        classes.insert(c, at: 0)
        return c
    }

    func update(_ id: UUID, transform: (inout ClassSession) -> Void) throws -> ClassSession {
        guard let idx = classes.firstIndex(where: { $0.id == id }) else { throw APIError.notFound }
        var copy = classes[idx]
        transform(&copy)
        classes[idx] = copy
        return copy
    }

    func get(_ id: UUID) throws -> ClassSession {
        guard let c = classes.first(where: { $0.id == id }) else { throw APIError.notFound }
        return c
    }
}

enum APIError: Error, LocalizedError {
    case notFound
    case server(String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Resource not found."
        case .server(let msg):
            return msg
        }
    }
}


struct MockAPIClient: TAPNAPI {
    private let db = MockDB()
    private let latency: UInt64 = 180_000_000

    func bootstrap() async throws -> [ClassSession] {
        try await Task.sleep(nanoseconds: latency)
        return await db.list()
    }

    func createClass(subject: String, timeLabel: String) async throws -> ClassSession {
        try await Task.sleep(nanoseconds: latency)
        let new = ClassSession(subject: subject, timeLabel: timeLabel, students: MockData.defaultRoster())
        return await db.insert(new)
    }

    func getClass(id: UUID) async throws -> ClassSession {
        try await Task.sleep(nanoseconds: latency)
        return try await db.get(id)
    }

    func setDuration(classID: UUID, minutes: Int) async throws -> ClassSession {
        try await Task.sleep(nanoseconds: latency)
        return try await db.update(classID) { c in
            c.settings.durationMinutes = minutes
        }
    }

    func setCategories(classID: UUID, categories: Set<AppCategory>) async throws -> ClassSession {
        try await Task.sleep(nanoseconds: latency)
        return try await db.update(classID) { c in
            c.settings.categories = categories
        }
    }

    func setAllowedApps(classID: UUID, allowed: Set<AllowedApp>) async throws -> ClassSession {
        try await Task.sleep(nanoseconds: latency)
        return try await db.update(classID) { c in
            c.settings.allowedApps = allowed
        }
    }

    func startClass(classID: UUID) async throws -> ClassSession {
        try await Task.sleep(nanoseconds: latency)
        return try await db.update(classID) { c in
            c.startTime = Date()
            c.endTime = nil
        }
    }

    func endClass(classID: UUID) async throws -> ClassSession {
        try await Task.sleep(nanoseconds: latency)
        return try await db.update(classID) { c in
            c.endTime = Date()
        }
    }

    func studentTapIn(classID: UUID, studentName: String) async throws -> ClassSession {
        try await Task.sleep(nanoseconds: latency)
        return try await db.update(classID) { c in
            if let i = c.students.firstIndex(where: { $0.name == studentName }) {
                c.students[i].tappedInAt = Date()
                c.students[i].tappedOutAt = nil
            } else {
                c.students.insert(Student(name: studentName, tappedInAt: Date()), at: 0)
            }
        }
    }

    func studentTapOut(classID: UUID, studentName: String) async throws -> ClassSession {
        try await Task.sleep(nanoseconds: latency)
        return try await db.update(classID) { c in
            if let i = c.students.firstIndex(where: { $0.name == studentName }) {
                c.students[i].tappedOutAt = Date()
            }
        }
    }
}
