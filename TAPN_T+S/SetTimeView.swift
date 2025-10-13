import SwiftUI

struct SetTimeView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    let classID: UUID

    @State private var custom: String = ""
    private let presets = [10, 20, 30, 60]

    var body: some View {
        NavigationStack {
            ZStack { AppTheme.bg.ignoresSafeArea() }
                .overlay(
                    VStack(spacing: 18) {
                        HStack(spacing: 10) {
                            ForEach(presets, id: \.self) { m in
                                Button {
                                    app.setDuration(for: classID, minutes: m); dismiss()
                                } label: { chip("\(m) min") }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("enter:").foregroundStyle(.white).font(.headline)
                            HStack {
                                TextField("minutes", text: $custom)
                                    .keyboardType(.numberPad)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 14)
                            }
                            .background(AppTheme.roundedField())
                            Button {
                                if let m = Int(custom) { app.setDuration(for: classID, minutes: m); dismiss() }
                            } label: { chip("apply custom") }
                            .disabled(Int(custom) == nil)
                            .opacity(Int(custom) == nil ? 0.5 : 1)
                        }
                        Spacer()
                    }
                    .padding()
                )
                .navigationTitle("set time")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("back") { dismiss() }.foregroundStyle(.white) }
                }
        }
    }

    private func chip(_ t: String) -> some View {
        Text(t)
            .font(AppTheme.buttonFont())
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(AppTheme.field)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.white)
    }
}
