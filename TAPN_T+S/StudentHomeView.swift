import SwiftUI

struct StudentHomeView: View {
    @EnvironmentObject var app: AppState

    @State private var showSuccess = false
    @State private var navigateToInClass = false
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
                                .foregroundStyle(AppTheme.sageGreen)
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(app.classes) { cls in
                                        ClassCard(classSession: cls)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.top)
                    }

                    Spacer()
                    Text("Tap-In")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(AppTheme.sageGreen)

                    Image(systemName: "hand.tap")
                        .font(.system(size: 96, weight: .thin))
                        .padding(28)
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .onTapGesture { beginScan() }

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

                    NavigationLink(isActive: $navigateToInClass) {
                        StudentInClassView()
                            .environmentObject(app)
                    } label: {
                        EmptyView()
                    }
                    .hidden()
                }
                .padding()
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Student Dashboard")
                            .foregroundStyle(AppTheme.sageGreen)
                    }
                }
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

    private func beginScan() {
        NFCManager.shared.onTag = { classIDString in
            print("NFC tag detected for student:", self.app.userProfile?.name ?? "Unknown")
            print("Class ID from tag:", classIDString)

            Task { @MainActor in
                do {
                    // Parse the UUID from the NFC tag
                    guard let classID = UUID(uuidString: classIDString) else {
                        self.errorMessage = "Invalid class ID on NFC tag"
                        withAnimation {
                            self.showError = true
                        }
                        return
                    }

                    // Check if student is already tapped in to this class
                    let classSession = self.app.classes.first(where: { $0.id == classID })
                    let isAlreadyTappedIn = classSession?.students.contains { student in
                        student.userId == self.app.currentUser?.id && student.status == .present
                    } ?? false

                    if isAlreadyTappedIn {
                        // TAP OUT: Student is already tapped in, so tap them out
                        print("Student already tapped in - tapping out")
                        self.successAction = "Tap-out"
                        self.app.studentTapOut()

                        // Remove app blocking
                        AppBlockingManager.shared.stopBlocking()

                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            self.showSuccess = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            withAnimation(.easeOut(duration: 0.25)) {
                                self.showSuccess = false
                            }
                        }
                    } else {
                        // TAP IN: Student not tapped in yet, so tap them in
                        print("Student not tapped in - tapping in")
                        self.successAction = "Tap-in"
                        try await self.app.studentTapIn(classID: classID)

                        // Start app blocking after successful tap-in
                        if let tappedInClass = self.app.classes.first(where: { $0.id == classID }) {
                            AppBlockingManager.shared.startBlocking(for: tappedInClass)
                        }

                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            self.showSuccess = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            withAnimation(.easeOut(duration: 0.25)) {
                                self.showSuccess = false
                            }
                            self.navigateToInClass = true
                        }
                    }
                } catch {
                    self.errorMessage = error.localizedDescription
                    withAnimation {
                        self.showError = true
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(classSession.subject)
                .font(.headline)
                .foregroundStyle(AppTheme.subtext)

            Text(classSession.timeLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            if classSession.isActive {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text("Active")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .frame(width: 160)
        .background(AppTheme.card)
        .cornerRadius(12)
    }
}
