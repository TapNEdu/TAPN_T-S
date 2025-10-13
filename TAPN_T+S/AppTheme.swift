import SwiftUI

enum AppTheme {
    static let bg = Color(white: 0.12)          
    static let card = Color(white: 0.18)
    static let field = Color(white: 0.22)
    static let text = Color.white
    static let subtext = Color.white.opacity(0.75)
    static let line = Color.white.opacity(0.10)
    static let accent = Color(white: 0.05)

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
            .shadow(color: .black.opacity(0.25), radius: 14, x: 0, y: 10)
    }

    static func statusDot(_ color: Color) -> some View {
        Circle().fill(color).frame(width: 10, height: 10)
    }
}
