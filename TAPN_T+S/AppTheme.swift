import SwiftUI

enum AppTheme {
    // Background gradient colors
    static let bgTop = Color(red: 250/255, green: 248/255, blue: 242/255)      // #FAF8F2
    static let bgMiddle = Color(red: 245/255, green: 242/255, blue: 235/255)   // #F5F2EB  
    static let bgBottom = Color(red: 240/255, green: 236/255, blue: 228/255)   // #F0ECE4
    
    // Sage green colors with better contrast
    static let sageGreen = Color(red: 143/255, green: 168/255, blue: 145/255) // #8FA891
    static let sageGreenDark = Color(red: 100/255, green: 130/255, blue: 105/255) // Darker sage for better contrast
    static let sageGreenLight = Color(red: 180/255, green: 200/255, blue: 185/255) // Lighter sage for backgrounds
    
    // Text colors with high contrast
    static let darkText = Color(red: 45/255, green: 55/255, blue: 50/255)       // Much darker for readability
    static let lightText = Color(red: 250/255, green: 248/255, blue: 242/255)  // #FAF8F2
    static let mediumText = Color(red: 70/255, green: 85/255, blue: 75/255)     // Medium contrast text
    
    // Legacy colors for compatibility with better contrast
    static let bg = LinearGradient(
        colors: [bgTop, bgMiddle, bgBottom],
        startPoint: .top,
        endPoint: .bottom
    )
    static let card = sageGreenLight.opacity(0.3)  // More visible card backgrounds
    static let field = sageGreenLight.opacity(0.4) // More visible input fields
    static let text = darkText                     // High contrast text
    static let subtext = mediumText                 // Medium contrast for secondary text
    static let line = sageGreenDark.opacity(0.6)   // More visible borders
    static let accent = sageGreenDark               // Darker accent for better contrast

    static let present = Color.green.opacity(0.9)
    static let absent = Color.gray.opacity(0.8)
    static let bypass = Color.red.opacity(0.9)

    static func titleFont() -> Font { .system(size: 44, weight: .heavy, design: .rounded) }
    static func bodyFont()  -> Font { .system(.body, design: .rounded) }
    static func buttonFont()-> Font { .system(.headline, design: .rounded).weight(.semibold) }

    static func roundedField() -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(field)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(line))
    }

    static func cardStyle() -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(card)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(line))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    static func statusDot(_ color: Color) -> some View {
        Circle().fill(color).frame(width: 10, height: 10)
    }
}
