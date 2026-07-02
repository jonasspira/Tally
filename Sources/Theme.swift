import SwiftUI

/// Tally's look: warm paper background, calm ink text, Soulver-style
/// teal answers on the right.
enum TallyTheme {
    static let bg        = Color(hex: 0xFDFDFB)   // paper
    static let sidebar   = Color(hex: 0xF5F4F0)
    static let text      = Color(hex: 0x2B2A26)   // ink
    static let subtle    = Color(hex: 0x8E8B82)
    static let answer    = Color(hex: 0x0A7B65)   // teal — the answer column
    static let answerDim = Color(hex: 0x9BB8B0)
    static let divider   = Color(hex: 0xECEAE4)
    static let accent    = Color(hex: 0xE07A2F)   // line-reference orange

    static let editorFont = Font.system(size: 15)
    static let answerFont = Font.system(size: 15, weight: .medium).monospacedDigit()
}

extension Color {
    /// Create a Color from a 0xRRGGBB integer.
    init(hex: UInt, alpha: Double = 1) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8)  & 0xFF) / 255,
                  blue:  Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}
