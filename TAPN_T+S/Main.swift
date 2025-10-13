//  Main.swift (renamed backend types)

import Foundation

struct LegacyRealTime {
    static func getCurrentTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }

    static func getCurrentTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
}

enum LegacyAttendanceStatus {
    case present
    case late(minutes: Int)
    case dismissed(reason: String)
    case absent

    var description: String {
        switch self {
        case .present:
            return "Present"
        case .late(let minutes):
            return "Late by \(minutes) minutes"
        case .dismissed(let reason):
            return "Dismissed - \(reason)"
        case .absent:
            return "Absent"
        }
    }
}

struct LegacyAttendanceRecord {
    let studentID: String
    let studentName: String
    let classID: String
    let dateTime: String
    let status: LegacyAttendanceStatus
}

final class LegacyAttendanceTracker {
    static let shared = LegacyAttendanceTracker()
    private(set) var records: [LegacyAttendanceRecord] = []

    func addRecord(_ record: LegacyAttendanceRecord) {
        records.append(record)
    }

    func getRecords(forStudentID studentID: String, inClassID classID: String) -> [LegacyAttendanceRecord] {
        return records.filter { $0.studentID == studentID && $0.classID == classID }
    }

    func getRecords(forClassID classID: String) -> [LegacyAttendanceRecord] {
        return records.filter { $0.classID == classID }
    }
}

final class LegacyClass {
    var allowedApps: [String]?
    var teacher: LegacyTeacher
    var ID: String
    var startTime: String = "08:00"
    private(set) var students: [LegacyStudent] = []
    private(set) var currentAttendance: [String: LegacyAttendanceStatus] = [:]

    init(teacher: LegacyTeacher, ID: String, startTime: String = "08:00") {
        self.teacher = teacher
        self.ID = ID
        self.startTime = startTime
    }

    func addStudent(_ student: LegacyStudent) {
        students.append(student)
    }

    func modifyAttendance(_ student: LegacyStudent, _ status: LegacyAttendanceStatus) {
        currentAttendance[student.ID] = status

        let record = LegacyAttendanceRecord(
            studentID: student.ID,
            studentName: student.name,
            classID: self.ID,
            dateTime: LegacyRealTime.getCurrentTimestamp(),
            status: status
        )
        LegacyAttendanceTracker.shared.addRecord(record)
    }

    func modifyAttendance(_ student: LegacyStudent, _ action: String, _ message: String) {
        let status: LegacyAttendanceStatus
        switch action.lowercased() {
        case "dismiss":
            status = .dismissed(reason: message)
        case "absent":
            status = .absent
        default:
            status = .present
        }
        modifyAttendance(student, status)
    }

    func getCurrentAttendance() -> [(studentName: String, status: String)] {
        var result: [(String, String)] = []
        for student in students {
            if let status = currentAttendance[student.ID] {
                result.append((student.name, status.description))
            } else {
                result.append((student.name, "Not marked"))
            }
        }
        return result
    }
}

final class LegacyTeacher {
    var name: String
    var preferedName: String
    var classes: [LegacyClass] = []

    init(name: String, preferedName: String) {
        self.name = name
        self.preferedName = preferedName
    }

    func checkCurrentAttendance(forClass classID: String) {
        guard let classToCheck = classes.first(where: { $0.ID == classID }) else {
            print("Class \(classID) not found")
            return
        }

        print("\n=== Current Attendance for Class \(classID) ===")
        let attendance = classToCheck.getCurrentAttendance()
        for (name, status) in attendance {
            print("\(name): \(status)")
        }
    }

    func checkLongTermAttendance(forClass classID: String) {
        print("\n=== Long-term Attendance History for Class \(classID) ===")
        let records = LegacyAttendanceTracker.shared.getRecords(forClassID: classID)
        if records.isEmpty {
            print("No attendance records found")
            return
        }
        for record in records {
            print("\(record.dateTime) - \(record.studentName): \(record.status.description)")
        }
    }

    func checkFullAttendance(forClass classID: String) {
        checkCurrentAttendance(forClass: classID)
        checkLongTermAttendance(forClass: classID)
    }
}

final class LegacyStudent {
    var name: String
    var preferedName: String?
    var grade: String
    var ID: String
    var school: LegacySchool
    var classes: [LegacyClass] = []
    var currentClass: LegacyClass?
    var prompt: Bool = true

    init(name: String, preferedName: String, grade: String, ID: String, school: LegacySchool) {
        self.name = name
        self.preferedName = preferedName
        self.grade = grade
        self.ID = ID
        self.school = school
    }

    func tap(NFC_ID: String) {
        for i in 0..<self.classes.count {
            if NFC_ID == self.classes[i].ID {
                currentClass = self.classes[i]
                if self.prompt {
                    let currentTime = LegacyRealTime.getCurrentTime()
                    let status: LegacyAttendanceStatus

                    if let lateMinutes = calculateLateMinutes(currentTime: currentTime, startTime: currentClass?.startTime ?? "08:00") {
                        status = .late(minutes: lateMinutes)
                    } else {
                        status = .present
                    }

                    currentClass?.modifyAttendance(self, status)
                }
                return
            }
        }
        self.school.requestRegistration(student: self, NFC_ID: NFC_ID)
    }

    func bePresent() {
        if let currentClass = currentClass {
            _ = currentClass.allowedApps
            // TODO: block unallowed apps
        }
    }

    func leaveEarly() {
        let message = "\(self.name) is leaving early"
        currentClass?.modifyAttendance(self, "dismiss", message)
        currentClass = nil
    }

    private func calculateLateMinutes(currentTime: String, startTime: String) -> Int? {
        let currentParts = currentTime.split(separator: ":")
        let startParts = startTime.split(separator: ":")

        guard currentParts.count == 2, startParts.count == 2,
              let currentHour = Int(currentParts[0]), let currentMin = Int(currentParts[1]),
              let startHour = Int(startParts[0]), let startMin = Int(startParts[1]) else {
            return nil
        }

        let currentTotal = currentHour * 60 + currentMin
        let startTotal = startHour * 60 + startMin
        let diff = currentTotal - startTotal

        return diff > 0 ? diff : nil
    }
}

final class LegacySchool {
    var name: String
    private(set) var classes: [LegacyClass] = []

    init(name: String) {
        self.name = name
    }

    func assignStudent(_ student: LegacyStudent, toClass classToAssign: LegacyClass) {
        classToAssign.addStudent(student)
    }

    func addClass(_ newClass: LegacyClass) {
        classes.append(newClass)
    }

    func displayRegistrationRequest(teacher: LegacyTeacher) {
        // TODO
    }

    func requestRegistration(student: LegacyStudent, NFC_ID: String) {
        // TODO
        print("Registration requested for student \(student.name) with NFC_ID: \(NFC_ID)")
    }
}

// NOTE: No top-level demo/testing code here
