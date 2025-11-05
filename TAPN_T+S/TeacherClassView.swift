import SwiftUI

struct TeacherClassView: View {
    @EnvironmentObject var app: AppState
    let classID: UUID

    @State private var showingTime = false
    @State private var showingAllowedApps = false
    @State private var showingAddStudent = false
    @State private var showingRoster = false
    @State private var showingNFCWrite = false

    @State private var remainingSeconds: Int? = nil
    @State private var writeSuccess = false
    @State private var writeError: String?

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()

            if let cls = app.classes.first(where: { $0.id == classID }) {

                VStack(spacing: 16) {
                    // Roster and Attendance
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Roster (\(cls.roster.count))")
                                .font(.headline)
                                .foregroundStyle(AppTheme.sageGreen)
                            Spacer()
                            Button(action: { showingRoster = true }) {
                                Text("Manage")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.sageGreen)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        if cls.roster.isEmpty {
                            Text("No students on roster. Tap 'Manage' to add students.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                                .padding(.bottom, 8)
                        }
                    }

                    // Attendance List
                    List {
                        ForEach(cls.roster) { rosterEntry in
                            let student = cls.students.first { $0.userId == rosterEntry.studentUserId }
                            HStack {
                                Text(rosterEntry.studentName).foregroundStyle(.gray)
                                Spacer()
                                switch student?.status ?? .absent {
                                case .present:
                                    Label("present", systemImage: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                case .absent, .tappedOut:
                                    Text("absent").foregroundStyle(.gray)
                                }
                            }
                            .listRowBackground(AppTheme.card)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)

                    let secondsToShow = cls.isActive
                        ? (remainingSeconds ?? computeRemaining(for: cls) ?? 0)
                        : cls.settings.durationMinutes * 60

                    Text(remainingString(secondsToShow))
                        .font(.system(size: 72, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(AppTheme.sageGreen)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .accessibilityIdentifier("TeacherBigTimerLabel")
                        .animation(.easeInOut, value: cls.isActive)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(AppTheme.bg, for: .navigationBar)


                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text(cls.subject)
                            .font(.largeTitle.bold())
                            .foregroundStyle(AppTheme.sageGreen)
                            .accessibilityAddTraits(.isHeader)
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingNFCWrite = true
                        } label: {
                            Image(systemName: "wave.3.right")
                                .foregroundStyle(.blue)
                        }
                    }

                    ToolbarItemGroup(placement: .bottomBar) {
                        Button { showingTime = true } label: { pill("set time") }
                        Button { showingAllowedApps = true } label: { pill("allow apps") }
                        Spacer()
                        if cls.isActive {
                            Button(role: .destructive) {
                                app.endClass(classID)
                                remainingSeconds = nil
                            } label: { pill("end") }
                        } else {
                            Button {
                                app.startClass(classID)
                                // Don't compute remaining seconds here - wait for the class to be updated
                                // The timer will pick it up on the next tick
                            } label: { pill("start class") }
                        }
                    }
                }

                .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                    guard let fresh = app.classes.first(where: { $0.id == classID }) else { return }
                    if fresh.isActive {
                        remainingSeconds = computeRemaining(for: fresh)
                        if let secs = remainingSeconds, secs <= 0 {
                            remainingSeconds = nil
                        }
                    }
                }

                .onChange(of: app.classes) { _ in
                    guard let fresh = app.classes.first(where: { $0.id == classID }) else { return }
                    if !fresh.isActive {
                        remainingSeconds = nil
                    }
                }

                .sheet(isPresented: $showingTime) {
                    SetTimeView(classID: classID)
                        .presentationDetents([.fraction(0.35), .medium])
                }
                .sheet(isPresented: $showingAllowedApps) {
                    SetAllowedAppsView(classID: classID)
                        .presentationDetents([.fraction(0.45), .medium])
                        .environmentObject(app)
                }
                .sheet(isPresented: $showingRoster) {
                    ClassRosterManagementView(classSession: cls)
                        .environmentObject(app)
                }
                .sheet(isPresented: $showingNFCWrite) {
                    NFCWriteSheetView(
                        classID: cls.id,
                        className: cls.subject,
                        onWriteSuccess: {
                            writeSuccess = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                writeSuccess = false
                            }
                        },
                        onWriteError: { error in
                            writeError = error
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                writeError = nil
                            }
                        }
                    )
                }
                .overlay {
                    if writeSuccess {
                        VStack {
                            Spacer()
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("NFC tag written successfully!")
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(12)
                            .padding(.bottom, 50)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(10)
                    }

                    if let error = writeError {
                        VStack {
                            Spacer()
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text("Write failed: \(error)")
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(12)
                            .padding(.bottom, 50)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(10)
                    }
                }

            } else {
                Text("Class not found").foregroundStyle(.white)
            }
        }
    }

    private func pill(_ t: String) -> some View {
        Text(t)
            .font(AppTheme.buttonFont())
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(AppTheme.field)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.white)
    }

    private func remainingString(_ secs: Int) -> String {
        String(format: "%02d:%02d", secs / 60, secs % 60)
    }

    private func computeRemaining(for cls: ClassSession) -> Int? {
        guard let start = cls.startTime else { return nil }
        let end = start.addingTimeInterval(Double(cls.settings.durationMinutes) * 60)
        return max(0, Int(end.timeIntervalSince(Date())))
    }
}
