import Foundation

struct RemoteAPIClient: TAPNAPI {
    let baseURL: URL
    let tokenProvider: () -> String?

    init(baseURL: URL, tokenProvider: @escaping () -> String? = { nil }) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
    }

    private func request<T: Decodable>(_ path: String,
                                       method: String = "GET",
                                       body: Encodable? = nil) async throws -> T {
        var url = baseURL
        url.append(path: path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        if let token = tokenProvider() {
            req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.addValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP error"
            throw APIError.server(msg)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    // wire these when API is ready
    func bootstrap() async throws -> [ClassSession] {
        try await request("/api/classes")
    }
    func createClass(subject: String, timeLabel: String) async throws -> ClassSession {
        struct Body: Encodable { let subject: String; let timeLabel: String }
        return try await request("/api/classes", method: "POST", body: Body(subject: subject, timeLabel: timeLabel))
    }
    func getClass(id: UUID) async throws -> ClassSession {
        try await request("/api/classes/\(id.uuidString)")
    }
    func setDuration(classID: UUID, minutes: Int) async throws -> ClassSession {
        struct Body: Encodable { let minutes: Int }
        return try await request("/api/classes/\(classID.uuidString)/duration", method: "POST", body: Body(minutes: minutes))
    }
    func setCategories(classID: UUID, categories: Set<AppCategory>) async throws -> ClassSession {
        struct Body: Encodable { let categories: Set<AppCategory> }
        return try await request("/api/classes/\(classID.uuidString)/categories", method: "POST", body: Body(categories: categories))
    }
    func startClass(classID: UUID) async throws -> ClassSession {
        try await request("/api/classes/\(classID.uuidString)/start", method: "POST", body: EmptyBody())
    }
    func endClass(classID: UUID) async throws -> ClassSession {
        try await request("/api/classes/\(classID.uuidString)/end", method: "POST", body: EmptyBody())
    }
    func studentTapIn(classID: UUID, studentName: String) async throws -> ClassSession {
        struct Body: Encodable { let studentName: String }
        return try await request("/api/classes/\(classID.uuidString)/tapin", method: "POST", body: Body(studentName: studentName))
    }
    func studentTapOut(classID: UUID, studentName: String) async throws -> ClassSession {
        struct Body: Encodable { let studentName: String }
        return try await request("/api/classes/\(classID.uuidString)/tapout", method: "POST", body: Body(studentName: studentName))
    }
    
    func setAllowedApps(classID: UUID, allowed: Set<AllowedApp>) async throws -> ClassSession {
        struct Body: Encodable { let allowed: Set<AllowedApp> }
        return try await request("/api/classes/\(classID.uuidString)/allowed-apps",
                                 method: "POST",
                                 body: Body(allowed: allowed))
    }


}

private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init(_ wrapped: Encodable) { _encode = wrapped.encode }
    func encode(to encoder: Encoder) throws { try _encode(encoder) }
}
private struct EmptyBody: Encodable {}
