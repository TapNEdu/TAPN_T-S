import SwiftUI

struct StudentTapOutView: View {
    @EnvironmentObject var app: AppState
    @State private var showSuccess = false

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                Text("tap to tap-out")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)

                Image(systemName: "face.smiling.inverse")
                    .font(.system(size: 96, weight: .thin))
                    .padding(28)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .onTapGesture { beginTapOutScan() }

                Button {
                    beginTapOutScan()
                } label: {
                    Text("scan tag")
                        .font(AppTheme.buttonFont())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.12))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Button(role: .cancel) {
                } label: {
                    Text("cancel")
                        .font(AppTheme.buttonFont())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.field)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Spacer()
            }
            .padding()
            .navigationTitle("tap-out")

            if showSuccess {
                SuccessOverlay(title: "Tap-out successful!")
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(1)
            }
        }
    }

    private func beginTapOutScan() {
        NFCManager.shared.onTag = { _ in
            print("NFC tag detected for tap-out:", app.studentName)
            app.studentTapOut()

            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                showSuccess = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.25)) {
                    showSuccess = false
                }
            }
        }
        NFCManager.shared.beginScan()
    }
}
