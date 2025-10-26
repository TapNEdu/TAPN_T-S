import SwiftUI

struct RoleSelectionView: View {
    @EnvironmentObject var app: AppState
    @State private var selectedRole: UserRole? = nil
    @State private var name: String = ""
    @State private var showNameInput = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 250/255, green: 248/255, blue: 242/255),
                    Color(red: 245/255, green: 242/255, blue: 235/255),
                    Color(red: 240/255, green: 236/255, blue: 228/255)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 10) {
                    // Logo circle with lightning bolt
                    ZStack {
                        Circle()
                            .fill(AppTheme.sageGreen)
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 40))
                            .foregroundColor(AppTheme.lightText)
                    }
                    .padding(.bottom, 20)
                    
                    Text("TAPN")
                        .font(AppTheme.titleFont())
                        .foregroundColor(AppTheme.text)
                    Text("reclaim focus")
                        .foregroundColor(AppTheme.subtext)
                }

                if !showNameInput {
                    // Role selection buttons
                    VStack(spacing: 16) {
                        Button {
                            selectedRole = .teacher
                            showNameInput = true
                        } label: {
                            roleButtonLabel("Teacher")
                        }
                        
                        Button {
                            selectedRole = .student
                            showNameInput = true
                        } label: {
                            roleButtonLabel("Student")
                        }
                    }
                    .padding(.horizontal, 30)
                } else {
                    // Name input
                    VStack(spacing: 18) {
                        Text("Enter your name")
                            .foregroundColor(AppTheme.text)
                            .font(.headline)
                        
                        HStack {
                            TextField("your name", text: $name)
                                .textInputAutocapitalization(.words)
                                .foregroundColor(AppTheme.text)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                        }
                        .background(AppTheme.roundedField())
                        
                        HStack(spacing: 12) {
                            Button {
                                showNameInput = false
                                selectedRole = nil
                                name = ""
                            } label: {
                                Text("Back")
                                    .font(AppTheme.buttonFont())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(AppTheme.field)
                                    .foregroundColor(AppTheme.text)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            
                            Button {
                                if let role = selectedRole {
                                    if role == .teacher {
                                        app.teacherName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                                    } else {
                                        app.studentName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "You" : name
                                    }
                                    app.setRole(role)
                                }
                            } label: {
                                Text("Continue")
                                    .font(AppTheme.buttonFont())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(AppTheme.accent)
                                    .foregroundColor(AppTheme.lightText)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                        }
                    }
                    .padding(.horizontal, 30)
                }

                Spacer()
            }
        }
    }

    private func roleButtonLabel(_ title: String) -> some View {
        Text(title)
            .font(AppTheme.buttonFont())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.accent)
            .foregroundColor(AppTheme.lightText)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
