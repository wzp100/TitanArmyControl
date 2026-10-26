import SwiftUI

/// Use macOS semantic colors so the window follows the user's appearance.
enum Palette {
    static let background = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let separator = Color(nsColor: .separatorColor).opacity(0.45)
    static let accent = Color.accentColor
}

enum Layout {
    static let compact: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let regular: CGFloat = 16
    static let large: CGFloat = 24
    static let page: CGFloat = 32
    static let groupRadius: CGFloat = 10
    static let contentWidth: CGFloat = 704
    static let controlWidth: CGFloat = 144
    static let sliderWidth: CGFloat = 220
    static let toneLabelWidth: CGFloat = 84
}
