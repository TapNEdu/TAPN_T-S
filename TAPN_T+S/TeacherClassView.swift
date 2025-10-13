import SwiftUI

struct TeacherClassView: View {
    @EnvironmentObject var app: AppState
    let classID: UUID

    @State private var showingTime = false
    @State private var showingAllowedApps = false

    @State private var remainingSeconds: Int? = nil

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()

            if let cls = app.classes.first(where: { $0.id == classID }) {

                VStack(spacing: 16) {
                    List {
                        ForEach(cls.students) { s in
                            HStack {
                                Text(s.name).foregroundStyle(.white)
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
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .accessibilityIdentifier("TeacherBigTimerLabel")
                        .animation(.easeInOut, value: cls.isActive)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(AppTheme.bg, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)


                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text(cls.subject)
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
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
