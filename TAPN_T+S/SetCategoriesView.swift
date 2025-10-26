import SwiftUI

struct SetCategoriesView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    let classID: UUID

    @State private var selection: Set<AppCategory> = []

    var body: some View {
        NavigationStack {
            ZStack { AppTheme.bg.ignoresSafeArea() }
                .overlay(
                    List {
                        ForEach(AppCategory.allCases) { cat in
                            Button {
                                if selection.contains(cat) { selection.remove(cat) } else { selection.insert(cat) }
                            } label: {
                                HStack {
                                    Image(systemName: selection.contains(cat) ? "checkmark.circle.fill" : "circle")
                                    Text(cat.title)
                                    Spacer()
                                }
                                .foregroundStyle(.white)
                            }
                            .listRowBackground(AppTheme.card)
                        }
                    }
                    .scrollContentBackground(.hidden)
                )
                .navigationTitle("select categories")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("back") { dismiss() }.foregroundStyle(AppTheme.text) }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("apply") {
                            app.setCategories(for: classID, selection)
                            dismiss()
                        }.foregroundStyle(AppTheme.text)
                    }
                }
        }
        .onAppear {
            if let cls = app.classes.first(where: { $0.id == classID }) {
                selection = cls.settings.categories
            }
        }
    }
}
