import Combine
import Foundation

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

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        menuBarIconStyle = defaults.string(forKey: Key.menuBarIconStyle)
            .flatMap(MenuBarIconStyle.init(rawValue:))
            ?? .color
        panelSize = defaults.string(forKey: Key.panelSize)
            .flatMap(PanelSize.init(rawValue:))
            ?? .small
    }
}
