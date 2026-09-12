import HighlightSwift
import SwiftUI

enum CodeHighlightTheme: String, CaseIterable, Identifiable {
    case github
    case xcode
    case atomOne
    case solarized
    case tokyoNight

    var id: Self { self }

    var title: String {
        switch self {
        case .github: "GitHub"
        case .xcode: "Xcode"
        case .atomOne: "Atom One"
        case .solarized: "Solarized"
        case .tokyoNight: "Tokyo Night"
        }
    }

    var highlightTheme: HighlightTheme {
        switch self {
        case .github: .github
        case .xcode: .xcode
        case .atomOne: .atomOne
        case .solarized: .solarized
        case .tokyoNight: .tokyoNight
        }
    }
}

private struct CodeHighlightThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue = CodeHighlightTheme.github
}

extension EnvironmentValues {
    var codeHighlightTheme: CodeHighlightTheme {
        get { self[CodeHighlightThemeEnvironmentKey.self] }
        set { self[CodeHighlightThemeEnvironmentKey.self] = newValue }
    }
}
