import SwiftUI

struct NFCWriteView: View {
    @Binding var classID: String
    let onWrite: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Write Class ID to NFC Tag")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.text)
                    
                    Text("Enter a class identifier (e.g., MATH_101, SCIENCE_202) to write to an NFC tag. This tag will be placed in your classroom for students to scan.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.text.opacity(0.8))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Class ID")
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)
                    
                    TextField("Enter class ID (e.g., MATH_101)", text: $classID)
                        .textInputAutocapitalization(.characters)
                        .foregroundColor(AppTheme.text)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(AppTheme.roundedField())
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button {
                        onWrite(classID.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    } label: {
                        Text("Write to NFC Tag")
                            .font(AppTheme.buttonFont())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .foregroundStyle(AppTheme.text)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(classID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(classID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                    
                    Button(role: .cancel) {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(AppTheme.buttonFont())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.field)
                            .foregroundStyle(AppTheme.text)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
            .padding()
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationTitle("Write NFC Tag")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    NFCWriteView(classID: .constant("MATH_101")) { _ in }
}
