import Foundation
import Supabase

struct SupabaseAPIClient: TAPNAPI {

    // MARK: - User Profile Methods

    func getUserProfile(userId: UUID) async throws -> UserProfile? {
        let result: [UserProfile] = try await supabase
            .from("users")
            .select()
            .eq("id", value: userId.uuidString)
            .execute()
            .value

        return result.first
    }

    func createUserProfile(userId: UUID, email: String, role: UserRole?, name: String) async throws -> UserProfile {
        struct UserInsert: Encodable {
            let id: String
            let email: String
            let role: String?
            let name: String
        }
        
        let insert = UserInsert(
            id: userId.uuidString,
            email: email,
            role: role?.rawValue,
            name: name
        )

        let result: UserProfile = try await supabase
            .from("users")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        return result
    }

    func updateUserRole(userId: UUID, role: UserRole) async throws -> UserProfile {
        let result: UserProfile = try await supabase
            .from("users")
            .update(["role": role.rawValue])
            .eq("id", value: userId.uuidString)
            .select()
            .single()
            .execute()
            .value

        return result
    }

    func updateUserName(userId: UUID, name: String) async throws -> UserProfile {
        let result: UserProfile = try await supabase
            .from("users")
            .update(["name": name])
            .eq("id", value: userId.uuidString)
            .select()
            .single()
            .execute()
            .value

        return result
    }

    // MARK: - Bootstrap
    func bootstrap() async throws -> [ClassSession] {
        let result: [ClassSessionDTO] = try await supabase
            .from("class_sessions")
            .select("*, students(*), roster:class_rosters(*)")
            .order("created_at", ascending: false)
            .execute()
            .value

        return result.map { $0.toClassSession() }
    }

    // MARK: - Create Class
    func createClass(subject: String, timeLabel: String, teacherId: UUID) async throws -> ClassSession {
        let insert = ClassSessionInsert(
            teacherId: teacherId,
            subject: subject,
            timeLabel: timeLabel,
            settings: SessionSettings()
        )

        let result: ClassSessionDTO = try await supabase
            .from("class_sessions")
            .insert(insert)
            .select("*, students(*), roster:class_rosters(*)")
            .single()
            .execute()
            .value

        return result.toClassSession()
    }

    // MARK: - Get Class
    func getClass(id: UUID) async throws -> ClassSession {
        let result: ClassSessionDTO = try await supabase
            .from("class_sessions")
            .select("*, students(*), roster:class_rosters(*)")
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value

        return result.toClassSession()
    }

    // MARK: - Set Duration
    func setDuration(classID: UUID, minutes: Int) async throws -> ClassSession {
        // First, fetch current settings
        let current: ClassSessionDTO = try await supabase
            .from("class_sessions")
            .select("settings")
            .eq("id", value: classID.uuidString)
            .single()
            .execute()
            .value

        // Merge with new duration
        var updatedSettings = current.settings
        updatedSettings.durationMinutes = minutes

        let result: ClassSessionDTO = try await supabase
            .from("class_sessions")
            .update(["settings": updatedSettings])
            .eq("id", value: classID.uuidString)
            .select("*, students(*), roster:class_rosters(*)")
            .single()
            .execute()
            .value

        return result.toClassSession()
    }

    // MARK: - Set Categories
    func setCategories(classID: UUID, categories: Set<AppCategory>) async throws -> ClassSession {
        // Fetch current settings
        let current: ClassSessionDTO = try await supabase
            .from("class_sessions")
            .select("settings")
            .eq("id", value: classID.uuidString)
            .single()
            .execute()
            .value

        // Merge with new categories
        var updatedSettings = current.settings
        updatedSettings.categories = categories

        let result: ClassSessionDTO = try await supabase
            .from("class_sessions")
            .update(["settings": updatedSettings])
            .eq("id", value: classID.uuidString)
            .select("*, students(*), roster:class_rosters(*)")
            .single()
            .execute()
            .value

        return result.toClassSession()
    }

    // MARK: - Set Allowed Apps
    func setAllowedApps(classID: UUID, allowed: Set<AllowedApp>) async throws -> ClassSession {
        // Fetch current settings
        let current: ClassSessionDTO = try await supabase
            .from("class_sessions")
            .select("settings")
            .eq("id", value: classID.uuidString)
            .single()
            .execute()
            .value

        // Merge with new allowed apps
        var updatedSettings = current.settings
        updatedSettings.allowedApps = allowed

        let result: ClassSessionDTO = try await supabase
            .from("class_sessions")
            .update(["settings": updatedSettings])
            .eq("id", value: classID.uuidString)
            .select("*, students(*), roster:class_rosters(*)")
            .single()
            .execute()
            .value

        return result.toClassSession()
    }

    // MARK: - Start Class
    func startClass(classID: UUID) async throws -> ClassSession {
        let result: ClassSessionDTO = try await supabase
            .from("class_sessions")
            .update([
                "start_time": ISO8601DateFormatter().string(from: Date()),
                "end_time": nil as String?
            ])
            .eq("id", value: classID.uuidString)
            .select("*, students(*), roster:class_rosters(*)")
            .single()
            .execute()
            .value

        return result.toClassSession()
    }

    // MARK: - End Class
    func endClass(classID: UUID) async throws -> ClassSession {
        let result: ClassSessionDTO = try await supabase
            .from("class_sessions")
            .update(["end_time": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: classID.uuidString)
            .select("*, students(*), roster:class_rosters(*)")
            .single()
            .execute()
            .value

        return result.toClassSession()
    }

    // MARK: - Student Tap In
    func studentTapIn(classID: UUID, userId: UUID, studentName: String) async throws -> ClassSession {
        // Check if student is on the roster
        let rosterCheck: [RosterEntryDTO] = try await supabase
            .from("class_rosters")
            .select()
            .eq("class_session_id", value: classID.uuidString)
            .eq("student_user_id", value: userId.uuidString)
            .execute()
            .value

        guard !rosterCheck.isEmpty else {
            throw RosterError.notOnRoster
        }

        // Check if student already exists
        let existing: [StudentDTO] = try await supabase
            .from("students")
            .select()
            .eq("class_session_id", value: classID.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        if let existingStudent = existing.first {
            // Update existing student - tap in again
            try await supabase
                .from("students")
                .update([
                    "tapped_in_at": ISO8601DateFormatter().string(from: Date()),
                    "tapped_out_at": nil as String?
                ])
                .eq("id", value: existingStudent.id.uuidString)
                .execute()
        } else {
            // Insert new student
            let newStudent = StudentInsert(
                classSessionId: classID,
                userId: userId,
                name: studentName,
                tappedInAt: Date()
            )

            try await supabase
                .from("students")
                .insert(newStudent)
                .execute()
        }

        // Return updated class with all students
        return try await getClass(id: classID)
    }

    // MARK: - Student Tap Out
    func studentTapOut(classID: UUID, userId: UUID) async throws -> ClassSession {
        // Update student tap out time
        try await supabase
            .from("students")
            .update(["tapped_out_at": ISO8601DateFormatter().string(from: Date())])
            .eq("class_session_id", value: classID.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()

        // Return updated class
        return try await getClass(id: classID)
    }

    // MARK: - Roster Management

    func addStudentToRoster(classId: UUID, studentEmail: String, addedBy: UUID) async throws -> ClassSession {
        // First, find the student user by email
        let users: [UserProfile] = try await supabase
            .from("users")
            .select()
            .eq("email", value: studentEmail)
            .execute()
            .value

        guard let studentUser = users.first else {
            throw RosterError.userNotFound
        }

        // Add to roster
        let entry = RosterEntryInsert(
            classSessionId: classId,
            studentUserId: studentUser.id,
            addedByUserId: addedBy
        )

        try await supabase
            .from("class_rosters")
            .insert(entry)
            .execute()

        // Return updated class with roster
        return try await getClass(id: classId)
    }

    func removeStudentFromRoster(classId: UUID, studentUserId: UUID) async throws -> ClassSession {
        try await supabase
            .from("class_rosters")
            .delete()
            .eq("class_session_id", value: classId.uuidString)
            .eq("student_user_id", value: studentUserId.uuidString)
            .execute()

        return try await getClass(id: classId)
    }

    func getStudentClasses(userId: UUID) async throws -> [ClassSession] {
        let result: [ClassSessionDTO] = try await supabase
            .from("class_sessions")
            .select("*, students(*), roster:class_rosters!inner(*)")
            .eq("roster.student_user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value

        return result.map { $0.toClassSession() }
    }

    func searchUsersByEmail(query: String) async throws -> [UserProfile] {
        let result: [UserProfile] = try await supabase
            .from("users")
            .select()
            .ilike("email", pattern: "%\(query)%")
            .limit(10)
            .execute()
            .value

        return result
    }
}

enum RosterError: LocalizedError {
    case userNotFound
    case alreadyOnRoster
    case notOnRoster

    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "No user found with that email address"
        case .alreadyOnRoster:
            return "Student is already on the roster"
        case .notOnRoster:
            return "You are not on the roster for this class. Please contact your teacher."
        }
    }
}
