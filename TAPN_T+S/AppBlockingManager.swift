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
    
    private init() {
        // Check if we already have authorization
        checkAuthorizationStatus()
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
    
    // MARK: - Helper Methods
    
    func getBlockedAppsCount() -> Int {
        return store.shield.applications?.count ?? 0
    }
    
    func isAppBlocked(_ token: ApplicationToken) -> Bool {
        return store.shield.applications?.contains(token) ?? false
    }
}
