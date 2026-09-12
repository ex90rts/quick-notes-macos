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
    }
}
