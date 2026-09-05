import AppKit
import Combine
import SwiftUI

@MainActor
enum MenuBarIconRenderer {
    private static let iconSize = NSSize(width: 18, height: 18)

    static func makeIcon(style: MenuBarIconStyle) -> NSImage? {
        let bundledIcon = Bundle.main
            .url(forResource: resourceName(for: style), withExtension: "png")
            .flatMap(NSImage.init(contentsOf:))
        guard let image = (bundledIcon ?? NSApp.applicationIconImage)?.copy() as? NSImage else {
            return nil
        }

        image.size = iconSize
        image.isTemplate = usesTemplateRendering(for: style)
        image.accessibilityDescription = "Quick Notes"
        return image
    }

    static func usesTemplateRendering(for style: MenuBarIconStyle) -> Bool {
        style == .monochrome
    }

    static func resourceName(for style: MenuBarIconStyle) -> String {
        switch style {
        case .monochrome:
            "MenuBarIcon@black"
        case .color:
            "MenuBarIcon@color"
        }
    }
}

@MainActor
final class MenuBarController: NSObject, ObservableObject, NSPopoverDelegate {
    private let viewModel: NotesViewModel
    private let preferences: AppPreferences
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var globalClickMonitor: Any?
    private var iconStyleCancellable: AnyCancellable?
    private var panelSizeCancellable: AnyCancellable?

    init(viewModel: NotesViewModel, preferences: AppPreferences) {
        self.viewModel = viewModel
        self.preferences = preferences
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()
        super.init()

        configureStatusItem()
        configurePopover()
        observePreferences()
        observeApplicationLifecycle()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        updateStatusItemIcon(style: preferences.menuBarIconStyle)
        button.imageScaling = .scaleProportionallyDown
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(togglePopover)
        button.toolTip = "Quick Notes"
    }

    private func configurePopover() {
        let contentSize = preferences.panelSize.contentSize
        popover.contentSize = contentSize
        popover.behavior = .applicationDefined
        popover.animates = true
        popover.delegate = self
        let hostingController = NSHostingController(
            rootView: ContentView()
                .environmentObject(viewModel)
                .environmentObject(preferences)
        )
        hostingController.preferredContentSize = contentSize
        popover.contentViewController = hostingController
    }

    private func observePreferences() {
        iconStyleCancellable = preferences.$menuBarIconStyle
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] newStyle in
                self?.updateStatusItemIcon(style: newStyle)
            }

        panelSizeCancellable = preferences.$panelSize
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] newSize in
                DispatchQueue.main.async { [weak self] in
                    self?.updatePopoverSize(newSize)
                }
            }
    }

    private func updateStatusItemIcon(style: MenuBarIconStyle) {
        guard let button = statusItem.button else { return }
        button.image = nil
        button.image = MenuBarIconRenderer.makeIcon(style: style)
        button.needsDisplay = true
    }

    private func updatePopoverSize(_ panelSize: PanelSize) {
        let contentSize = panelSize.contentSize
        popover.contentViewController?.preferredContentSize = contentSize
        popover.contentSize = contentSize
    }

    private func observeApplicationLifecycle() {
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in
                self?.closePopoverUnlessPresentingModal()
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
            return
        }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate()

        DispatchQueue.main.async { [weak self] in
            guard let window = self?.popover.contentViewController?.view.window else { return }
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func applicationDidResignActive() {
        closePopoverUnlessPresentingModal()
    }

    private func closePopoverUnlessPresentingModal() {
        guard popover.isShown, !isPresentingModal else { return }
        popover.performClose(nil)
    }

    private var isPresentingModal: Bool {
        guard let popoverWindow = popover.contentViewController?.view.window else { return false }
        if popoverWindow.attachedSheet != nil { return true }

        return NSApp.windows.contains { window in
            window.isVisible && window.sheetParent === popoverWindow
        }
    }

    func popoverDidClose(_ notification: Notification) {
        viewModel.showAddNote = false
        viewModel.showAbout = false
    }
}
