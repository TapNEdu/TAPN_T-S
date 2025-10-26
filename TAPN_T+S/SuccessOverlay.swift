import SwiftUI

struct SuccessOverlay: View {
    let title: String
    let message: String?
    
    init(title: String, message: String? = nil) {
        self.title = title
        self.message = message
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64, weight: .bold))
            Text(title)
                .font(.title3.weight(.semibold))
            
            if let message = message {
                Text(message)
                    .font(.body)
                    .foregroundStyle(AppTheme.text.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(28)
        .foregroundStyle(AppTheme.text)
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.35)) 
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(radius: 18, y: 8)
        .accessibilityAddTraits(.isModal)
    }
}
