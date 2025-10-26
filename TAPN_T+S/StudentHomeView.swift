import SwiftUI
import CoreNFC

struct StudentHomeView: View {
    @EnvironmentObject var app: AppState

    @State private var showSuccess = false
    @State private var scannedClassID = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var rotation: Double = 0

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.bg.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()
                    
                    // Class name at top
                    VStack(spacing: 8) {
                        Text(app.activeClass?.subject ?? "No class")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(AppTheme.text)
                        
                        // Timer if class is active
                        if let cls = app.activeClass, let startTime = cls.startTime {
                            let endTime = startTime.addingTimeInterval(Double(cls.settings.durationMinutes) * 60)
                            
                            Text("time left:")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.subtext)
                            
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                let remaining = max(0, Int(endTime.timeIntervalSince(context.date)))
                                Text(formatTime(remaining))
                                    .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                                    .foregroundStyle(AppTheme.text)
                            }
                        } else if app.activeClass != nil {
                            Text("waiting for teacher to start")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.subtext)
                        }
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    // Lightning bolt CTA button with orbiting animation
                    Button {
                        beginScan()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(AppTheme.sageGreen)
                                .frame(width: 180, height: 180)
                            
                            // Orbiting elements around the border
                            ForEach(0..<8, id: \.self) { index in
                                Circle()
                                    .fill(AppTheme.lightText)
                                    .frame(width: 8, height: 8)
                                    .offset(y: -86)
                                    .rotationEffect(.degrees(rotation + Double(index) * 45))
                            }
                            
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 75))
                                .foregroundColor(AppTheme.lightText)
                        }
                    }
                    .padding(.vertical, 40)
                    .onAppear {
                        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                            rotation = 360
                        }
                    }

                    // Dynamic text at bottom
                    Text(app.activeClass != nil ? "tap to tap-out" : "tap to tap-in")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(AppTheme.subtext)
                        .padding(.bottom, 20)

                    Spacer()
                }
                .padding()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            app.resetToRoleSelection()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("back")
                                    .font(.callout)
                            }
                            .foregroundStyle(AppTheme.text)
                        }
                    }
                }

                if showSuccess {
                    SuccessOverlay(title: "Tap-in successful!", message: "You've joined \(formatClassInfo(from: scannedClassID))")
                        .transition(.scale.combined(with: .opacity))
                        .zIndex(1)
                }
            }
            .alert("NFC Scan Result", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func beginScan() {
        print("🔍 Student: Starting NFC scan...")
        
        NFCManager.shared.onTag = { classID in
            print("✅ Student: NFC tag detected with class ID:", classID)
            scannedClassID = classID
            
            // Smart toggle logic: check if student is already in a class
            if app.activeClass != nil {
                // Student is already in class → TAP OUT
                print("🔍 DEBUG: Student already in class - performing TAP OUT")
                handleTapOut()
            } else {
                // Student not in class → TAP IN
                print("🔍 DEBUG: Student not in class - performing TAP IN")
                handleTapIn(classID: classID)
            }
        }

        NFCManager.shared.beginScan(simulated: false)
    }
    
    private func handleTapIn(classID: String) {
        // Find the matching class from app.classes
        if let matchingClass = findMatchingClass(for: classID) {
            print("📚 Student: Found matching class:", matchingClass.subject)
            app.activeClassID = matchingClass.id
            app.studentTapIn()

            // Enable app blocking
            enableAppBlockingForActiveClass(matchingClass)
            
            // Always allow tap-in
            let student = createStudentFromAppState()
            student.tap(NFC_ID: classID)
            
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                showSuccess = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.25)) {
                    showSuccess = false
                }
            }
        } else {
            alertMessage = "Class \(classID) not found"
            showAlert = true
        }
    }
    
    private func handleTapOut() {
        // Remove all app blocking
        AppBlockingManager.shared.removeAllRestrictions()
        
        // Clear active class
        app.activeClassID = nil
        
        // Show success message
        alertMessage = "Tapped out - Apps unblocked"
        showAlert = true
    }
    
    private func enableAppBlockingForActiveClass(_ classSession: ClassSession) {
        guard AppBlockingManager.shared.isAuthorized else {
            Task {
                let authorized = await AppBlockingManager.shared.requestAuthorization()
                if authorized {
                    AppBlockingManager.shared.applySimpleWhitelist()
                    alertMessage = "Checked into \(classSession.subject) - Focus mode activated"
                    showAlert = true
                }
            }
            return
        }

        AppBlockingManager.shared.applySimpleWhitelist()
        alertMessage = "Checked into \(classSession.subject) - Focus mode activated"
        showAlert = true
    }
    
    private func findMatchingClass(for classID: String) -> ClassSession? {
        print("🔍 Student: Looking for matching class for ID:", classID)
        print("🔍 Student: Available classes:", app.classes.map { "\($0.subject) - \($0.timeLabel)" })
        
        // Try to find a class that matches the scanned class ID
        // The class ID format is like "ENGLISH_1000_1100" (SUBJECT_STARTTIME_ENDTIME)
        let components = classID.split(separator: "_")
        
        if components.count >= 3 {
            let subject = String(components[0])
            let startTime = String(components[1])
            let endTime = String(components[2])
            
            print("🔍 Student: Parsed - subject: \(subject), start: \(startTime), end: \(endTime)")
            
            // Look for a class with matching subject and time
            let matchingClass = app.classes.first { cls in
                let subjectMatch = cls.subject.lowercased() == subject.lowercased()
                let timeMatch = cls.timeLabel.contains(startTime) || cls.timeLabel.contains(endTime)
                print("🔍 Student: Checking class \(cls.subject) - subjectMatch: \(subjectMatch), timeMatch: \(timeMatch)")
                return subjectMatch && timeMatch
            }
            
            if let match = matchingClass {
                print("✅ Student: Found matching class:", match.subject)
                return match
            }
        }
        
        // Fallback: try to match by subject only
        let subject = String(classID.split(separator: "_").first ?? "")
        print("🔍 Student: Fallback - trying to match subject:", subject)
        
        let fallbackMatch = app.classes.first { cls in
            let match = cls.subject.lowercased() == subject.lowercased()
            print("🔍 Student: Fallback check \(cls.subject) vs \(subject) - match: \(match)")
            return match
        }
        
        if let match = fallbackMatch {
            print("✅ Student: Found fallback match:", match.subject)
        } else {
            print("❌ Student: No matching class found")
        }
        
        return fallbackMatch
    }
    
    private func createStudentFromAppState() -> LegacyStudent {
        // Create a mock school for the student
        let school = LegacySchool(name: "TAPN School")
        
        // Create the student with the name from app state
        let student = LegacyStudent(
            name: app.studentName,
            preferedName: app.studentName,
            grade: "12", // Default grade
            ID: UUID().uuidString,
            school: school
        )
        
        return student
    }
    
    private func formatClassInfo(from classID: String) -> String {
        // Convert class ID back to readable format
        // Example: "MATH_1000_1100" -> "Math - 10:00–11:00"
        let components = classID.split(separator: "_")
        
        if components.count >= 3 {
            let subject = String(components[0]).capitalized
            let startTime = String(components[1])
            let endTime = String(components[2])
            
            // Format time: "1000" -> "10:00"
            let formattedStartTime = formatTimeFromString(startTime)
            let formattedEndTime = formatTimeFromString(endTime)
            
            return "\(subject) - \(formattedStartTime)–\(formattedEndTime)"
        }
        
        // Fallback to original class ID if parsing fails
        return classID
    }
    
    private func formatTimeFromString(_ timeString: String) -> String {
        // Convert "1000" to "10:00"
        if timeString.count == 4 {
            let hours = String(timeString.prefix(2))
            let minutes = String(timeString.suffix(2))
            return "\(hours):\(minutes)"
        }
        return timeString
    }
    
    private func formatTime(_ secs: Int) -> String {
        String(format: "%02d:%02d", secs / 60, secs % 60)
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




