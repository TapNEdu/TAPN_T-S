import SwiftUI

struct AddStudentToRosterView: View {
    @EnvironmentObject var app: AppState
    let classSession: ClassSession
    @Environment(\.dismiss) var dismiss

    @State private var emailQuery: String = ""
    @State private var searchResults: [UserProfile] = []
    @State private var isSearching = false
    @State private var isAdding = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Search section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Search by Email")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    HStack {
                        TextField("Enter student email", text: $emailQuery)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .disabled(isSearching || isAdding)

                        Button(action: performSearch) {
                            if isSearching {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("Search")
                            }
                        }
                        .disabled(emailQuery.trimmingCharacters(in: .whitespaces).isEmpty || isSearching || isAdding)
                    }
                }
                .padding(.horizontal)
                .padding(.top)

                // Error/Success messages
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if let successMessage = successMessage {
                    Text(successMessage)
                        .font(.caption)
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Search results
                if !searchResults.isEmpty {
                    List {
                        ForEach(searchResults, id: \.id) { user in
                            StudentSearchResultRow(
                                user: user,
                                isOnRoster: isStudentOnRoster(user.id),
                                isAdding: isAdding,
                                onAdd: { addStudent(user) }
                            )
                        }
                    }
                } else if !emailQuery.isEmpty && !isSearching {
                    Text("No users found")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Spacer()
            }
            .navigationTitle("Add Student")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func performSearch() {
        guard !emailQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        isSearching = true
        errorMessage = nil
        successMessage = nil

        Task {
            do {
                searchResults = try await app.searchUsersByEmail(query: emailQuery)

                // Filter out users who are not students
                searchResults = searchResults.filter { $0.role == .student }

                if searchResults.isEmpty {
                    errorMessage = "No students found with that email"
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isSearching = false
        }
    }

    private func addStudent(_ user: UserProfile) {
        isAdding = true
        errorMessage = nil
        successMessage = nil

        Task {
            do {
                try await app.addStudentToRoster(
                    classId: classSession.id,
                    studentEmail: user.email
                )
                successMessage = "\(user.name) added to roster"

                // Clear search after 2 seconds
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                emailQuery = ""
                searchResults = []
                successMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            isAdding = false
        }
    }

    private func isStudentOnRoster(_ userId: UUID) -> Bool {
        classSession.roster.contains { $0.studentUserId == userId }
    }
}

struct StudentSearchResultRow: View {
    let user: UserProfile
    let isOnRoster: Bool
    let isAdding: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.headline)

                Text(user.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isOnRoster {
                Text("On Roster")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            } else {
                Button(action: onAdd) {
                    if isAdding {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Add")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                .disabled(isAdding)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AddStudentToRosterView(
        classSession: ClassSession(
            subject: "Math",
            timeLabel: "10:00-11:00"
        )
    )
    .environmentObject(AppState(api: MockAPIClient()))
}
