import AppKit
import Combine
import Foundation
import SwiftUI

enum SupportedAppLanguage: String, Equatable, Sendable {
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case englishUS = "en-US"

    var locale: Locale {
        Locale(identifier: rawValue)
    }
}

enum AppLanguagePreference: String, CaseIterable, Identifiable {
    case automatic
    case simplifiedChinese
    case traditionalChinese
    case englishUS

    var id: Self { self }

    var title: String {
        switch self {
        case .automatic:
            "Automatic"
        case .simplifiedChinese:
            "简体中文"
        case .traditionalChinese:
            "繁體中文"
        case .englishUS:
            "English (US)"
        }
    }

    func resolvedLanguage(
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> SupportedAppLanguage {
        switch self {
        case .simplifiedChinese:
            return .simplifiedChinese
        case .traditionalChinese:
            return .traditionalChinese
        case .englishUS:
            return .englishUS
        case .automatic:
            guard let preferredLanguage = preferredLanguages.first else {
                return .englishUS
            }

            let identifier = preferredLanguage
                .replacingOccurrences(of: "_", with: "-")
                .lowercased()
            guard identifier.hasPrefix("zh") else {
                return .englishUS
            }

            let usesTraditionalChinese = identifier.contains("hant")
                || identifier.contains("-tw")
                || identifier.contains("-hk")
                || identifier.contains("-mo")
            return usesTraditionalChinese ? .traditionalChinese : .simplifiedChinese
        }
    }
}

private struct AppLanguageEnvironmentKey: EnvironmentKey {
    static let defaultValue = AppLanguagePreference.automatic.resolvedLanguage()
}

extension EnvironmentValues {
    var appLanguage: SupportedAppLanguage {
        get { self[AppLanguageEnvironmentKey.self] }
        set { self[AppLanguageEnvironmentKey.self] = newValue }
    }
}

enum AppLocalization {
    static func string(
        _ key: String,
        language: SupportedAppLanguage,
        bundle: Bundle = .main
    ) -> String {
        guard let localizationURL = bundle.url(
            forResource: language.rawValue,
            withExtension: "lproj"
        ), let localizationBundle = Bundle(url: localizationURL) else {
            return key
        }

        return localizationBundle.localizedString(
            forKey: key,
            value: key,
            table: nil
        )
    }

    static func format(
        _ key: String,
        language: SupportedAppLanguage,
        arguments: CVarArg...
    ) -> String {
        String(
            format: string(key, language: language),
            locale: language.locale,
            arguments: arguments
        )
    }
}

enum MenuBarIconStyle: String, CaseIterable, Identifiable {
    case monochrome
    case color

    var id: Self { self }

    var title: String {
        switch self {
        case .monochrome:
            "Black & White"
        case .color:
            "Color"
        }
    }
}

enum AppAccentColor: String, CaseIterable, Identifiable {
    case system
    case red
    case orange
    case yellow
    case green
    case mint
    case teal
    case cyan
    case blue
    case indigo
    case purple
    case pink
    case brown

    private struct RGB {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat

        func makeNSColor() -> NSColor {
            NSColor(
                calibratedRed: red / 255,
                green: green / 255,
                blue: blue / 255,
                alpha: 1
            )
        }

        var relativeLuminance: CGFloat {
            func linearComponent(_ component: CGFloat) -> CGFloat {
                let normalized = component / 255
                return normalized <= 0.04045
                    ? normalized / 12.92
                    : pow((normalized + 0.055) / 1.055, 2.4)
            }

            return 0.2126 * linearComponent(red)
                + 0.7152 * linearComponent(green)
                + 0.0722 * linearComponent(blue)
        }

        static func contrastingForeground(for background: NSColor) -> NSColor {
            guard let rgbBackground = background.usingColorSpace(.sRGB) else {
                return .white
            }

            let color = RGB(
                red: rgbBackground.redComponent * 255,
                green: rgbBackground.greenComponent * 255,
                blue: rgbBackground.blueComponent * 255
            )
            return color.relativeLuminance > 0.38 ? .black : .white
        }
    }

    var id: Self { self }

    var title: String {
        switch self {
        case .system: "Automatic"
        default: rawValue.capitalized
        }
    }

    /// Uses macOS's system accent for the default. Custom choices use the
    /// increased-contrast light values consistently in every appearance.
    var color: Color {
        guard let rgb = increasedContrastColor else {
            return Color(nsColor: .controlAccentColor)
        }
        return Color(nsColor: rgb.makeNSColor())
    }

    var foregroundColor: Color {
        if let rgb = increasedContrastColor {
            return Color(nsColor: RGB.contrastingForeground(for: rgb.makeNSColor()))
        }

        let dynamicColor = NSColor(name: nil) { appearance in
            var background = NSColor.controlAccentColor
            appearance.performAsCurrentDrawingAppearance {
                background = NSColor.controlAccentColor
            }
            return RGB.contrastingForeground(for: background)
        }
        return Color(nsColor: dynamicColor)
    }

    private var increasedContrastColor: RGB? {
        switch self {
        case .system:
            nil
        case .red:
            RGB(red: 233, green: 21, blue: 45)
        case .orange:
            RGB(red: 197, green: 83, blue: 0)
        case .yellow:
            RGB(red: 161, green: 106, blue: 0)
        case .green:
            RGB(red: 0, green: 137, blue: 50)
        case .mint:
            RGB(red: 0, green: 133, blue: 117)
        case .teal:
            RGB(red: 0, green: 129, blue: 152)
        case .cyan:
            RGB(red: 0, green: 126, blue: 174)
        case .blue:
            RGB(red: 30, green: 110, blue: 244)
        case .indigo:
            RGB(red: 86, green: 74, blue: 222)
        case .purple:
            RGB(red: 176, green: 47, blue: 194)
        case .pink:
            RGB(red: 231, green: 18, blue: 77)
        case .brown:
            RGB(red: 149, green: 109, blue: 81)
        }
    }
}

enum PanelSize: String, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: Self { self }

    var title: String {
        switch self {
        case .small:
            "Small"
        case .medium:
            "Medium"
        case .large:
            "Large"
        }
    }

    var contentSize: CGSize {
        switch self {
        case .small:
            CGSize(width: 520, height: 600)
        case .medium:
            CGSize(width: 620, height: 720)
        case .large:
            CGSize(width: 720, height: 840)
        }
    }
}

@MainActor
final class AppPreferences: ObservableObject {
    private enum Key {
        static let menuBarIconStyle = "menuBarIconStyle"
        static let panelSize = "panelSize"
        static let displayLanguage = "displayLanguage"
        static let codeHighlightTheme = "codeHighlightTheme"
        static let accentColor = "accentColor"
        static let mcpServerEnabled = "mcpServerEnabled"
        static let mcpDeletionEnabled = "mcpDeletionEnabled"
    }

    private let defaults: UserDefaults

    @Published var menuBarIconStyle: MenuBarIconStyle {
        didSet {
            defaults.set(menuBarIconStyle.rawValue, forKey: Key.menuBarIconStyle)
        }
    }

    @Published var panelSize: PanelSize {
        didSet {
            defaults.set(panelSize.rawValue, forKey: Key.panelSize)
        }
    }

    @Published var displayLanguage: AppLanguagePreference {
        didSet {
            defaults.set(displayLanguage.rawValue, forKey: Key.displayLanguage)
        }
    }

    @Published var codeHighlightTheme: CodeHighlightTheme {
        didSet {
            defaults.set(codeHighlightTheme.rawValue, forKey: Key.codeHighlightTheme)
        }
    }

    @Published var accentColor: AppAccentColor {
        didSet {
            defaults.set(accentColor.rawValue, forKey: Key.accentColor)
        }
    }

    /// Controls whether a locally launched Agent may access the note library through MCP.
    @Published var mcpServerEnabled: Bool {
        didSet {
            defaults.set(mcpServerEnabled, forKey: Key.mcpServerEnabled)
        }
    }

    /// Controls whether a locally launched Agent may delete notes or tags through MCP.
    @Published var mcpDeletionEnabled: Bool {
        didSet {
            defaults.set(mcpDeletionEnabled, forKey: Key.mcpDeletionEnabled)
        }
    }

    var resolvedLanguage: SupportedAppLanguage {
        displayLanguage.resolvedLanguage()
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        menuBarIconStyle = defaults.string(forKey: Key.menuBarIconStyle)
            .flatMap(MenuBarIconStyle.init(rawValue:))
            ?? .color
        panelSize = defaults.string(forKey: Key.panelSize)
            .flatMap(PanelSize.init(rawValue:))
            ?? .medium
        displayLanguage = defaults.string(forKey: Key.displayLanguage)
            .flatMap(AppLanguagePreference.init(rawValue:))
            ?? .automatic
        codeHighlightTheme = defaults.string(forKey: Key.codeHighlightTheme)
            .flatMap(CodeHighlightTheme.init(rawValue:))
            ?? .github
        accentColor = defaults.string(forKey: Key.accentColor)
            .flatMap(AppAccentColor.init(rawValue:))
            ?? .system
        mcpServerEnabled = defaults.object(forKey: Key.mcpServerEnabled) as? Bool ?? true
        mcpDeletionEnabled = defaults.object(forKey: Key.mcpDeletionEnabled) as? Bool ?? false
    }

    static func isMCPServerEnabled(defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: Key.mcpServerEnabled) as? Bool ?? true
    }

    nonisolated static func selectedAccentColor(
        defaults: UserDefaults = .standard
    ) -> AppAccentColor {
        defaults.string(forKey: Key.accentColor)
            .flatMap(AppAccentColor.init(rawValue:))
            ?? .system
    }

    static func isMCPDeletionEnabled(defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: Key.mcpDeletionEnabled) as? Bool ?? false
    }
}
