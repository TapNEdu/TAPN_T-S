import SwiftUI

struct RoleSetupView: View {
    @EnvironmentObject var app: AppState
    @State private var selectedRole: UserRole = .teacher
    @State private var name: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Welcome message
            VStack(spacing: 16) {
                Text("Welcome!")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(AppTheme.text)

                Text("Let's set up your profile")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Form section
            VStack(spacing: 24) {
                // Name input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Name")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    TextField("Enter your name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.words)
                        .disabled(isSubmitting)
                }

                // Role selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("I am a...")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    HStack(spacing: 16) {
                        RoleButton(
                            role: .teacher,
                            selectedRole: $selectedRole,
                            isDisabled: isSubmitting
                        )

                        RoleButton(
                            role: .student,
                            selectedRole: $selectedRole,
                            isDisabled: isSubmitting
                        )
                    }
                }

                // Continue button
                Button(action: saveProfile) {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    } else {
                        Text("Continue")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                }
                .background(isFormValid ? AppTheme.present : Color.gray)
                .cornerRadius(12)
                .disabled(!isFormValid || isSubmitting)

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func saveProfile() {
        guard isFormValid else { return }

        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                try await app.createUserProfile(
                    role: selectedRole,
                    name: name.trimmingCharacters(in: .whitespaces)
                )
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

struct RoleButton: View {
    let role: UserRole
    @Binding var selectedRole: UserRole
    let isDisabled: Bool

    var body: some View {
        Button(action: { selectedRole = role }) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(isSelected ? .white : AppTheme.present)

                Text(title)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : AppTheme.present)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(isSelected ? AppTheme.present : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.present, lineWidth: 2)
            )
            .cornerRadius(12)
        }
        .disabled(isDisabled)
    }

    private var isSelected: Bool {
        selectedRole == role
    }

    private var icon: String {
        switch role {
        case .teacher:
            return "person.fill.checkmark"
        case .student:
            return "person.fill"
        case .none:
            return "person"
        }
    }

    private var title: String {
        switch role {
        case .teacher:
            return "Teacher"
        case .student:
            return "Student"
        case .none:
            return ""
        }
    }
}

#Preview {
    RoleSetupView()
        .environmentObject(AppState(api: MockAPIClient()))
}