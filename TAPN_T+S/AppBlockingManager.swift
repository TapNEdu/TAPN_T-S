import Foundation
import FamilyControls
import ManagedSettings
import SwiftUI

@MainActor
final class AppBlockingManager: ObservableObject {
    static let shared = AppBlockingManager()

    private let store = ManagedSettingsStore()
    @Published var isAuthorized = false
    @Published var isBlocking = false

    // Persistence keys
    private let blockingEndTimeKey = "blockingEndTime"
    private let blockingClassIDKey = "blockingClassID"

    private init() {
        // Check if we already have authorization
        checkAuthorizationStatus()

        // Check if there's an active blocking session
        checkAndRestoreBlockingSession()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async -> Bool {
        print("🔒 AppBlocking: Requesting Family Controls authorization...")
        
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            await MainActor.run {
                self.isAuthorized = true
            }
            print("✅ AppBlocking: Authorization granted")
            return true
        } catch {
            print("❌ AppBlocking: Authorization denied - \(error.localizedDescription)")
            await MainActor.run {
                self.isAuthorized = false
            }
            return false
        }
    }
    
    private func checkAuthorizationStatus() {
        let status = AuthorizationCenter.shared.authorizationStatus
        isAuthorized = (status == .approved)
        print("🔒 AppBlocking: Current authorization status: \(status)")
    }
    
    // MARK: - App Blocking (Whitelist Approach)
    
    func applyWhitelist(apps: FamilyActivitySelection) {
        guard isAuthorized else {
            print("❌ AppBlocking: Cannot apply whitelist - not authorized")
            return
        }
        
        print("🔒 AppBlocking: Applying whitelist - allowing \(apps.applicationTokens.count) apps")
        
        // CORRECT WHITELIST APPROACH: Use Apple's built-in .all(except:) functionality
        // This is the proper way to implement whitelist blocking with Family Controls
        
        let allowedAppTokens = Set(apps.applicationTokens)
        
        // Apple handles "all apps" internally - we don't need to enumerate them
        // This blocks everything except the allowed apps
        store.shield.applicationCategories = .all(except: allowedAppTokens)
        
        // Also block distracting web domains
        let blockedWebDomains = getDistractingWebDomains()
        store.shield.webDomains = blockedWebDomains
        
        isBlocking = true
        print("✅ AppBlocking: True whitelist applied - \(apps.applicationTokens.count) apps allowed, everything else blocked")
    }
    
    func applySimpleWhitelist() {
        guard isAuthorized else {
            print("❌ AppBlocking: Cannot apply simple whitelist - not authorized")
            return
        }
        
        print("🔒 AppBlocking: Applying MAXIMUM AGGRESSIVE blocking")
        print("🔍 Current authorization status: \(isAuthorized)")
        
        // First, clear any existing restrictions
        store.clearAllSettings()
        print("🧹 Cleared all existing restrictions")
        
        // Block ALL apps except ones we explicitly allow
        store.shield.applicationCategories = .all(except: Set())
        print("✅ Applied .all(except: Set()) policy")
        
        // Also try blocking web domains and categories
        store.shield.webDomains = Set()
        store.shield.webDomainCategories = .all(except: Set())
        print("🌐 Also blocked web domains and categories")
        
        // Verify what was set
        print("🔍 Current applicationCategories policy: \(String(describing: store.shield.applicationCategories))")
        print("🔍 Current webDomains policy: \(String(describing: store.shield.webDomains))")
        print("🔍 Current webDomainCategories policy: \(String(describing: store.shield.webDomainCategories))")
        
        isBlocking = true
        print("✅ AGGRESSIVE BLOCKING COMPLETE")
        
        // Test if we can check what's currently blocked
        print("🔍 Testing blocking status...")
        print("🔍 Is blocking active: \(isBlocking)")
        
        print("⚠️  IMPORTANT: Messages, Phone, Settings are EXEMPT from Family Controls")
        print("⚠️  These system apps cannot be blocked by design")
        print("📱 Test with: Instagram, TikTok, Safari, Games, etc.")
    }
    
    private func getDistractingCategories() -> Set<ActivityCategoryToken> {
        // These are the category tokens for distracting app categories
        // We'll need to get these from the system at runtime
        return Set()
    }
    
    private func getDistractingWebDomains() -> Set<WebDomainToken> {
        // Block social media, gaming, entertainment websites
        return Set()
    }
    
    func removeAllRestrictions() {
        print("🔒 AppBlocking: Removing all restrictions...")
        
        // Clear all blocking settings
        store.shield.applications = Set()
        store.shield.webDomains = Set()
        store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy<Application>.none
        
        isBlocking = false
        print("✅ AppBlocking: All restrictions removed")
    }
    
    // Test function to verify blocking is working
    func testBlockingStatus() {
        print("🔍 BLOCKING STATUS TEST:")
        print("🔍 Authorization: \(isAuthorized)")
        print("🔍 Is blocking: \(isBlocking)")
        print("🔍 Application categories: \(String(describing: store.shield.applicationCategories))")
        print("🔍 Web domains: \(String(describing: store.shield.webDomains))")
        print("🔍 Web domain categories: \(String(describing: store.shield.webDomainCategories))")
    }
    
    // Legacy method for compatibility
    func disableBlocking() {
        removeAllRestrictions()
    }

    // MARK: - Class Session Blocking

    func startBlocking(for classSession: ClassSession) {
        guard isAuthorized else {
            print("❌ AppBlocking: Cannot start blocking - not authorized")
            return
        }

        guard let startTime = classSession.startTime else {
            print("❌ AppBlocking: Cannot start blocking - class not started")
            return
        }

        let endTime = startTime.addingTimeInterval(Double(classSession.settings.durationMinutes) * 60)

        print("🔒 AppBlocking: Starting blocking for class: \(classSession.subject)")
        print("   Duration: \(classSession.settings.durationMinutes) minutes")
        print("   End time: \(endTime)")
        print("   Blocked categories: \(classSession.settings.categories)")
        print("   Allowed apps: \(classSession.settings.allowedApps)")

        // For now, use aggressive blocking (block all apps)
        // In the future, we can customize based on settings.categories and settings.allowedApps
        store.clearAllSettings()
        store.shield.applicationCategories = .all(except: Set())

        // Save blocking state for persistence
        UserDefaults.standard.set(endTime, forKey: blockingEndTimeKey)
        UserDefaults.standard.set(classSession.id.uuidString, forKey: blockingClassIDKey)

        isBlocking = true
        print("✅ AppBlocking: Blocking started until \(endTime)")

        // Schedule auto-removal when class ends
        scheduleBlockingRemoval(at: endTime, for: classSession.id)
    }

    func stopBlocking() {
        print("🔒 AppBlocking: Stopping blocking...")

        removeAllRestrictions()

        // Clear persistence
        UserDefaults.standard.removeObject(forKey: blockingEndTimeKey)
        UserDefaults.standard.removeObject(forKey: blockingClassIDKey)

        print("✅ AppBlocking: Blocking stopped")
    }

    private func checkAndRestoreBlockingSession() {
        guard let endTime = UserDefaults.standard.object(forKey: blockingEndTimeKey) as? Date,
              let classIDString = UserDefaults.standard.string(forKey: blockingClassIDKey),
              let classID = UUID(uuidString: classIDString) else {
            print("📱 AppBlocking: No active blocking session to restore")
            return
        }

        // Check if blocking should still be active
        if endTime > Date() {
            print("🔄 AppBlocking: Restoring active blocking session")
            print("   Class ID: \(classID)")
            print("   End time: \(endTime)")

            // Re-apply blocking
            store.shield.applicationCategories = .all(except: Set())
            isBlocking = true

            // Re-schedule removal
            scheduleBlockingRemoval(at: endTime, for: classID)
        } else {
            print("⏰ AppBlocking: Previous blocking session expired, cleaning up")
            stopBlocking()
        }
    }

    private func scheduleBlockingRemoval(at endTime: Date, for classID: UUID) {
        let timeUntilEnd = endTime.timeIntervalSinceNow

        guard timeUntilEnd > 0 else {
            print("⏰ AppBlocking: End time already passed, stopping blocking immediately")
            stopBlocking()
            return
        }

        print("⏰ AppBlocking: Scheduled auto-removal in \(Int(timeUntilEnd)) seconds")

        // Use DispatchQueue to schedule removal
        DispatchQueue.main.asyncAfter(deadline: .now() + timeUntilEnd) { [weak self] in
            print("⏰ AppBlocking: Auto-removing blocks - class ended")
            self?.stopBlocking()
        }
    }

    // MARK: - Helper Methods
    
    func getBlockedAppsCount() -> Int {
        return store.shield.applications?.count ?? 0
    }
    
    func isAppBlocked(_ token: ApplicationToken) -> Bool {
        return store.shield.applications?.contains(token) ?? false
    }
}
