import Foundation

protocol TAPNAPI {
    func bootstrap() async throws -> [ClassSession]
    func createClass(subject: String, timeLabel: String) async throws -> ClassSession
    func getClass(id: UUID) async throws -> ClassSession

    func setDuration(classID: UUID, minutes: Int) async throws -> ClassSession
    func setCategories(classID: UUID, categories: Set<AppCategory>) async throws -> ClassSession
    func setAllowedApps(classID: UUID, allowed: Set<AllowedApp>) async throws -> ClassSession

    func startClass(classID: UUID) async throws -> ClassSession
    func endClass(classID: UUID) async throws -> ClassSession

    func studentTapIn(classID: UUID, studentName: String) async throws -> ClassSession
    func studentTapOut(classID: UUID, studentName: String) async throws -> ClassSession
}
