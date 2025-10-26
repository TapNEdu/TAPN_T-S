import Foundation

// MARK: - Database Transfer Objects (DTOs)
// These models map directly to the Supabase database schema with snake_case fields

struct ClassSessionDTO: Codable {
    let id: UUID
    var teacherId: UUID?
    var subject: String
    var timeLabel: String
    var students: [StudentDTO]?
    var roster: [RosterEntryDTO]?
    var settings: SessionSettings
    var startTime: Date?
    var endTime: Date?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, subject, students, roster, settings
        case teacherId = "teacher_id"
        case timeLabel = "time_label"
        case startTime = "start_time"
        case endTime = "end_time"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // Convert DTO to domain model
    func toClassSession() -> ClassSession {
        var session = ClassSession(
            id: id,
            teacherId: teacherId,
            subject: subject,
            timeLabel: timeLabel,
            students: students?.map { $0.toStudent() } ?? [],
            roster: roster?.map { $0.toRosterEntry() } ?? []
        )
        session.settings = settings
        session.startTime = startTime
        session.endTime = endTime
        return session
    }

    // Create DTO from domain model
    static func from(_ session: ClassSession) -> ClassSessionDTO {
        ClassSessionDTO(
            id: session.id,
            teacherId: session.teacherId,
            subject: session.subject,
            timeLabel: session.timeLabel,
            students: session.students.map { StudentDTO.from($0) },
            roster: session.roster.map { RosterEntryDTO.from($0) },
            settings: session.settings,
            startTime: session.startTime,
            endTime: session.endTime,
            createdAt: nil,
            updatedAt: nil
        )
    }
}

struct StudentDTO: Codable {
    let id: UUID
    var classSessionId: UUID
    var userId: UUID?
    var name: String
    var tappedInAt: Date?
    var tappedOutAt: Date?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name
        case classSessionId = "class_session_id"
        case userId = "user_id"
        case tappedInAt = "tapped_in_at"
        case tappedOutAt = "tapped_out_at"
        case createdAt = "created_at"
    }

    // Convert DTO to domain model
    func toStudent() -> Student {
        Student(
            id: id,
            userId: userId,
            name: name,
            tappedInAt: tappedInAt,
            tappedOutAt: tappedOutAt
        )
    }

    // Create DTO from domain model
    static func from(_ student: Student, classSessionId: UUID? = nil) -> StudentDTO {
        StudentDTO(
            id: student.id,
            classSessionId: classSessionId ?? UUID(),
            userId: student.userId,
            name: student.name,
            tappedInAt: student.tappedInAt,
            tappedOutAt: student.tappedOutAt,
            createdAt: nil
        )
    }
}

struct RosterEntryDTO: Codable {
    let id: UUID
    let classSessionId: UUID
    let studentUserId: UUID
    var studentName: String?
    var studentEmail: String?
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

    // Convert DTO to domain model
    func toRosterEntry() -> RosterEntry {
        RosterEntry(
            id: id,
            classSessionId: classSessionId,
            studentUserId: studentUserId,
            studentName: studentName ?? "",
            studentEmail: studentEmail ?? "",
            addedAt: addedAt,
            addedByUserId: addedByUserId
        )
    }

    // Create DTO from domain model
    static func from(_ entry: RosterEntry) -> RosterEntryDTO {
        RosterEntryDTO(
            id: entry.id,
            classSessionId: entry.classSessionId,
            studentUserId: entry.studentUserId,
            studentName: entry.studentName,
            studentEmail: entry.studentEmail,
            addedAt: entry.addedAt,
            addedByUserId: entry.addedByUserId
        )
    }
}

// MARK: - Helper Types for Partial Updates

struct ClassSessionInsert: Encodable {
    let teacherId: UUID?
    let subject: String
    let timeLabel: String
    let settings: SessionSettings

    enum CodingKeys: String, CodingKey {
        case subject, settings
        case teacherId = "teacher_id"
        case timeLabel = "time_label"
    }
}

struct StudentInsert: Encodable {
    let classSessionId: UUID
    let userId: UUID?
    let name: String
    let tappedInAt: Date?

    enum CodingKeys: String, CodingKey {
        case name
        case classSessionId = "class_session_id"
        case userId = "user_id"
        case tappedInAt = "tapped_in_at"
    }
}

struct RosterEntryInsert: Encodable {
    let classSessionId: UUID
    let studentUserId: UUID
    let studentName: String
    let studentEmail: String
    let addedByUserId: UUID?

    enum CodingKeys: String, CodingKey {
        case classSessionId = "class_session_id"
        case studentUserId = "student_user_id"
        case studentName = "student_name"
        case studentEmail = "student_email"
        case addedByUserId = "added_by_user_id"
    }
}

// MARK: - JSON Update Helpers

struct SettingsUpdate: Encodable {
    let settings: [String: Any]

    enum CodingKeys: String, CodingKey {
        case settings
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(AnyCodable(settings), forKey: .settings)
    }
}

// Helper for encoding Any type
struct AnyCodable: Encodable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        case let date as Date:
            try container.encode(ISO8601DateFormatter().string(from: date))
        case is NSNull:
            try container.encodeNil()
        default:
            let context = EncodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "Cannot encode value of type \(type(of: value))"
            )
            throw EncodingError.invalidValue(value, context)
        }
    }
}
