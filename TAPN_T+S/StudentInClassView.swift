import SwiftUI

struct StudentInClassView: View {
    @EnvironmentObject var app: AppState

    private var endDate: Date? {
        guard let cls = app.activeClass,
              let start = cls.startTime else { return nil }
        return start.addingTimeInterval(Double(cls.settings.durationMinutes) * 60)
    }

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()

            VStack(spacing: 24) {
                if let cls = app.activeClass, let end = endDate {
                    Text("class: \(cls.subject)")
                        .foregroundStyle(.white)
                        .font(.title3.weight(.semibold))

                    Text("time left:")
                        .foregroundStyle(.white)
                        .font(.headline)

                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let remaining = max(0, Int(end.timeIntervalSince(context.date)))
                        Text(Self.remainingString(remaining))
                            .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    NavigationLink {
                        StudentTapOutView()
                    } label: {
                        Text("tap-out")
                            .font(AppTheme.buttonFont())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.field)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                } else {
                    Text("no class in session")
                        .foregroundStyle(AppTheme.subtext)
                }
            }
            .padding()
            .navigationTitle("in class")
        }
    }

    private static func remainingString(_ secs: Int) -> String {
        String(format: "%02d:%02d", secs / 60, secs % 60)
    }
}
