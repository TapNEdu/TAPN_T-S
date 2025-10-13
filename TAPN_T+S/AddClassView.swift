import SwiftUI

struct AddClassView: View {
    var onSave: (_ title: Swift.String, _ time: Swift.String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var classTitle: Swift.String = ""
    @State private var classTime:  Swift.String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("Class name (e.g., English)", text: $classTitle)
                    .textFieldStyle(.roundedBorder)
                    .foregroundColor(.white)

                TextField("Time (e.g., 9am–10am)", text: $classTime)
                    .textFieldStyle(.roundedBorder)
                    .foregroundColor(.white)

                Spacer()
            }
            .padding()
            .background(AppTheme.bg)
            .navigationTitle("Add Class")
            .toolbar(content: {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let title = classTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        let time  = classTime.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(title, time)
                        dismiss()
                    }
                    .disabled(
                        classTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        classTime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            })
        }
    }
}
