import HighlightSwift
import SwiftUI

enum CodeHighlightTheme: String, CaseIterable, Identifiable {
    case github
    case xcode
    case atomOne
    case solarized
    case tokyoNight
    case a11y
    case classic
    case edge
    case google
    case gradient
    case grayscale
    case harmonic16
    case heetch
    case horizon
    case humanoid
    case ia
    case isblEditor
    case kimbie
    case nnfx
    case pandaSyntax
    case papercolor
    case paraiso
    case qtcreator
    case silk
    case solarFlare
    case stackoverflow
    case standard
    case summerfruit
    case synthMidnightTerminal
    case unikitty

    var id: Self { self }

    var title: String {
        switch self {
        case .github: "GitHub"
        case .xcode: "Xcode"
        case .atomOne: "Atom One"
        case .solarized: "Solarized"
        case .tokyoNight: "Tokyo Night"
        case .a11y: "a11y"
        case .classic: "Classic"
        case .edge: "Edge"
        case .google: "Google"
        case .gradient: "Gradient"
        case .grayscale: "Grayscale"
        case .harmonic16: "Harmonic16"
        case .heetch: "Heetch"
        case .horizon: "Horizon"
        case .humanoid: "Humanoid"
        case .ia: "iA"
        case .isblEditor: "ISBL Editor"
        case .kimbie: "Kimbie"
        case .nnfx: "NNFX"
        case .pandaSyntax: "Panda Syntax"
        case .papercolor: "Papercolor"
        case .paraiso: "Paraiso"
        case .qtcreator: "QT Creator"
        case .silk: "Silk"
        case .solarFlare: "Solar Flare"
        case .stackoverflow: "StackOverflow"
        case .standard: "Standard"
        case .summerfruit: "Summerfruit"
        case .synthMidnightTerminal: "Synth Midnight Terminal"
        case .unikitty: "Unikitty"
        }
    }

    var highlightTheme: HighlightTheme {
        switch self {
        case .github: .github
        case .xcode: .xcode
        case .atomOne: .atomOne
        case .solarized: .solarized
        case .tokyoNight: .tokyoNight
        case .a11y: .a11y
        case .classic: .classic
        case .edge: .edge
        case .google: .google
        case .gradient: .gradient
        case .grayscale: .grayscale
        case .harmonic16: .harmonic16
        case .heetch: .heetch
        case .horizon: .horizon
        case .humanoid: .humanoid
        case .ia: .ia
        case .isblEditor: .isblEditor
        case .kimbie: .kimbie
        case .nnfx: .nnfx
        case .pandaSyntax: .pandaSyntax
        case .papercolor: .papercolor
        case .paraiso: .paraiso
        case .qtcreator: .qtcreator
        case .silk: .silk
        case .solarFlare: .solarFlare
        case .stackoverflow: .stackoverflow
        case .standard: .standard
        case .summerfruit: .summerfruit
        case .synthMidnightTerminal: .synthMidnightTerminal
        case .unikitty: .unikitty
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
