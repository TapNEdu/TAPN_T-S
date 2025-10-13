import SwiftUI

struct StudentHomeView: View {
    @EnvironmentObject var app: AppState

    @State private var showSuccess = false
    @State private var navigateToInClass = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.bg.ignoresSafeArea()

                VStack(spacing: 22) {
                    Spacer()
                    Text("tap to tap-in")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)

                    Image(systemName: "face.smiling")
                        .font(.system(size: 96, weight: .thin))
                        .padding(28)
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .onTapGesture { beginScan() }

                    Button {
                        beginScan()
                    } label: { fullWidthButton("scan tag") }
                    .disabled(app.activeClass == nil)
                    .opacity(app.activeClass == nil ? 0.5 : 1)

                    Button(role: .cancel) {
                        app.resetToRoleSelection()
                    } label: { ghostButton("cancel") }

                    Spacer()

                    NavigationLink(isActive: $navigateToInClass) {
                        StudentInClassView()
                            .environmentObject(app)
                    } label: {
                        EmptyView()
                    }
                    .hidden()
                }
                .padding()
                .navigationTitle("student")

                if showSuccess {
                    SuccessOverlay(title: "Tap-in successful!")
                        .transition(.scale.combined(with: .opacity))
                        .zIndex(1)
                }
            }
        }
    }

    private func beginScan() {
        guard app.activeClass != nil else { return }

        NFCManager.shared.onTag = { _ in
            print("NFC tag detected for student:", app.studentName)
            app.studentTapIn()

            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                showSuccess = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.25)) {
                    showSuccess = false
                }
                navigateToInClass = true
            }
        }

        NFCManager.shared.beginScan()
    }

    private func fullWidthButton(_ title: String) -> some View {
        Text(title)
            .font(AppTheme.buttonFont())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white)
            .foregroundStyle(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func ghostButton(_ title: String) -> some View {
        Text(title)
            .font(AppTheme.buttonFont())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.field)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}



