import SwiftUI

struct NFCWriteSheetView: View {
    let classID: UUID
    let className: String
    let onWriteSuccess: () -> Void
    let onWriteError: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isWriting = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Write NFC Tag")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.sageGreen)

                    Text("Create a physical NFC tag for this class. Place the tag in your classroom so students can scan it to tap in.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.sageGreen.opacity(0.8))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Class Information")
                        .font(.headline)
                        .foregroundStyle(AppTheme.sageGreen)

                    VStack(spacing: 8) {
                        HStack {
                            Text("Class:")
                                .foregroundStyle(.gray.opacity(0.7))
                            Spacer()
                            Text(className)
                                .foregroundStyle(.gray)
                                .fontWeight(.medium)
                        }

                        HStack {
                            Text("Class ID:")
                                .foregroundStyle(.gray.opacity(0.7))
                            Spacer()
                            Text(classID.uuidString.prefix(8) + "...")
                                .foregroundStyle(.gray.opacity(0.7))
                                .font(.caption)
                                .monospaced()
                        }
                    }
                    .padding()
                    .background(AppTheme.card)
                    .cornerRadius(12)
                }

                if isWriting {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        Text("Hold your iPhone near the NFC tag...")
                            .foregroundStyle(.white)
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        writeToTag()
                    } label: {
                        Text(isWriting ? "Writing..." : "Write to NFC Tag")
                            .font(AppTheme.buttonFont())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isWriting ? Color.gray : Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(isWriting)

                    Button(role: .cancel) {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(AppTheme.buttonFont())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.field)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(isWriting)
                }
            }
            .padding()
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationTitle("NFC Tag Setup")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func writeToTag() {
        isWriting = true

        NFCManager.shared.onWriteComplete = { [self] success, error in
            isWriting = false

            if success {
                onWriteSuccess()
                dismiss()
            } else {
                onWriteError(error ?? "Unknown error")
            }
        }

        // Write the class UUID to the tag
        NFCManager.shared.writeToTag(data: classID.uuidString)
    }
}

#Preview {
    NFCWriteSheetView(
        classID: UUID(),
        className: "Math 10:00-11:00",
        onWriteSuccess: {},
        onWriteError: { _ in }
    )
}
