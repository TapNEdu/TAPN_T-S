import Foundation

enum UserRole: String, Codable {
    case none, teacher, student
}


enum AppCategory: String, CaseIterable, Identifiable, Codable {
    case social, games, entertainment, shoppingFood, other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .social: return "social"
        case .games: return "games"
        case .entertainment: return "entertainment"
        case .shoppingFood: return "shopping & food"
        case .other: return "other"
        }
    }
}


enum AllowedApp: String, CaseIterable, Identifiable, Codable {
    case phone, messages, notes, camera, googleClassroom, email, canvas
    var id: String { rawValue }
    var title: String {
        switch self {
        case .phone: return "Phone"
        case .messages: return "Messages"
        case .notes: return "Notes"
        case .camera: return "Camera"
        case .googleClassroom: return "Google Classroom"
        case .email: return "Email"
        case .canvas: return "Canvas"
        }
    }
}


struct SessionSettings: Codable, Hashable {
    var categories: Set<AppCategory> = []

    var allowedApps: Set<AllowedApp> = []

    var durationMinutes: Int = 30
}


struct Student: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var tappedInAt: Date?
    var tappedOutAt: Date?

    init(id: UUID = UUID(), name: String, tappedInAt: Date? = nil, tappedOutAt: Date? = nil) {
        self.id = id
        self.name = name
        self.tappedInAt = tappedInAt
        self.tappedOutAt = tappedOutAt
    }

    enum Status: Codable, Hashable {
        case present, absent, tappedOut
    }

    var status: Status {
        if tappedOutAt != nil { return .tappedOut }
        return tappedInAt == nil ? .absent : .present
    }
}


struct ClassSession: Identifiable, Hashable, Codable {
    let id: UUID
    var subject: String
    var timeLabel: String
    var students: [Student]
    var settings: SessionSettings = .init()
    var startTime: Date?
    var endTime: Date?

    init(
        id: UUID = UUID(),
        subject: String,
        timeLabel: String,
        students: [Student] = MockData.defaultRoster()
    ) {
        self.id = id
        self.subject = subject
        self.timeLabel = timeLabel
        self.students = students
    }

    var isActive: Bool { startTime != nil && endTime == nil }
    var secondsRemaining: Int? {
        guard let startTime else { return nil }
        let end = startTime.addingTimeInterval(Double(settings.durationMinutes) * 60)
        return max(0, Int(end.timeIntervalSince(Date())))
    }
}



enum MockData {
    static func defaultRoster() -> [Student] {
        [
            "Allison Choi","Bob Smith","Claire Swift","Ethan Kim","Olivia Zhang",
            "Noah Patel","Emma Lopez","Mia Johnson","Lucas Brown","James Rivera"
        ].map { Student(name: $0) }
    }

    static let initialClasses: [ClassSession] = [
        .init(subject: "English", timeLabel: "10:00–11:00"),
        .init(subject: "Math",    timeLabel: "11:00–12:00"),
        .init(subject: "Science", timeLabel: "1:00–2:00")
    ]
}
