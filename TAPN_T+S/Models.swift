import Foundation

enum UserRole: String, Codable {
    case none, teacher, student
}

struct UserProfile: Codable, Hashable {
    let id: UUID
    let email: String
    var role: UserRole?
    var name: String
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, email, role, name
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
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
    var userId: UUID?  // Link to authenticated user
    var name: String
    var tappedInAt: Date?
    var tappedOutAt: Date?

    init(id: UUID = UUID(), userId: UUID? = nil, name: String, tappedInAt: Date? = nil, tappedOutAt: Date? = nil) {
        self.id = id
        self.userId = userId
        self.name = name
        self.tappedInAt = tappedInAt
        self.tappedOutAt = tappedOutAt
    }

    enum CodingKeys: String, CodingKey {
        case id, name
        case userId = "user_id"
        case tappedInAt = "tapped_in_at"
        case tappedOutAt = "tapped_out_at"
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
    var teacherId: UUID?  // Link to teacher who created the class
    var subject: String
    var timeLabel: String
    var students: [Student]
    var roster: [RosterEntry]  // Students assigned to this class
    var settings: SessionSettings = .init()
    var startTime: Date?
    var endTime: Date?

    init(
        id: UUID = UUID(),
        teacherId: UUID? = nil,
        subject: String,
        timeLabel: String,
        students: [Student] = [],
        roster: [RosterEntry] = []
    ) {
        self.id = id
        self.teacherId = teacherId
        self.subject = subject
        self.timeLabel = timeLabel
        self.students = students
        self.roster = roster
    }

    enum CodingKeys: String, CodingKey {
        case id, subject, settings, students, roster
        case teacherId = "teacher_id"
        case timeLabel = "time_label"
        case startTime = "start_time"
        case endTime = "end_time"
    }

    var isActive: Bool { startTime != nil && endTime == nil }
    var secondsRemaining: Int? {
        guard let startTime else { return nil }
        let end = startTime.addingTimeInterval(Double(settings.durationMinutes) * 60)
        return max(0, Int(end.timeIntervalSince(Date())))
    }
}

struct RosterEntry: Identifiable, Hashable, Codable {
    let id: UUID
    let classSessionId: UUID
    let studentUserId: UUID
    let studentName: String  // Denormalized for display
    let studentEmail: String  // For searching/inviting
    let addedAt: Date
    let addedByUserId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case classSessionId = "class_session_id"
        case studentUserId = "student_user_id"
        case studentName = "student_name"
        case studentEmail = "student_email"
        case addedAt = "added_at"
        case addedByUserId = "added_by_user_id"
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
