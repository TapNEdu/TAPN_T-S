import SwiftUI

struct TeacherHomeView: View {
    @EnvironmentObject var app: AppState
    @State private var showAdd = false
    @State private var classToDelete: ClassSession?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.bg.ignoresSafeArea()
                if app.classes.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "rectangle.and.text.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(AppTheme.sageGreen.opacity(0.7))
                        Text("My classes").foregroundStyle(AppTheme.sageGreen).font(.title3.weight(.semibold))
                        Text("dd a class to get started").foregroundStyle(AppTheme.subtext)
                    }
                } else {
                    List {
                        ForEach(app.classes) { cls in
                            NavigationLink {
                                TeacherClassView(classID: cls.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(cls.subject).foregroundStyle(AppTheme.sageGreen).font(.headline)
                                        Text(cls.timeLabel).foregroundStyle(AppTheme.subtext).font(.subheadline)
                                    }
                                    Spacer()
                                    if cls.isActive {
                                        Label("live", systemImage: "dot.radiowaves.left.and.right")
                                            .foregroundStyle(.green)
                                    }
                                }
                                .padding(.vertical, 6)
                            }
                            .listRowBackground(AppTheme.card)
                        }
                        .onDelete { indexSet in
                            guard let index = indexSet.first else { return }
                            let cls = app.classes[index]

                            // Prevent deletion of active class
                            if cls.isActive {
                                print("Cannot delete active class")
                                return
                            }

                            classToDelete = cls
                        }
                    }
                    .scrollContentBackground(.hidden)
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button { showAdd = true } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(20)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 8)
                        }
                        .padding(20)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { Task { await app.signOut() } }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.title3)
                            .foregroundStyle(AppTheme.sageGreen)
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text("Teacher Dashboard")
                        .foregroundStyle(AppTheme.sageGreen)
                }
            }
            .onAppear {
                // Reload classes when view appears to ensure fresh data
                Task {
                    await app.bootstrap()

                    // Subscribe to real-time updates for all teacher's classes
                    subscribeToAllClasses()
                }
            }
            .onDisappear {
                // Unsubscribe from all class subscriptions
                unsubscribeFromAllClasses()
            }
            .onChange(of: app.classes) { _ in
                // When classes change (new class created), update subscriptions
                subscribeToAllClasses()
            }
            .sheet(isPresented: $showAdd) {
                AddClassView { subject, time in
                    app.addClass(subject: subject, timeLabel: time)
                }
                .presentationDetents([.fraction(0.35), .medium])
            }
            .confirmationDialog(
                "Delete Class",
                isPresented: Binding(
                    get: { classToDelete != nil },
                    set: { if !$0 { classToDelete = nil } }
                ),
                presenting: classToDelete
            ) { cls in
                Button("Delete \(cls.subject)", role: .destructive) {
                    app.deleteClass(cls.id)
                    classToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    classToDelete = nil
                }
            } message: { cls in
                Text("Are you sure you want to delete \(cls.subject)? This will remove all attendance records and cannot be undone.")
            }
        }
    }

    private func subscribeToAllClasses() {
        for classSession in app.classes {
            // Only subscribe if not already subscribed
            if !RealtimeManager.shared.isSubscribed(to: classSession.id) {
                RealtimeManager.shared.subscribeToClass(classID: classSession.id)
            }
        }
    }

    private func unsubscribeFromAllClasses() {
        for classSession in app.classes {
            RealtimeManager.shared.unsubscribeFromClass(classID: classSession.id)
        }
    }
}
