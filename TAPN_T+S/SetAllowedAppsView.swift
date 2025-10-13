import SwiftUI

struct SetAllowedAppsView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    let classID: UUID

    @State private var selection: Set<AllowedApp> = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(AllowedApp.allCases) { a in
                        Toggle(isOn: binding(for: a)) {
                            Text(a.title)
                                .foregroundStyle(.white)
                        }
                        .tint(.green)
                        .listRowBackground(AppTheme.card)
                        .listSectionSeparatorTint(.clear)

                    }
                } header: {
                    Text("ALLOW THESE APPS DURING CLASS")
                        .textCase(.uppercase)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.subtext)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppTheme.bg)
            

            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        app.setAllowedApps(for: classID, allowed: selection)
                        dismiss()
                    }
                }
            }
            .navigationTitle("allow apps")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(AppTheme.bg, for: .navigationBar)
            .onAppear {
                
                if let cls = app.classes.first(where: { $0.id == classID }) {
                    selection = cls.settings.allowedApps
                }
            }
        }
    }

    private func binding(for app: AllowedApp) -> Binding<Bool> {
        Binding(
            get: { selection.contains(app) },
            set: { on in
                if on { selection.insert(app) } else { selection.remove(app) }
            }
        )
    }
}
