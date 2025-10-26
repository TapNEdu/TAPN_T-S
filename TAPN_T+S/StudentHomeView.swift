import SwiftUI

struct StudentHomeView: View {
    @EnvironmentObject var app: AppState

    @State private var showSuccess = false
    @State private var showRoleSwitcher = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var successAction: String = "Tap-in"

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.bg.ignoresSafeArea()

                VStack(spacing: 22) {
                    // Show rostered classes
                    if !app.classes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your Classes")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(app.classes) { cls in
                                        ClassCard(
                                            classSession: cls,
                                            isSelected: app.activeClassID == cls.id,
                                            onTap: {
                                                if cls.isActive {
                                                    app.activeClassID = cls.id
                                                }
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.top)
                    }

                    Spacer()

                    if isTappedIn {
                        Text("tap to tap-out")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(.white)

                        Image(systemName: "hand.wave.fill")
                            .font(.system(size: 96, weight: .thin))
                            .padding(28)
                            .background(AppTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 28))
                            .onTapGesture { tapOut() }

                        Button {
                            tapOut()
                        } label: { fullWidthButton("tap out") }
                    } else {
                        Text("tap to tap-in")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(.white)

                        Image(systemName: "face.smiling")
                            .font(.system(size: 96, weight: .thin))
                            .padding(28)
                            .background(AppTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 28))
                            .onTapGesture { beginScan() }

                        Button {
                            beginScan()
                        } label: { fullWidthButton("scan tag") }
                        .disabled(app.activeClass == nil)
                        .opacity(app.activeClass == nil ? 0.5 : 1)
                    }

                    Menu {
                        Button(action: { showRoleSwitcher = true }) {
                            Label("Switch to Teacher", systemImage: "arrow.left.arrow.right")
                        }
                        Button(action: { Task { await app.signOut() } }) {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        ghostButton("menu")
                    }

                    Spacer()
                }
                .padding()
                .navigationTitle("student")
                .onAppear {
                    Task {
                        await app.loadStudentClasses()
                    }
                }

                if showSuccess {
                    SuccessOverlay(title: "\(successAction) successful!")
                        .transition(.scale.combined(with: .opacity))
                        .zIndex(1)
                }

                if showError, let errorMessage = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.red)

                        Text("\(successAction) Failed")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button("Dismiss") {
                            withAnimation {
                                showError = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(32)
                    .background(Color.black.opacity(0.9))
                    .cornerRadius(20)
                    .shadow(radius: 20)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(2)
                }
            }
            .confirmationDialog("Switch Role", isPresented: $showRoleSwitcher) {
                Button("Switch to Teacher") {
                    Task {
                        try? await app.switchRole(to: .teacher)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to switch to teacher mode?")
            }
        }
    }

    private var isTappedIn: Bool {
        guard let activeClass = app.activeClass,
              let userId = app.currentUser?.id else {
            return false
        }

        // Check if student is in the students list and is currently present
        return activeClass.students.contains { student in
            student.userId == userId && student.status == .present
        }
    }

    private func tapOut() {
        successAction = "Tap-out"
        app.studentTapOut()

        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showSuccess = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.25)) {
                showSuccess = false
            }
        }
    }

    private func beginScan() {
        successAction = "Tap-in"
        guard app.activeClass != nil else { return }

        NFCManager.shared.onTag = { [self] _ in
            print("NFC tag detected for student:", app.userProfile?.name ?? "Unknown")

            Task { @MainActor in
                do {
                    try await app.studentTapIn()

                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showSuccess = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.easeOut(duration: 0.25)) {
                            showSuccess = false
                        }
                    }
                } catch {
                    errorMessage = error.localizedDescription
                    withAnimation {
                        showError = true
                    }
                }
            }
        }

        NFCManager.shared.beginScan()
    }

    private func fullWidthButton(_ title: String) -> some View {
        Text(title)
            .font(AppTheme.buttonFont())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white)
            .foregroundStyle(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func ghostButton(_ title: String) -> some View {
        Text(title)
            .font(AppTheme.buttonFont())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.field)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ClassCard: View {
    let classSession: ClassSession
    var isSelected: Bool = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(classSession.subject)
                .font(.headline)
                .foregroundStyle(.white)

            Text(classSession.timeLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            if classSession.isActive {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text(isSelected ? "Selected" : "Active")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            } else {
                Text("Not Started")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 160)
        .background(isSelected ? Color.green.opacity(0.3) : AppTheme.card)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            onTap?()
        }
        .opacity(classSession.isActive ? 1.0 : 0.5)
    }
}
