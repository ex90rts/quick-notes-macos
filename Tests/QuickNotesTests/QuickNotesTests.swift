import AppKit
import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import QuickNotes

@Suite("Quick Notes core behavior")
struct QuickNotesTests {
    @Test("Add Note sheet starts with the content editor focused")
    @MainActor
    func addNoteInitialFocus() throws {
        let viewModel = try NotesViewModel(
            repository: makeRepository(),
            clipboardRepository: makeClipboardRepository(),
            monitorsClipboard: false
        )
        let controller = NSHostingController(
            rootView: AddNoteFocusTestHost(viewModel: viewModel)
        )
        let parentWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        parentWindow.contentViewController = controller
        parentWindow.makeKeyAndOrderFront(nil)
        defer { parentWindow.close() }

        let presentationDeadline = Date().addingTimeInterval(1)
        while parentWindow.attachedSheet == nil, Date() < presentationDeadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }

        let sheet = try #require(parentWindow.attachedSheet)
        let focusDeadline = Date().addingTimeInterval(1)
        while !(sheet.firstResponder is NSTextView), Date() < focusDeadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }

        let focusedTextView = try #require(sheet.firstResponder as? NSTextView)
        #expect(!focusedTextView.isFieldEditor)
    }

    @Test("Menu bar icon preference defaults to color and persists changes")
    @MainActor
    func menuBarIconPreference() throws {
        let suiteName = "QuickNotesTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let initialPreferences = AppPreferences(defaults: defaults)
        #expect(initialPreferences.menuBarIconStyle == .color)
        #expect(initialPreferences.panelSize == .medium)
        #expect(initialPreferences.displayLanguage == .automatic)
        #expect(PanelSize.small.contentSize == CGSize(width: 520, height: 600))

        initialPreferences.menuBarIconStyle = .monochrome
        initialPreferences.panelSize = .large
        initialPreferences.displayLanguage = .traditionalChinese
        let restoredPreferences = AppPreferences(defaults: defaults)
        #expect(restoredPreferences.menuBarIconStyle == .monochrome)
        #expect(restoredPreferences.panelSize == .large)
        #expect(restoredPreferences.displayLanguage == .traditionalChinese)
        #expect(PanelSize.medium.contentSize == CGSize(width: 620, height: 720))
        #expect(restoredPreferences.panelSize.contentSize == CGSize(width: 720, height: 840))
    }

    @Test("Automatic display language matches supported system languages")
    func automaticDisplayLanguageResolution() {
        #expect(
            AppLanguagePreference.automatic.resolvedLanguage(
                preferredLanguages: ["zh-Hans-CN"]
            ) == .simplifiedChinese
        )
        #expect(
            AppLanguagePreference.automatic.resolvedLanguage(
                preferredLanguages: ["zh-TW"]
            ) == .traditionalChinese
        )
        #expect(
            AppLanguagePreference.automatic.resolvedLanguage(
                preferredLanguages: ["zh-Hant-HK"]
            ) == .traditionalChinese
        )
        #expect(
            AppLanguagePreference.automatic.resolvedLanguage(
                preferredLanguages: ["en-US"]
            ) == .englishUS
        )
        #expect(
            AppLanguagePreference.automatic.resolvedLanguage(
                preferredLanguages: ["fr-FR", "zh-Hans"]
            ) == .englishUS
        )
        #expect(
            AppLanguagePreference.automatic.resolvedLanguage(
                preferredLanguages: []
            ) == .englishUS
        )
    }

    @Test("Explicit display languages override the system language")
    func explicitDisplayLanguageResolution() {
        #expect(
            AppLanguagePreference.simplifiedChinese.resolvedLanguage(
                preferredLanguages: ["en-US"]
            ) == .simplifiedChinese
        )
        #expect(
            AppLanguagePreference.traditionalChinese.resolvedLanguage(
                preferredLanguages: ["en-US"]
            ) == .traditionalChinese
        )
        #expect(
            AppLanguagePreference.englishUS.resolvedLanguage(
                preferredLanguages: ["zh-CN"]
            ) == .englishUS
        )
    }

    @Test("App sheet keeps its explicitly supplied display language")
    @MainActor
    func appSheetLanguageContext() {
        let sheet = AppSheet(
            title: "About",
            language: .traditionalChinese,
            minHeight: 120,
            closeAction: {}
        ) {
            EmptyView()
        }

        #expect(sheet.language == .traditionalChinese)
        #expect(sheet.language.locale.identifier == "zh-Hant")
    }

    @Test("Every supported language ships the same localization keys")
    func localizationResourcesAreComplete() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let resourcesRoot = projectRoot.appendingPathComponent("Resources")

        func strings(for language: SupportedAppLanguage) throws -> [String: String] {
            let url = resourcesRoot
                .appendingPathComponent("\(language.rawValue).lproj")
                .appendingPathComponent("Localizable.strings")
            let data = try Data(contentsOf: url)
            return try #require(
                PropertyListSerialization.propertyList(from: data, format: nil)
                    as? [String: String]
            )
        }

        let english = try strings(for: .englishUS)
        let simplifiedChinese = try strings(for: .simplifiedChinese)
        let traditionalChinese = try strings(for: .traditionalChinese)

        #expect(Set(english.keys) == Set(simplifiedChinese.keys))
        #expect(Set(english.keys) == Set(traditionalChinese.keys))
        #expect(simplifiedChinese["Display Language"] == "显示语言")
        #expect(traditionalChinese["Display Language"] == "顯示語言")
        #expect(english["Display Language"] == "Display Language")
        #expect(simplifiedChinese["Quick Notes"] == "快记")
        #expect(traditionalChinese["Quick Notes"] == "快记")
        #expect(english["Quick Notes"] == "Quick Notes")
        #expect(simplifiedChinese["Automatic"] == "跟随系统")
        #expect(traditionalChinese["Automatic"] == "跟隨系統")
        #expect(english["Automatic"] == "Follow System")
        #expect(simplifiedChinese["Adjust the panel size."] == "调整面板大小。")
    }

    @Test("Menu bar icon styles use their supplied image resources")
    @MainActor
    func menuBarIconResources() {
        #expect(MenuBarIconRenderer.resourceName(for: .monochrome) == "MenuBarIcon@black")
        #expect(MenuBarIconRenderer.resourceName(for: .color) == "MenuBarIcon@color")
        #expect(MenuBarIconRenderer.usesTemplateRendering(for: .monochrome))
        #expect(!MenuBarIconRenderer.usesTemplateRendering(for: .color))
    }

    @Test("Content is trimmed without flattening intentional paragraphs")
    func contentSanitization() {
        let input = "  First line   \n\n\n\nSecond line\t  "
        #expect(ContentSanitizer.sanitize(input) == "First line\n\nSecond line")
    }

    @Test("Note content is limited to 2000 characters")
    func noteContentLengthLimit() {
        let maximumLengthContent = String(repeating: "a", count: 2_000)
        let overLimitContent = maximumLengthContent + "b"

        #expect(NoteContentPolicy.maximumCharacterCount == 2_000)
        #expect(NoteContentPolicy.canSave(maximumLengthContent))
        #expect(!NoteContentPolicy.canSave(overLimitContent))
        #expect(!NoteContentPolicy.canSave("  \n "))
    }

    @Test("Optional titles are trimmed and blank titles are omitted")
    func titleSanitization() {
        #expect(TitleSanitizer.sanitize("  Project plan  ") == "Project plan")
        #expect(TitleSanitizer.sanitize(" \n\t ") == nil)
    }

    @Test("Complete HTTP and HTTPS links are extracted from surrounding text")
    func noteContentLinks() {
        #expect(NoteContentLink.url(from: "https://example.com/path?q=notes")?.absoluteString == "https://example.com/path?q=notes")
        #expect(NoteContentLink.url(from: "  http://localhost:8080/note  ")?.absoluteString == "http://localhost:8080/note")
        #expect(NoteContentLink.url(from: "See https://example.com")?.absoluteString == "https://example.com")
        #expect(NoteContentLink.url(from: "https://example.com trailing")?.absoluteString == "https://example.com")
        #expect(NoteContentLink.url(from: "example.com") == nil)
        #expect(NoteContentLink.url(from: "file:///tmp/note") == nil)
        #expect(NoteContentLink.url(from: "https:///missing-host") == nil)

        let content = "See https://example.com/a, then http://localhost:8080/note."
        let extractedLinks = NoteContentLink.matches(in: content)
        #expect(extractedLinks.map { String(content[$0.range]) } == [
            "https://example.com/a",
            "http://localhost:8080/note"
        ])
    }

    @Test("Markdown content recognizes custom todos and aligned tables")
    func markdownContentBlocks() {
        let content = """
        # Plan
        [] **Draft** the proposal
        [-] Review https://example.com/spec

        | Item | Owner | Score |
        | :--- | :---: | ---: |
        | UI | Amy | 9 |
        | API | Bo | 8 |
        """

        let blocks = NoteContentParser.blocks(from: content)
        #expect(blocks.count == 4)
        #expect(blocks[0] == .heading(level: 1, text: "Plan"))
        #expect(blocks[1] == .todo(NoteTodoItem(
            lineIndex: 1,
            text: "**Draft** the proposal",
            isCompleted: false
        )))
        #expect(blocks[2] == .todo(NoteTodoItem(
            lineIndex: 2,
            text: "Review https://example.com/spec",
            isCompleted: true
        )))

        guard case .table(let table) = blocks[3] else {
            Issue.record("Expected the final Markdown block to be a table")
            return
        }
        #expect(table.headers == ["Item", "Owner", "Score"])
        #expect(table.alignments == [.leading, .center, .trailing])
        #expect(table.rows == [["UI", "Amy", "9"], ["API", "Bo", "8"]])
    }

    @Test("Markdown content recognizes all basic block syntax")
    func basicMarkdownBlocks() {
        let content = """
        # Primary heading

        Secondary heading
        ---

        Paragraph with **bold**, *italic*, `code`, and [a link](https://example.com).

        > A quoted **sentence**.
        > A second line.

        - First bullet
          - Nested bullet

        3. Third item
        4. Fourth item

        ***

        ```swift
        let answer = 42
        print(answer)
        ```
        """

        let blocks = NoteContentParser.blocks(from: content)
        #expect(blocks.count == 8)
        #expect(blocks[0] == .heading(level: 1, text: "Primary heading"))
        #expect(blocks[1] == .heading(level: 2, text: "Secondary heading"))
        #expect(blocks[2] == .paragraph(
            "Paragraph with **bold**, *italic*, `code`, and [a link](https://example.com)."
        ))
        #expect(blocks[3] == .blockQuote("A quoted **sentence**.\nA second line."))
        #expect(blocks[4] == .list(NoteMarkdownList(
            isOrdered: false,
            startingNumber: 1,
            items: [
                NoteMarkdownListItem(text: "First bullet", indentationLevel: 0),
                NoteMarkdownListItem(text: "Nested bullet", indentationLevel: 1)
            ]
        )))
        #expect(blocks[5] == .list(NoteMarkdownList(
            isOrdered: true,
            startingNumber: 3,
            items: [
                NoteMarkdownListItem(text: "Third item", indentationLevel: 0),
                NoteMarkdownListItem(text: "Fourth item", indentationLevel: 0)
            ]
        )))
        #expect(blocks[6] == .thematicBreak)
        #expect(blocks[7] == .codeBlock(NoteMarkdownCodeBlock(
            language: "swift",
            code: "let answer = 42\nprint(answer)"
        )))
    }

    @Test("Todo toggles only replace the selected line marker")
    func todoContentToggling() {
        let content = "  [] First\n[-] Second\nPlain text\n"
        let completed = NoteTodo.togglingItem(in: content, at: 0)
        #expect(completed == "  [-] First\n[-] Second\nPlain text\n")
        guard let completed else { return }
        #expect(NoteTodo.togglingItem(in: completed, at: 1) == "  [-] First\n[] Second\nPlain text\n")
        #expect(NoteTodo.togglingItem(in: content, at: 2) == nil)
        #expect(NoteTodo.item(from: "[]missing-space", lineIndex: 0) == nil)
    }

    @Test("Only top-level JSON objects and arrays use formatted JSON rendering")
    func jsonContentDetection() {
        let object = NoteJSON.formattedString(
            from: #" {"z":1,"markdown":"**bold**","url":"https://example.com/a"} "#
        )
        #expect(object?.contains("\n") == true)
        #expect(object?.contains(#""url" : "https://example.com/a""#) == true)
        #expect(object?.first == "{")
        #expect(NoteJSON.formattedString(from: #"[true,null,{"a":2}]"#) != nil)
        #expect(NoteJSON.formattedString(from: #""plain JSON string""#) == nil)
        #expect(NoteJSON.formattedString(from: "123") == nil)
        #expect(NoteJSON.formattedString(from: "{not JSON}") == nil)
        #expect(NoteJSON.formattedString(from: "```json\n{}\n```") == nil)
    }

    @Test("Virtual note windows keep five items above and below the viewport")
    func virtualNoteWindow() {
        let itemHeights = Array(repeating: CGFloat(100), count: 100)
        let window = NoteListVirtualizer.window(
            itemHeights: itemHeights,
            spacing: 8,
            visibleRange: 1_080..<1_300,
            overscan: 5
        )

        #expect(window.range == 5..<18)
        #expect(window.leadingHeight == 540)
        #expect(window.trailingHeight == 8_856)

        let renderedHeight = itemHeights[window.range].reduce(0, +)
            + CGFloat(window.range.count - 1) * 8
        #expect(window.leadingHeight + renderedHeight + window.trailingHeight == 10_792)
    }

    @Test("Virtual note windows preserve total height with mixed row heights")
    func mixedHeightVirtualNoteWindow() {
        let itemHeights: [CGFloat] = [80, 140, 96, 180, 72, 124, 160]
        let spacing: CGFloat = 8
        let window = NoteListVirtualizer.window(
            itemHeights: itemHeights,
            spacing: spacing,
            visibleRange: 240..<430,
            overscan: 1
        )
        let renderedHeight = itemHeights[window.range].reduce(0, +)
            + CGFloat(max(window.range.count - 1, 0)) * spacing
        let totalHeight = itemHeights.reduce(0, +)
            + CGFloat(itemHeights.count - 1) * spacing

        #expect(window.range == 1..<5)
        #expect(window.leadingHeight + renderedHeight + window.trailingHeight == totalHeight)
    }

    @Test("Back to top appears after entering the second viewport")
    func scrollToTopThreshold() {
        #expect(!ScrollToTopBehavior.shouldShow(scrollOffset: 300, viewportHeight: 300))
        #expect(ScrollToTopBehavior.shouldShow(scrollOffset: 301, viewportHeight: 300))
        #expect(!ScrollToTopBehavior.shouldShow(scrollOffset: -20, viewportHeight: 300))
        #expect(!ScrollToTopBehavior.shouldShow(scrollOffset: 301, viewportHeight: 0))
    }

    @Test("Collapsed note content renders up to 120 points including padding")
    func collapsedNoteContentHeight() {
        #expect(NoteContentLayout.collapsedViewportHeight == 100)
        #expect(NoteContentLayout.containerPadding == 10)
        #expect(NoteContentLayout.collapsedContainerHeight == 120)
    }

    @Test("Single-line tag and search filters share the same height")
    func notesFilterBarHeight() {
        #expect(NotesFilterBarLayout.controlHeight == 28)
        #expect(NotesFilterBarLayout.verticalPadding == 10)
        #expect(NotesFilterBarLayout.singleLineHeight == 48)
        #expect(NotesFilterBarLayout.shadowHeight == 10)
    }

    @Test("Note actions and Settings dividers use the intended visual metrics")
    func refinedSettingsAndNoteCardMetrics() {
        #expect(HeaderMenuBehavior.clipboardRefreshMilliseconds == 500)
        #expect(HeaderActionLayout.labelSpacing == 6)
        #expect(HeaderActionLayout.horizontalPadding == 10)
        #expect(HeaderActionLayout.iconFontSize == 12)
        #expect(HeaderActionLayout.labelFontSize == 12)
        #expect(NoteCardLayout.actionIconSize == 14)
        #expect(NoteCardLayout.actionHoverPadding == 4)
        #expect(NoteCardLayout.actionHorizontalMargin == 2)
        #expect(NoteCardLayout.actionHoverCornerRadius == 5)
        #expect(NoteRenderingMenuLayout.fontSize == 12)
        #expect(NoteRenderingMenuLayout.itemWidth == 156)
        #expect(NoteRenderingMenuLayout.itemHeight == 24)
        #expect(NoteRenderingMenuLayout.selectionWidth == 156)
        #expect(NoteRenderingMenuLayout.indicatorFontSize == 8)
        #expect(AppControlMetrics.formControlHeight == 30)
        #expect(AppControlMetrics.editorMetadataSpacing == 1)
        #expect(SettingsDividerMetrics.dashPattern == [4, 3])
        #expect(NoteDeletionAnimationMetrics.dissolveDuration == 0.34)
        #expect(NoteDeletionAnimationMetrics.particleCount == 112)
        #expect(NoteDeletionAnimationMetrics.maximumBlurRadius == 4)
        #expect(NoteDeletionAnimationMetrics.horizontalDrift == 18)
        #expect(NoteAttentionAnimationMetrics.pulseCount == 2)
        #expect(NoteAttentionAnimationMetrics.standardLifetimeMilliseconds == 820)
    }

    @Test("Clipboard quick add accepts only text that can be saved as a note")
    func clipboardQuickAddContent() {
        #expect(ClipboardQuickAddContent.sanitizedText(from: nil) == nil)
        #expect(ClipboardQuickAddContent.sanitizedText(from: " \n\t ") == nil)
        #expect(
            ClipboardQuickAddContent.sanitizedText(from: "  First line  \nSecond line  ")
                == "First line\nSecond line"
        )
        #expect(
            ClipboardQuickAddContent.sanitizedText(
                from: String(repeating: "a", count: NoteContentPolicy.maximumCharacterCount + 1)
            ) == nil
        )
    }

    @Test("Clipboard quick add recognizes only an unrepeated Command-V shortcut")
    func clipboardQuickAddShortcut() {
        #expect(PasteShortcutBehavior.matches(
            charactersIgnoringModifiers: "v",
            modifierFlags: .command,
            isRepeat: false
        ))
        #expect(PasteShortcutBehavior.matches(
            charactersIgnoringModifiers: "V",
            modifierFlags: .command,
            isRepeat: false
        ))
        #expect(!PasteShortcutBehavior.matches(
            charactersIgnoringModifiers: "v",
            modifierFlags: [],
            isRepeat: false
        ))
        #expect(!PasteShortcutBehavior.matches(
            charactersIgnoringModifiers: "v",
            modifierFlags: [.command, .shift],
            isRepeat: false
        ))
        #expect(!PasteShortcutBehavior.matches(
            charactersIgnoringModifiers: "v",
            modifierFlags: .command,
            isRepeat: true
        ))
    }

    @Test("Notes filter bar shadow appears only after scrolling more than 10 points")
    func notesFilterBarShadowThreshold() {
        #expect(!NotesFilterBarShadowBehavior.shouldShow(scrollOffset: -1))
        #expect(!NotesFilterBarShadowBehavior.shouldShow(scrollOffset: 0))
        #expect(!NotesFilterBarShadowBehavior.shouldShow(scrollOffset: 10))
        #expect(NotesFilterBarShadowBehavior.shouldShow(scrollOffset: 10.1))
    }

    @Test("Saving a link automatically applies an available Link tag")
    @MainActor
    func automaticLinkTag() throws {
        let repository = try makeRepository()
        try repository.insertTag("Work")
        try repository.insertTag("Link")
        let viewModel = try NotesViewModel(
            repository: repository,
            clipboardRepository: makeClipboardRepository(),
            monitorsClipboard: false
        )

        viewModel.addNote(
            content: "Read https://example.com/new before tomorrow",
            tags: ["Work"]
        )
        let addedNote = try #require(viewModel.notes.first)
        #expect(addedNote.tags == ["Work", "Link"])

        viewModel.addNoteFromClipboard(
            content: "https://example.com/clipboard",
            tags: []
        )
        let clipboardNote = try #require(viewModel.notes.first {
            $0.content == "https://example.com/clipboard"
        })
        #expect(clipboardNote.tags == ["Link", viewModel.clipboardTag])

        viewModel.updateNote(
            addedNote,
            title: "",
            content: "Edited text with https://example.com/edited inside",
            tags: [],
            renderingMode: .markdown
        )
        let editedNote = try #require(viewModel.notes.first { $0.id == addedNote.id })
        #expect(editedNote.tags == ["Link"])
    }

    @Test("Toggling a rendered todo persists immediately without changing note metadata")
    @MainActor
    func persistedTodoToggle() throws {
        let note = Note(
            id: UUID(),
            title: "Plan",
            content: "[] First\n[-] Second",
            tags: ["Work"],
            timestamp: Date(timeIntervalSince1970: 100),
            isPinned: true,
            expanded: true
        )
        let repository = CountingNotesRepository(notes: [note], tags: ["Work"])
        let viewModel = try NotesViewModel(
            repository: repository,
            clipboardRepository: makeClipboardRepository(),
            monitorsClipboard: false
        )

        viewModel.toggleTodo(in: note, at: 0)

        let updatedNote = try #require(viewModel.notes.first)
        #expect(updatedNote.content == "[-] First\n[-] Second")
        #expect(updatedNote.title == note.title)
        #expect(updatedNote.tags == note.tags)
        #expect(updatedNote.timestamp == note.timestamp)
        #expect(updatedNote.isPinned)
        #expect(updatedNote.expanded)
        #expect(repository.notes.first?.content == updatedNote.content)
    }

    @Test("A link is not tagged when no Link tag exists")
    @MainActor
    func unavailableLinkTag() throws {
        let repository = try makeRepository()
        let viewModel = try NotesViewModel(
            repository: repository,
            clipboardRepository: makeClipboardRepository(),
            monitorsClipboard: false
        )
        viewModel.addNote(content: "https://example.com", tags: [])
        #expect(viewModel.notes.first?.tags == [])
    }

    @Test("SwiftData repository persists independent notes and tags")
    @MainActor
    func repositoryRoundTrip() throws {
        let repository = try makeRepository()
        let note = Note(
            id: UUID(),
            title: "Persisted title",
            content: "A persisted note",
            tags: ["Work"],
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            isPinned: true,
            renderingMode: .code(.swift),
            expanded: true
        )

        try repository.insertTag("Work")
        try repository.insertNote(note)

        #expect(try repository.fetchTags() == ["Work"])
        let storedNote = try #require(repository.fetchNotes().first)
        #expect(storedNote.id == note.id)
        #expect(storedNote.title == note.title)
        #expect(storedNote.content == note.content)
        #expect(storedNote.tags == note.tags)
        #expect(storedNote.timestamp == note.timestamp)
        #expect(storedNote.isPinned)
        #expect(storedNote.renderingMode == .code(.swift))
        #expect(!storedNote.expanded)
    }

    @Test("Pinned notes persist, sort first, and stop at three")
    @MainActor
    func pinnedNotes() throws {
        let repository = try makeRepository()
        for timestamp in 1...4 {
            try repository.insertNote(
                Note(
                    id: UUID(),
                    content: "Note \(timestamp)",
                    tags: [],
                    timestamp: Date(timeIntervalSince1970: TimeInterval(timestamp)),
                    expanded: false
                )
            )
        }

        let viewModel = try NotesViewModel(
            repository: repository,
            clipboardRepository: makeClipboardRepository(),
            monitorsClipboard: false
        )
        let notesToPin = Array(viewModel.notes.prefix(3))
        for note in notesToPin {
            viewModel.togglePin(note)
        }

        #expect(viewModel.notes.prefix(3).allSatisfy { $0.isPinned })
        let remainingNote = try #require(viewModel.notes.first { !$0.isPinned })
        #expect(!viewModel.canTogglePin(for: remainingNote))
        viewModel.togglePin(remainingNote)
        #expect(!viewModel.notes.first { $0.id == remainingNote.id }!.isPinned)

        let pinnedNote = try #require(viewModel.notes.first { $0.isPinned })
        viewModel.togglePin(pinnedNote)
        #expect(viewModel.canTogglePin(for: remainingNote))
        viewModel.togglePin(remainingNote)

        let persistedNotes = try repository.fetchNotes()
        #expect(persistedNotes.prefix(3).allSatisfy { $0.isPinned })
        #expect(persistedNotes.map(\.content) == ["Note 3", "Note 2", "Note 1", "Note 4"])
    }

    @Test("SwiftData records survive reopening the persistent store")
    @MainActor
    func persistentStoreReopens() throws {
        try withTemporaryDirectory { directory in
            let storeURL = directory.appendingPathComponent("QuickNotes.store")
            let noteID = UUID()

            do {
                let repository = try makeRepository(storeURL: storeURL)
                try repository.insertTag("Work")
                try repository.insertNote(
                    Note(
                        id: noteID,
                        content: "Persisted across containers",
                        tags: ["Work"],
                        timestamp: Date(timeIntervalSince1970: 100),
                        expanded: false
                    )
                )
            }

            let reopenedRepository = try makeRepository(storeURL: storeURL)
            #expect(try reopenedRepository.fetchTags() == ["Work"])
            #expect(try reopenedRepository.fetchNotes().map(\.id) == [noteID])
        }
    }

    @Test("Removing a managed tag also removes it from notes")
    @MainActor
    func tagRemoval() throws {
        let repository = try makeRepository()
        let note = Note(
            id: UUID(),
            content: "Tagged note",
            tags: ["Work", "Personal"],
            timestamp: .now,
            expanded: false
        )
        try repository.insertTag("Work")
        try repository.insertTag("Personal")
        try repository.insertNote(note)

        try repository.deleteTag("Work")

        #expect(try repository.fetchTags() == ["Personal"])
        #expect(try repository.fetchNotes().first?.tags == ["Personal"])
    }

    @Test("Search matches titles and content while preserving tag filters")
    @MainActor
    func noteSearch() throws {
        let repository = try makeRepository()
        let titleMatch = Note(
            id: UUID(),
            title: "Résumé plan",
            content: "Prepare milestones",
            tags: ["Work"],
            timestamp: Date(timeIntervalSince1970: 20),
            expanded: false
        )
        let contentMatch = Note(
            id: UUID(),
            content: "Review the project plan",
            tags: ["Personal"],
            timestamp: Date(timeIntervalSince1970: 10),
            expanded: false
        )
        try repository.insertTag("Work")
        try repository.insertTag("Personal")
        try repository.insertNote(titleMatch)
        try repository.insertNote(contentMatch)

        let viewModel = try NotesViewModel(
            repository: repository,
            clipboardRepository: makeClipboardRepository(),
            monitorsClipboard: false
        )
        viewModel.searchQuery = "resume"
        #expect(viewModel.filteredNotes.map(\.id) == [titleMatch.id])

        viewModel.searchQuery = "plan"
        #expect(viewModel.filteredNotes.count == 2)

        viewModel.selectedTagFilter = "Personal"
        #expect(viewModel.filteredNotes.map(\.id) == [contentMatch.id])

        viewModel.searchQuery = "p"
        #expect(viewModel.filteredNotes.map(\.id) == [contentMatch.id])
    }

    @Test("Clipboard notes preserve an optional title and automatically add the Clipboard tag")
    @MainActor
    func clipboardNoteTitle() throws {
        let repository = try makeRepository()
        let viewModel = try NotesViewModel(
            repository: repository,
            clipboardRepository: makeClipboardRepository(),
            monitorsClipboard: false
        )

        viewModel.addNoteFromClipboard(
            title: "  Captured reference  ",
            content: "Clipboard content",
            tags: []
        )

        #expect(viewModel.notes.first?.title == "Captured reference")
        #expect(viewModel.notes.first?.tags == [viewModel.clipboardTag])
        #expect(try repository.fetchNotes().first?.title == "Captured reference")
    }

    @Test("Clipboard filtering is immediate, case insensitive, and diacritic insensitive")
    @MainActor
    func clipboardFiltering() throws {
        let repository = try makeRepository()
        let viewModel = try NotesViewModel(
            repository: repository,
            clipboardRepository: makeClipboardRepository(),
            monitorsClipboard: false
        )
        viewModel.addClipboardNote(content: "Résumé draft")
        viewModel.addClipboardNote(content: "Release checklist")

        #expect(viewModel.filteredClipboardData(matching: "").count == 2)
        #expect(viewModel.filteredClipboardData(matching: "resume").map(\.content) == ["Résumé draft"])
        #expect(viewModel.filteredClipboardData(matching: "CHECK").map(\.content) == ["Release checklist"])
        #expect(viewModel.filteredClipboardData(matching: "missing").isEmpty)
    }

    @Test("Clipboard history defaults to 100 and accepts values above 100")
    @MainActor
    func clipboardHistoryLimit() throws {
        let repository = try makeRepository()
        let viewModel = try NotesViewModel(
            repository: repository,
            clipboardRepository: makeClipboardRepository(),
            monitorsClipboard: false
        )

        #expect(viewModel.maxClipboardNotes == 100)

        viewModel.maxClipboardNotes = 250
        #expect(viewModel.maxClipboardNotes == 250)

        viewModel.maxClipboardNotes = 0
        #expect(viewModel.maxClipboardNotes == 1)
    }

    @Test("Clipboard repository persists, deduplicates, and trims items")
    @MainActor
    func clipboardRepositoryPersistence() throws {
        try withTemporaryDirectory { directory in
            let storeURL = directory.appendingPathComponent("QuickNotes.store")
            let firstCopy = ClipboardItem(
                id: UUID(),
                content: "Repeated content",
                timestamp: Date(timeIntervalSince1970: 100)
            )
            let secondItem = ClipboardItem(
                id: UUID(),
                content: "Second item",
                timestamp: Date(timeIntervalSince1970: 200)
            )
            let latestCopy = ClipboardItem(
                id: UUID(),
                content: "Repeated content",
                timestamp: Date(timeIntervalSince1970: 300)
            )
            let limitedItem = ClipboardItem(
                id: UUID(),
                content: "Newest limited item",
                timestamp: Date(timeIntervalSince1970: 400)
            )

            do {
                let container = try makeModelContainer(storeURL: storeURL)
                let repository = SwiftDataClipboardRepository(modelContainer: container)
                try repository.upsertItem(firstCopy, limit: 100)
                try repository.upsertItem(secondItem, limit: 100)
                try repository.upsertItem(latestCopy, limit: 100)

                #expect(try repository.fetchItems().map(\.id) == [latestCopy.id, secondItem.id])
                try repository.trimItems(to: 1)
                #expect(try repository.fetchItems().map(\.id) == [latestCopy.id])
                try repository.upsertItem(limitedItem, limit: 1)
                #expect(try repository.fetchItems().map(\.id) == [limitedItem.id])
            }

            let reopenedContainer = try makeModelContainer(storeURL: storeURL)
            let reopenedRepository = SwiftDataClipboardRepository(modelContainer: reopenedContainer)
            #expect(try reopenedRepository.fetchItems().map(\.id) == [limitedItem.id])
        }
    }

    @Test("View model restores and persistently removes clipboard history")
    @MainActor
    func clipboardViewModelRestoration() throws {
        let container = try makeModelContainer()
        let viewModel = try NotesViewModel(
            repository: SwiftDataNotesRepository(modelContainer: container),
            clipboardRepository: SwiftDataClipboardRepository(modelContainer: container),
            monitorsClipboard: false
        )
        viewModel.addClipboardNote(content: "First persisted item")
        viewModel.addClipboardNote(content: "Second persisted item")

        let restoredViewModel = try NotesViewModel(
            repository: SwiftDataNotesRepository(modelContainer: container),
            clipboardRepository: SwiftDataClipboardRepository(modelContainer: container),
            monitorsClipboard: false
        )
        #expect(Set(restoredViewModel.clipboardData.map(\.content)) == [
            "First persisted item",
            "Second persisted item"
        ])

        let removedItem = try #require(restoredViewModel.clipboardData.first)
        restoredViewModel.removeClipboardItem(removedItem)
        #expect(try SwiftDataClipboardRepository(modelContainer: container).fetchItems().count == 1)

        restoredViewModel.clearClipboardData()
        #expect(try SwiftDataClipboardRepository(modelContainer: container).fetchItems().isEmpty)
    }

    @Test("Adding the clipboard model preserves an existing notes store")
    @MainActor
    func clipboardSchemaUpgrade() throws {
        try withTemporaryDirectory { directory in
            let storeURL = directory.appendingPathComponent("QuickNotes.store")
            let note = Note(
                id: UUID(),
                content: "Created before clipboard persistence",
                tags: ["Work"],
                timestamp: Date(timeIntervalSince1970: 100),
                expanded: false
            )

            do {
                let oldConfiguration = ModelConfiguration(url: storeURL)
                let oldContainer = try ModelContainer(
                    for: NoteRecord.self,
                    TagRecord.self,
                    configurations: oldConfiguration
                )
                let oldRepository = SwiftDataNotesRepository(modelContainer: oldContainer)
                try oldRepository.insertTag("Work")
                try oldRepository.insertNote(note)
            }

            let upgradedContainer = try makeModelContainer(storeURL: storeURL)
            let notesRepository = SwiftDataNotesRepository(modelContainer: upgradedContainer)
            let clipboardRepository = SwiftDataClipboardRepository(modelContainer: upgradedContainer)

            #expect(try notesRepository.fetchNotes().map(\.id) == [note.id])
            #expect(try notesRepository.fetchTags() == ["Work"])
            #expect(try clipboardRepository.fetchItems().isEmpty)
        }
    }

    @Test("Only clipboard-origin notes receive the Clipboard tag")
    @MainActor
    func clipboardOriginNoteTags() throws {
        let repository = try makeRepository()
        try repository.insertTag("Work")
        try repository.insertTag("Clipboard")
        try repository.insertTag("Link")
        let viewModel = try NotesViewModel(
            repository: repository,
            clipboardRepository: makeClipboardRepository(),
            monitorsClipboard: false
        )

        viewModel.addNote(content: "Typed content", tags: ["Work"])
        let typedNote = try #require(viewModel.notes.first {
            $0.content == "Typed content"
        })
        #expect(typedNote.tags == ["Work"])

        viewModel.addNoteFromClipboard(
            content: "https://example.com/pasted",
            tags: ["Work"]
        )
        let pastedNote = try #require(viewModel.notes.first {
            $0.content == "https://example.com/pasted"
        })
        #expect(pastedNote.tags == ["Work", "Clipboard", "Link"])
    }

    @Test("Successful writes update view-model caches without refetching")
    @MainActor
    func incrementalViewModelUpdates() throws {
        let initialNote = Note(
            id: UUID(),
            content: "Existing note",
            tags: ["Work"],
            timestamp: Date(timeIntervalSince1970: 10),
            expanded: false
        )
        let notesRepository = CountingNotesRepository(
            notes: [initialNote],
            tags: ["Work"]
        )
        let clipboardRepository = CountingClipboardRepository()
        let viewModel = try NotesViewModel(
            repository: notesRepository,
            clipboardRepository: clipboardRepository,
            monitorsClipboard: false
        )

        #expect(viewModel.addNote(content: "New note", tags: ["Work"]))
        let addedNote = try #require(viewModel.notes.first { $0.id != initialNote.id })
        viewModel.togglePin(addedNote)
        viewModel.updateNote(
            addedNote,
            title: "Updated",
            content: "Updated note",
            tags: ["Work"],
            renderingMode: .plainText
        )
        viewModel.deleteNote(initialNote)
        viewModel.tagInput = "Ideas"
        viewModel.addTag()
        viewModel.removeTag("Work")
        viewModel.addClipboardNote(content: "Clipboard item")
        let clipboardItem = try #require(viewModel.clipboardData.first)
        viewModel.removeClipboardItem(clipboardItem)

        #expect(notesRepository.fetchNotesCount == 1)
        #expect(notesRepository.fetchTagsCount == 1)
        #expect(clipboardRepository.fetchItemsCount == 1)
        #expect(viewModel.notes.map(\.content) == ["Updated note"])
        #expect(viewModel.notes.first?.renderingMode == .plainText)
        #expect(viewModel.tags == ["Ideas"])
        #expect(viewModel.clipboardData.isEmpty)
    }

    @Test("Failed writes refetch only for recovery and keep caches consistent")
    @MainActor
    func failedWriteRecovery() throws {
        let initialNote = Note(
            id: UUID(),
            content: "Existing note",
            tags: [],
            timestamp: Date(timeIntervalSince1970: 10),
            expanded: false
        )
        let notesRepository = CountingNotesRepository(notes: [initialNote])
        let clipboardRepository = CountingClipboardRepository()
        let viewModel = try NotesViewModel(
            repository: notesRepository,
            clipboardRepository: clipboardRepository,
            monitorsClipboard: false
        )

        notesRepository.failNextWrite = true
        #expect(!viewModel.addNote(content: "Will fail", tags: []))

        #expect(viewModel.notes == [initialNote])
        #expect(notesRepository.fetchNotesCount == 2)
        #expect(notesRepository.fetchTagsCount == 2)
        #expect(viewModel.persistenceError != nil)
    }

    @Test("Markdown export wraps note content in transfer markers")
    func markdownExport() {
        let notes = [
            Note(
                id: UUID(),
                title: "Project plan",
                content: "First line\n\nSecond line",
                tags: ["Work", "Ideas"],
                timestamp: Date(timeIntervalSince1970: 0),
                expanded: false
            ),
            Note(
                id: UUID(),
                content: "Without a title",
                tags: [],
                timestamp: Date(timeIntervalSince1970: 1),
                expanded: false
            )
        ]

        let markdown = MarkdownExporter.document(
            notes: notes,
            exportedAt: Date(timeIntervalSince1970: 2)
        )

        #expect(markdown.contains("# Quick Notes"))
        #expect(markdown.contains("## Project plan"))
        #expect(markdown.contains("- Tags: Work, Ideas"))
        #expect(markdown.contains("- Rendering: markdown"))
        #expect(markdown.contains(
            "<!-- note-content:start -->\nFirst line\n\nSecond line\n<!-- note-content:end -->"
        ))
        #expect(markdown.contains("## Note 2"))
        #expect(markdown.contains("<!-- note-title:untitled -->"))
        #expect(markdown.hasSuffix(
            "<!-- note-content:start -->\nWithout a title\n<!-- note-content:end -->\n"
        ))
    }

    @Test("Markdown export and import preserve migration fields and arbitrary Markdown")
    func markdownImportRoundTrip() throws {
        let sourceNotes = [
            Note(
                id: UUID(),
                title: "Road-map [v2]",
                content: "# Heading\n\n---\n\n<!-- note-content:end -->\nStill content",
                tags: ["Work", "Long-Term"],
                timestamp: Date(timeIntervalSince1970: 100),
                renderingMode: .code(.swift),
                expanded: false
            ),
            Note(
                id: UUID(),
                content: "Untitled **Markdown**",
                tags: [],
                timestamp: Date(timeIntervalSince1970: 50),
                renderingMode: .plainText,
                expanded: false
            )
        ]

        let markdown = MarkdownExporter.document(
            notes: sourceNotes,
            exportedAt: Date(timeIntervalSince1970: 200)
        )
        let importedNotes = try MarkdownImporter.notes(from: markdown)

        #expect(importedNotes.count == 2)
        #expect(importedNotes[0].title == sourceNotes[0].title)
        #expect(importedNotes[0].content == sourceNotes[0].content)
        #expect(importedNotes[0].tags == sourceNotes[0].tags)
        #expect(importedNotes[0].timestamp == sourceNotes[0].timestamp)
        #expect(importedNotes[0].renderingMode == .code(.swift))
        #expect(importedNotes[1].title == nil)
        #expect(importedNotes[1].content == sourceNotes[1].content)
        #expect(importedNotes[1].timestamp == sourceNotes[1].timestamp)
        #expect(importedNotes[1].renderingMode == .plainText)
    }

    @Test("Legacy Markdown imports default to Markdown rendering")
    func legacyMarkdownImportDefaultsRenderingMode() throws {
        let document = """
        # Quick Notes

        Exported: 1970-01-01T00:00:02Z

        ---

        ## Legacy note

        - Created: 1970-01-01T00:00:01Z
        - Tags: None

        <!-- note-content:start -->
        **Still Markdown**
        <!-- note-content:end -->
        """

        let note = try #require(MarkdownImporter.notes(from: document).first)
        #expect(note.renderingMode == .markdown)
    }

    @Test("Code rendering heuristics recognize common languages")
    func codeLanguageHeuristics() {
        #expect(NoteCodeHeuristics.detectedLanguage(in: #"{"answer":42}"#) == .json)
        #expect(NoteCodeHeuristics.detectedLanguage(in: "#!/bin/zsh\necho hello") == .shell)
        #expect(NoteCodeHeuristics.detectedLanguage(in: "const answer = 42;\nconsole.log(answer)") == .javascript)
        #expect(NoteCodeHeuristics.detectedLanguage(in: "interface User { id: string }") == .typescript)
        #expect(NoteCodeHeuristics.detectedLanguage(in: "import SwiftUI\nstruct Demo: View {") == .swift)
        #expect(NoteCodeHeuristics.detectedLanguage(in: "A normal sentence.") == nil)
        #expect(
            NoteRenderingMode.automatic.resolvedForSaving(
                content: "const answer = 42;"
            ) == .code(.javascript)
        )
        #expect(
            NoteRenderingMode.automatic.resolvedForSaving(
                content: "A normal sentence."
            ) == .markdown
        )
        #expect(
            NoteRenderingMode.plainText.resolvedForSaving(
                content: "const answer = 42;"
            ) == .plainText
        )
        #expect(NoteRenderingMode.code(.swift).rendersCode(for: "A normal sentence."))
        #expect(NoteRenderingMode.automatic.rendersCode(for: "const answer = 42;"))
        #expect(!NoteRenderingMode.automatic.rendersCode(for: "A normal sentence."))
        #expect(!NoteRenderingMode.markdown.rendersCode(for: "```swift\nlet value = 1\n```"))
    }

    @Test("Adding a note reveals it and clears filters that could hide it")
    @MainActor
    func newlyCreatedNoteRevealRequest() throws {
        let viewModel = try NotesViewModel(
            repository: makeRepository(),
            clipboardRepository: makeClipboardRepository(),
            monitorsClipboard: false
        )
        viewModel.selectedTagFilter = "Work"
        viewModel.searchQuery = "hidden"
        viewModel.isSearchPresented = true

        #expect(viewModel.addNote(
            content: "const answer = 42",
            tags: []
        ))

        let createdNote = try #require(viewModel.notes.first)
        #expect(createdNote.renderingMode == .code(.javascript))
        #expect(viewModel.newlyCreatedNoteID == createdNote.id)
        #expect(viewModel.selectedTagFilter.isEmpty)
        #expect(viewModel.searchQuery.isEmpty)
        #expect(!viewModel.isSearchPresented)
    }

    @Test("Markdown import rejects documents without content markers")
    func markdownImportRequiresContentMarkers() {
        let malformedDocument = """
        # Quick Notes

        Exported: 1970-01-01T00:00:02Z

        ---

        ## Broken note

        - Created: 1970-01-01T00:00:01Z
        - Tags: None

        Unmarked content
        """

        #expect(throws: MarkdownImportError.self) {
            try MarkdownImporter.notes(from: malformedDocument)
        }
    }

    @Test("Markdown import merges by Created, skips matching content, and creates tags")
    @MainActor
    func markdownImportMerge() throws {
        let existingNote = Note(
            id: UUID(),
            title: "Same",
            content: "Duplicate body",
            tags: ["Work"],
            timestamp: Date(timeIntervalSince1970: 100),
            expanded: false
        )
        let repository = CountingNotesRepository(
            notes: [existingNote],
            tags: ["Work"]
        )
        let viewModel = try NotesViewModel(
            repository: repository,
            clipboardRepository: makeClipboardRepository(),
            monitorsClipboard: false
        )
        let importCandidates = [
            Note(
                id: UUID(),
                title: "Newest",
                content: "New body",
                tags: ["Travel"],
                timestamp: Date(timeIntervalSince1970: 200),
                expanded: false
            ),
            Note(
                id: UUID(),
                title: "Same",
                content: "Duplicate body",
                tags: ["IgnoredTag"],
                timestamp: Date(timeIntervalSince1970: 150),
                expanded: false
            ),
            Note(
                id: UUID(),
                title: nil,
                content: "Old body",
                tags: ["Work", "Archive"],
                timestamp: Date(timeIntervalSince1970: 50),
                expanded: false
            )
        ]
        let document = MarkdownExporter.document(
            notes: importCandidates,
            exportedAt: Date(timeIntervalSince1970: 300)
        )

        let result = try viewModel.importMarkdownDocument(document)

        #expect(result == NoteImportResult(importedCount: 2, skippedCount: 1))
        #expect(viewModel.notes.map(\.timestamp) == [
            Date(timeIntervalSince1970: 200),
            Date(timeIntervalSince1970: 100),
            Date(timeIntervalSince1970: 50)
        ])
        #expect(viewModel.tags == ["Work", "Travel", "Archive"])
        #expect(!viewModel.tags.contains("IgnoredTag"))
        #expect(repository.notes == viewModel.notes)
        #expect(repository.tags == viewModel.tags)
    }

    @MainActor
    private func makeRepository() throws -> SwiftDataNotesRepository {
        SwiftDataNotesRepository(modelContainer: try makeModelContainer())
    }

    @MainActor
    private func makeRepository(storeURL: URL) throws -> SwiftDataNotesRepository {
        SwiftDataNotesRepository(modelContainer: try makeModelContainer(storeURL: storeURL))
    }

    @MainActor
    private func makeClipboardRepository() throws -> SwiftDataClipboardRepository {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ClipboardRecord.self,
            configurations: configuration
        )
        return SwiftDataClipboardRepository(modelContainer: container)
    }

    @MainActor
    private func makeModelContainer(storeURL: URL? = nil) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if let storeURL {
            configuration = ModelConfiguration(url: storeURL)
        } else {
            configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        }
        return try ModelContainer(
            for: NoteRecord.self,
            TagRecord.self,
            ClipboardRecord.self,
            configurations: configuration
        )
    }

    private func withTemporaryDirectory(
        _ operation: (URL) throws -> Void
    ) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try operation(directory)
    }
}

@MainActor
private final class CountingNotesRepository: NotesRepository {
    var notes: [Note]
    var tags: [String]
    var fetchNotesCount = 0
    var fetchTagsCount = 0
    var failNextWrite = false

    init(notes: [Note] = [], tags: [String] = []) {
        self.notes = notes
        self.tags = tags
    }

    func fetchNotes() throws -> [Note] {
        fetchNotesCount += 1
        return notes
    }

    func fetchTags() throws -> [String] {
        fetchTagsCount += 1
        return tags
    }

    func insertNote(_ note: Note) throws {
        try checkForFailure()
        notes = NoteOrdering.inserting(note, into: notes)
    }

    func updateNote(_ note: Note) throws {
        try checkForFailure()
        notes = NoteOrdering.replacingAndReordering(note, in: notes)
    }

    func deleteNote(id: UUID) throws {
        try checkForFailure()
        notes.removeAll { $0.id == id }
    }

    func insertTag(_ tag: String) throws {
        try checkForFailure()
        tags.append(tag)
    }

    func importNotes(_ notes: [Note], creatingTags tags: [String]) throws {
        try checkForFailure()
        for tag in tags where !self.tags.contains(tag) {
            self.tags.append(tag)
        }
        for note in notes {
            self.notes = NoteOrdering.inserting(note, into: self.notes)
        }
    }

    func deleteTag(_ tag: String) throws {
        try checkForFailure()
        tags.removeAll { $0 == tag }
        notes = notes.map { note in
            var note = note
            note.tags.removeAll { $0 == tag }
            return note
        }
    }

    func reorderTags(_ tags: [String]) throws {
        try checkForFailure()
        let reorderedTags = Set(tags)
        self.tags = tags + self.tags.filter { !reorderedTags.contains($0) }
    }

    private func checkForFailure() throws {
        guard failNextWrite else { return }
        failNextWrite = false
        throw CountingRepositoryError.writeFailed
    }
}

@MainActor
private final class CountingClipboardRepository: ClipboardRepository {
    var items: [ClipboardItem] = []
    var fetchItemsCount = 0

    func fetchItems() throws -> [ClipboardItem] {
        fetchItemsCount += 1
        return items
    }

    func upsertItem(_ item: ClipboardItem, limit: Int) throws {
        items.removeAll { $0.id == item.id || $0.content == item.content }
        items.insert(item, at: 0)
        items = Array(items.prefix(max(limit, 0)))
    }

    func deleteItem(id: UUID) throws {
        items.removeAll { $0.id == id }
    }

    func deleteAllItems() throws {
        items.removeAll()
    }

    func trimItems(to limit: Int) throws {
        items = Array(items.prefix(max(limit, 0)))
    }
}

private enum CountingRepositoryError: Error {
    case writeFailed
}

@MainActor
private struct AddNoteFocusTestHost: View {
    @ObservedObject var viewModel: NotesViewModel
    @State private var isSheetPresented = false

    var body: some View {
        Color.clear
            .frame(width: 520, height: 600)
            .sheet(isPresented: $isSheetPresented) {
                AddNoteView(language: .englishUS)
                    .environmentObject(viewModel)
            }
            .onAppear {
                isSheetPresented = true
            }
    }
}
