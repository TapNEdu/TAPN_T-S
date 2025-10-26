import SwiftUI

struct TeacherHomeView: View {
    @EnvironmentObject var app: AppState
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.bg.ignoresSafeArea()
                if app.classes.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "rectangle.and.text.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(AppTheme.subtext)
                        Text("my classes").foregroundStyle(AppTheme.text).font(.title3.weight(.semibold))
                        Text("add a class to get started").foregroundStyle(AppTheme.subtext)
                    }
                } else {
                    List {
                        ForEach(app.classes) { cls in
                            NavigationLink {
                                TeacherClassView(classID: cls.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(cls.subject).foregroundStyle(AppTheme.text).font(.headline)
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
            .navigationTitle("my classes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("back") { app.resetToRoleSelection() }.foregroundStyle(AppTheme.text)
                }
            }
            .sheet(isPresented: $showAdd) {
                AddClassView { subject, time in
                    app.addClass(subject: subject, timeLabel: time)
                }
                .presentationDetents([.fraction(0.35), .medium])
            }
        }
    }
    
}
