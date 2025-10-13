import SwiftUI

struct SuccessOverlay: View {
    let title: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64, weight: .bold))
            Text(title)
                .font(.title3.weight(.semibold))
        }
        .padding(28)
        .foregroundStyle(.white)
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.35)) 
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(radius: 18, y: 8)
        .accessibilityAddTraits(.isModal)
    }
}
