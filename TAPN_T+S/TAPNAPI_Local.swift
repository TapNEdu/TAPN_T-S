import Foundation

final class TAPNAPI_Local: TAPNAPI {
    private let school: LegacySchool
    private let teacher: LegacyTeacher

    private var classMap: [UUID: LegacyClass] = [:]

    private var durationByID: [UUID: Int] = [:]
    private var categoriesByID: [UUID: Set<AppCategory>] = [:]
    private var allowedAppsByID: [UUID: Set<AllowedApp>] = [:]
    private var startTimeByID: [UUID: Date?] = [:]
    private var endTimeByID: [UUID: Date?] = [:]

    init() {
        self.school = LegacySchool(name: "Swift Academy")
        self.teacher = LegacyTeacher(name: "Mr. Smith", preferedName: "John")
    }


    private func toSession(_ cls: LegacyClass, id: UUID) -> ClassSession {
        let attendance = cls.getCurrentAttendance() // [(studentName, statusString)]
        let students: [Student] = attendance.map { item in
            let lower = item.status.lowercased()
            if lower.contains("dismiss") {
                return Student(name: item.studentName, tappedInAt: Date(), tappedOutAt: Date())
            } else if lower.contains("present") || lower.contains("late") {
                return Student(name: item.studentName, tappedInAt: Date(), tappedOutAt: nil)
            } else {
                return Student(name: item.studentName, tappedInAt: nil, tappedOutAt: nil)
            }
        }

        var settings = SessionSettings()
        settings.durationMinutes = durationByID[id] ?? 45
        settings.categories = categoriesByID[id] ?? []
        settings.allowedApps = allowedAppsByID[id] ?? []

        var session = ClassSession(
            id: id,
            subject: cls.ID,
            timeLabel: cls.startTime,
            students: students
        )
        session.settings = settings
        session.startTime = startTimeByID[id] ?? nil
        session.endTime = endTimeByID[id] ?? nil
        return session
    }

    
    func bootstrap() async throws -> [ClassSession] {
        let sci = LegacyClass(teacher: teacher, ID: "Science", startTime: "13:00")
        school.addClass(sci)
        teacher.classes.append(sci)

        let names = ["Sarah", "Nate", "Bob Smith", "Allison Choi", "Claire Swift"]
        for n in names {
            let s = LegacyStudent(name: n, preferedName: n, grade: "10", ID: UUID().uuidString, school: school)
            s.classes.append(sci)
            sci.addStudent(s)
        }

        let id = UUID()
        classMap[id] = sci
        durationByID[id] = 30
        categoriesByID[id] = []
        allowedAppsByID[id] = []
        startTimeByID[id] = nil
        endTimeByID[id] = nil

        return [toSession(sci, id: id)]
    }

    func createClass(subject: String, timeLabel: String) async throws -> ClassSession {
        let cls = LegacyClass(teacher: teacher, ID: subject, startTime: timeLabel)
        school.addClass(cls)
        teacher.classes.append(cls)

        let id = UUID()
        classMap[id] = cls
        durationByID[id] = 30
        categoriesByID[id] = []
        allowedAppsByID[id] = []
        startTimeByID[id] = nil
        endTimeByID[id] = nil

        return toSession(cls, id: id)
    }

    func getClass(id: UUID) async throws -> ClassSession {
        guard let cls = classMap[id] else { throw APIError.notFound }
        return toSession(cls, id: id)
    }


    func setDuration(classID: UUID, minutes: Int) async throws -> ClassSession {
        guard let cls = classMap[classID] else { throw APIError.notFound }
        durationByID[classID] = minutes
        return toSession(cls, id: classID)
    }

    func setCategories(classID: UUID, categories: Set<AppCategory>) async throws -> ClassSession {
        guard let cls = classMap[classID] else { throw APIError.notFound }
        categoriesByID[classID] = categories
        return toSession(cls, id: classID)
    }

    func setAllowedApps(classID: UUID, allowed: Set<AllowedApp>) async throws -> ClassSession {
        guard let cls = classMap[classID] else { throw APIError.notFound }
        allowedAppsByID[classID] = allowed
        return toSession(cls, id: classID)
    }


    func startClass(classID: UUID) async throws -> ClassSession {
        guard let cls = classMap[classID] else { throw APIError.notFound }
        startTimeByID[classID] = Date()
        endTimeByID[classID] = nil
        return toSession(cls, id: classID)
    }

    func endClass(classID: UUID) async throws -> ClassSession {
        guard let cls = classMap[classID] else { throw APIError.notFound }
        endTimeByID[classID] = Date()
        return toSession(cls, id: classID)
    }


    func studentTapIn(classID: UUID, studentName: String) async throws -> ClassSession {
        guard let cls = classMap[classID] else { throw APIError.notFound }

        if let found = cls.students.first(where: { $0.name == studentName }) {
            cls.modifyAttendance(found, LegacyAttendanceStatus.present)
        } else {
            let temp = LegacyStudent(name: studentName, preferedName: studentName, grade: "10", ID: UUID().uuidString, school: school)
            temp.classes.append(cls)
            cls.addStudent(temp)
            cls.modifyAttendance(temp, LegacyAttendanceStatus.present)
        }
        return toSession(cls, id: classID)
    }

    func studentTapOut(classID: UUID, studentName: String) async throws -> ClassSession {
        guard let cls = classMap[classID] else { throw APIError.notFound }
        if let found = cls.students.first(where: { $0.name == studentName }) {
            cls.modifyAttendance(found, "dismiss", "\(studentName) tapped out")
        }
        return toSession(cls, id: classID)
    }
}
