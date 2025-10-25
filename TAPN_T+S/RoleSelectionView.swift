import SwiftUI

struct RoleSelectionView: View {
    @EnvironmentObject var app: AppState
    @State private var teacherName: String = ""
    @State private var studentName: String = ""

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 10) {
                    Text("TAPN").font(AppTheme.titleFont()).foregroundStyle(AppTheme.text)
                    Text("reclaim focus").foregroundStyle(AppTheme.subtext)
                }

                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Teacher").foregroundStyle(.white).font(.headline)
                        HStack {
                            TextField("your name", text: $teacherName)
                                .textInputAutocapitalization(.words)
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                        }
                        .background(AppTheme.roundedField())
                        Button {
                            let trimmedName = teacherName.trimmingCharacters(in: .whitespacesAndNewlines)
                            Task {
                                try? await app.createUserProfile(role: .teacher, name: trimmedName)
                                app.setRole(.teacher)
                            }
                        } label: {
                            fullWidthButtonLabel("enter as teacher")
                        }
                        .disabled(teacherName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(teacherName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Student").foregroundStyle(.white).font(.headline)
                        HStack {
                            TextField("your name", text: $studentName)
                                .textInputAutocapitalization(.words)
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                        }
                        .background(AppTheme.roundedField())
                        Button {
                            let trimmedName = studentName.trimmingCharacters(in: .whitespacesAndNewlines)
                            let finalName = trimmedName.isEmpty ? "Student" : trimmedName
                            Task {
                                try? await app.createUserProfile(role: .student, name: finalName)
                                app.setRole(.student)
                            }
                        } label: {
                            fullWidthButtonLabel("enter as student")
                        }
                    }
                }
                .padding(.horizontal, 30)

                Spacer()
            }
        }
    }

    private func fullWidthButtonLabel(_ title: String) -> some View {
        Text(title)
            .font(AppTheme.buttonFont())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white)
            .foregroundStyle(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
