import SwiftUI

struct TeacherClassView: View {
    @EnvironmentObject var app: AppState
    let classID: UUID

    @State private var showingTime = false
    @State private var showingAllowedApps = false
    @State private var showingNFCWrite = false
    @State private var showWriteSuccess = false
    @State private var nfcClassID = ""

    @State private var remainingSeconds: Int? = nil

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()

            if let cls = app.classes.first(where: { $0.id == classID }) {

                VStack(spacing: 16) {
                    // NFC Write Button Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("NFC Tag")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Spacer()
                            Button { 
                                nfcClassID = generateClassID(for: cls)
                                showingNFCWrite = true 
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                        .font(.title3)
                                    Text("Write Tag")
                                        .font(.subheadline)
                                }
                                .foregroundStyle(AppTheme.lightText)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(AppTheme.sageGreenDark)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding()
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Roster Registration Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Roster Registration")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Spacer()
                            HStack(spacing: 16) {
                                Button {
                                    // TODO: Approve all pending students
                                } label: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.green)
                                }
                                
                                Button {
                                    // TODO: Deny all pending students
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                        
                        // Placeholder for pending students table
                        VStack(spacing: 8) {
                            Text("Pending Students")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.text.opacity(0.8))
                            
                            Text("Students who tap in will appear here for approval")
                                .font(.caption)
                                .foregroundStyle(AppTheme.subtext)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 20)
                                .frame(maxWidth: .infinity)
                                .background(AppTheme.field)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding()
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    List {
                        ForEach(cls.students) { s in
                            HStack {
                                Text(s.name).foregroundStyle(AppTheme.text)
                                Spacer()
                                switch s.status {
                                case .present:
                                    Label("present", systemImage: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                case .absent:
                                    Text("absent").foregroundStyle(.gray)
                                case .tappedOut:
                                    Text("tapped out").foregroundStyle(.gray)
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
                        .foregroundStyle(AppTheme.text)
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
                            .foregroundStyle(AppTheme.text)
                            .accessibilityAddTraits(.isHeader)
                    }

                    ToolbarItemGroup(placement: .bottomBar) {
                        Button { showingTime = true } label: { pill("set time") }
                        Button { showingAllowedApps = true } label: { pill("allow apps") }
                        Spacer()
                        if cls.isActive {
                            Button(role: .destructive) {
                                app.endActiveClass()
                                remainingSeconds = nil
                            } label: { pill("end") }
                        } else {
                            Button {
                                app.startClass(classID)
                                remainingSeconds = computeRemaining(for: cls)
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

                .onChange(of: app.classes) {
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
                .sheet(isPresented: $showingNFCWrite) {
                    NFCWriteView(classID: $nfcClassID, onWrite: { classID in
                        writeClassIDToTag(classID: classID)
                    })
                    .presentationDetents([.fraction(0.4), .medium])
                }
                
                if showWriteSuccess {
                    SuccessOverlay(title: "Class ID written to tag!")
                        .transition(.scale.combined(with: .opacity))
                        .zIndex(1)
                }

            } else {
                Text("Class not found").foregroundStyle(AppTheme.text)
            }
        }
    }

    private func pill(_ t: String) -> some View {
        Text(t)
            .font(AppTheme.buttonFont())
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(AppTheme.field)
            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(AppTheme.text)
    }

    private func remainingString(_ secs: Int) -> String {
        String(format: "%02d:%02d", secs / 60, secs % 60)
    }

    private func computeRemaining(for cls: ClassSession) -> Int? {
        guard let start = cls.startTime else { return nil }
        let end = start.addingTimeInterval(Double(cls.settings.durationMinutes) * 60)
        return max(0, Int(end.timeIntervalSince(Date())))
    }
    
    private func generateClassID(for cls: ClassSession) -> String {
        // Generate a class ID based on the subject and time
        let subjectCode = cls.subject.uppercased().replacingOccurrences(of: " ", with: "_")
        let timeCode = cls.timeLabel.replacingOccurrences(of: ":", with: "").replacingOccurrences(of: "–", with: "_")
        return "\(subjectCode)_\(timeCode)"
    }
    
    private func writeClassIDToTag(classID: String) {
        NFCManager.shared.onWriteComplete = { success, error in
            if success {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showWriteSuccess = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showWriteSuccess = false
                    }
                }
            } else {
                print("Write failed: \(error ?? "Unknown error")")
            }
        }
        
        NFCManager.shared.writeToTag(data: classID)
    }
}
