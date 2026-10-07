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
    private let noteWindows: NoteEditorWindowManager
    private var globalClickMonitor: Any?
    private var iconStyleCancellable: AnyCancellable?
    private var panelSizeCancellable: AnyCancellable?

    init(
        viewModel: NotesViewModel,
        preferences: AppPreferences
    ) {
        self.viewModel = viewModel
        self.preferences = preferences
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()
        noteWindows = NoteEditorWindowManager(viewModel: viewModel, preferences: preferences)
        super.init()

        noteWindows.onWindowOpen = { [weak self] in
            self?.popover.performClose(nil)
        }
        noteWindows.onWindowCountChange = { count in
            NSApp.setActivationPolicy(count > 0 ? .regular : .accessory)
        }

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
            rootView: LocalizedAppContent(
                viewModel: viewModel,
                preferences: preferences,
                noteWindows: noteWindows
            )
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

    func popoverWillShow(_ notification: Notification) {
        viewModel.setPanelPresented(true)
    }

    func popoverDidClose(_ notification: Notification) {
        viewModel.setPanelPresented(false)
        viewModel.showAddNote = false
        viewModel.showAbout = false
    }
}

private struct LocalizedAppContent: View {
    @ObservedObject var viewModel: NotesViewModel
    @ObservedObject var preferences: AppPreferences
    let noteWindows: NoteEditorWindowManager

    var body: some View {
        let language = preferences.resolvedLanguage
        ContentView()
            .environmentObject(viewModel)
            .environmentObject(preferences)
            .environment(\.noteEditorWindows, noteWindows)
            .environment(\.locale, language.locale)
            .environment(\.appLanguage, language)
            .environment(\.codeHighlightTheme, preferences.codeHighlightTheme)
            .id(language)
    }
}

struct NoteEditorDraft {
    var title = ""
    var content = ""
    var tags: Set<String> = []
    var renderingMode: NoteRenderingMode = .automatic

    init(title: String = "", content: String = "", tags: Set<String> = [],
         renderingMode: NoteRenderingMode = .automatic) {
        self.title = title
        self.content = content
        self.tags = tags
        self.renderingMode = renderingMode
    }

    init(note: Note) {
        self.init(
            title: note.title ?? "",
            content: note.content,
            tags: Set(note.tags),
            renderingMode: note.renderingMode == .code(.automatic) ? .automatic : note.renderingMode
        )
    }
}

private struct NoteEditorWindowsKey: EnvironmentKey {
    static let defaultValue: NoteEditorWindowManager? = nil
}

extension EnvironmentValues {
    var noteEditorWindows: NoteEditorWindowManager? {
        get { self[NoteEditorWindowsKey.self] }
        set { self[NoteEditorWindowsKey.self] = newValue }
    }
}

@MainActor
final class NoteEditorWindowManager: NSObject, NSWindowDelegate {
    static let defaultSize = NSSize(width: 640, height: 560)
    static let minimumSize = NSSize(width: 500, height: 460)
    static let detachedWindowStyleMask: NSWindow.StyleMask = [
        .titled, .resizable, .fullSizeContentView
    ]

    static func level(isPinned: Bool) -> NSWindow.Level {
        isPinned ? .floating : .normal
    }

    static func displayTitle(
        baseKey: String,
        noteTitle: String?,
        language: SupportedAppLanguage
    ) -> String {
        let baseTitle = AppLocalization.string(baseKey, language: language)
        guard let noteTitle else { return baseTitle }
        let trimmedTitle = noteTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return baseTitle }

        let preview = String(trimmedTitle.prefix(10))
        let ellipsis = trimmedTitle.count > 10 ? "..." : ""
        return "\(baseTitle) - \(preview)\(ellipsis)"
    }

    private let viewModel: NotesViewModel
    private let preferences: AppPreferences
    private var windows: [UUID: NSWindow] = [:]

    init(viewModel: NotesViewModel, preferences: AppPreferences) {
        self.viewModel = viewModel
        self.preferences = preferences
    }

    func openNew(draft: NoteEditorDraft = NoteEditorDraft()) {
        let id = UUID()
        let pin = pinBinding(for: id)
        let content = AddNoteView(
            language: preferences.resolvedLanguage,
            draft: draft,
            closeAction: { [weak self] in self?.close(id) },
            windowPin: pin
        )
        showWindow(id: id, title: Self.displayTitle(baseKey: "New Note", noteTitle: nil, language: preferences.resolvedLanguage), content: content)
    }

    func openEdit(note: Note, draft: NoteEditorDraft? = nil) {
        let id = UUID()
        let pin = pinBinding(for: id)
        let content = EditNoteSheet(
            note: note,
            availableTags: viewModel.tags,
            isPresented: Binding(
                get: { [weak self] in self?.windows[id] != nil },
                set: { [weak self] presented in if !presented { self?.close(id) } }
            ),
            language: preferences.resolvedLanguage,
            onSave: { [weak self] note, title, content, tags, renderingMode in
                self?.viewModel.updateNote(
                    note, title: title, content: content, tags: tags,
                    renderingMode: renderingMode
                ) ?? false
            },
            draft: draft,
            windowPin: pin
        )
        showWindow(
            id: id,
            title: Self.displayTitle(
                baseKey: "Edit Note",
                noteTitle: note.title,
                language: preferences.resolvedLanguage
            ),
            content: content
        )
    }

    private func pinBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { [weak self] in self?.windows[id]?.level == .floating },
            set: { [weak self] pinned in
                guard let window = self?.windows[id] else { return }
                window.level = Self.level(isPinned: pinned)
                window.collectionBehavior = pinned ? [.canJoinAllSpaces, .fullScreenAuxiliary] : []
            }
        )
    }

    private func showWindow<Content: View>(id: UUID, title: String, content: Content) {
        let language = preferences.resolvedLanguage
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
            styleMask: Self.detachedWindowStyleMask,
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].forEach { buttonType in
            window.standardWindowButton(buttonType)?.isHidden = true
        }
        window.minSize = Self.minimumSize
        window.level = Self.level(isPinned: true)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentViewController = NSHostingController(
            rootView: content
                .environmentObject(viewModel)
                .environmentObject(preferences)
                .environment(\.appLanguage, language)
                .environment(\.locale, language.locale)
                .environment(\.codeHighlightTheme, preferences.codeHighlightTheme)
        )
        windows[id] = window
        onWindowOpen?()
        onWindowCountChange?(windows.count)
        window.setContentSize(Self.defaultSize)
        window.center()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func close(_ id: UUID) {
        windows[id]?.close()
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow else { return }
        windows = windows.filter { $0.value !== closingWindow }
        onWindowCountChange?(windows.count)
    }

    var onWindowCountChange: ((Int) -> Void)?
    var onWindowOpen: (() -> Void)?
}
