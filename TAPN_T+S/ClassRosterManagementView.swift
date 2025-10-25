import SwiftUI

struct ClassRosterManagementView: View {
    @EnvironmentObject var app: AppState
    let classSession: ClassSession
    @Environment(\.dismiss) var dismiss

    @State private var showingAddStudent = false
    @State private var studentToRemove: RosterEntry?
    @State private var showingRemoveConfirmation = false
    @State private var isRemoving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.red.opacity(0.1))
                }

                if classSession.roster.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                            .padding()

                        Text("No students on roster")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("Tap the + button to add students to this class")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(classSession.roster) { entry in
                            RosterEntryRow(
                                entry: entry,
                                onRemove: {
                                    studentToRemove = entry
                                    showingRemoveConfirmation = true
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Class Roster")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddStudent = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddStudent) {
                AddStudentToRosterView(classSession: classSession)
                    .environmentObject(app)
            }
            .alert("Remove Student", isPresented: $showingRemoveConfirmation) {
                Button("Cancel", role: .cancel) {
                    studentToRemove = nil
                }
                Button("Remove", role: .destructive) {
                    if let entry = studentToRemove {
                        removeStudent(entry)
                    }
                }
            } message: {
                if let entry = studentToRemove {
                    Text("Are you sure you want to remove \(entry.studentName) from this class roster?")
                }
            }
        }
    }

    private func removeStudent(_ entry: RosterEntry) {
        isRemoving = true
        errorMessage = nil

        Task {
            do {
                try await app.removeStudentFromRoster(
                    classId: classSession.id,
                    studentUserId: entry.studentUserId
                )
                studentToRemove = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            isRemoving = false
        }
    }
}

struct RosterEntryRow: View {
    let entry: RosterEntry
    let onRemove: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.studentName)
                    .font(.headline)

                Text(entry.studentEmail)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Added \(formatDate(entry.addedAt))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    ClassRosterManagementView(
        classSession: ClassSession(
            subject: "Math",
            timeLabel: "10:00-11:00",
            roster: [
                RosterEntry(
                    id: UUID(),
                    classSessionId: UUID(),
                    studentUserId: UUID(),
                    studentName: "John Doe",
                    studentEmail: "john@example.com",
                    addedAt: Date(),
                    addedByUserId: UUID()
                )
            ]
        )
    )
    .environmentObject(AppState(api: MockAPIClient()))
}
