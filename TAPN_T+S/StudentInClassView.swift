import SwiftUI

struct StudentInClassView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // Success icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 96))
                    .foregroundStyle(.green)
                    .padding(.bottom, 8)
                
                Text("You're Tapped In!")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                
                if let activeClass = app.activeClass {
                    VStack(spacing: 12) {
                        Text(activeClass.subject)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                        
                        Text(activeClass.timeLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.card)
                    .cornerRadius(16)
                }
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(AppTheme.buttonFont())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .foregroundStyle(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding()
        }
        .navigationTitle("Attendance")
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    NavigationStack {
        StudentInClassView()
            .environmentObject(AppState.shared)
    }
}
