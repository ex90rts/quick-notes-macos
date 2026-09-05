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
        #expect(initialPreferences.panelSize == .small)
        #expect(PanelSize.small.contentSize == CGSize(width: 520, height: 600))

        initialPreferences.menuBarIconStyle = .monochrome
        initialPreferences.panelSize = .large
        let restoredPreferences = AppPreferences(defaults: defaults)
        #expect(restoredPreferences.menuBarIconStyle == .monochrome)
        #expect(restoredPreferences.panelSize == .large)
        #expect(PanelSize.medium.contentSize == CGSize(width: 620, height: 720))
        #expect(restoredPreferences.panelSize.contentSize == CGSize(width: 720, height: 840))
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

    @Test("Only complete HTTP and HTTPS note contents become links")
    func noteContentLinks() {
        #expect(NoteContentLink.url(from: "https://example.com/path?q=notes")?.absoluteString == "https://example.com/path?q=notes")
        #expect(NoteContentLink.url(from: "  http://localhost:8080/note  ")?.absoluteString == "http://localhost:8080/note")
        #expect(NoteContentLink.url(from: "See https://example.com") == nil)
        #expect(NoteContentLink.url(from: "https://example.com trailing") == nil)
        #expect(NoteContentLink.url(from: "example.com") == nil)
        #expect(NoteContentLink.url(from: "file:///tmp/note") == nil)
        #expect(NoteContentLink.url(from: "https:///missing-host") == nil)
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

    @Test("Back to top appears after entering the second viewport")
    func scrollToTopThreshold() {
        #expect(!ScrollToTopBehavior.shouldShow(scrollOffset: 300, viewportHeight: 300))
        #expect(ScrollToTopBehavior.shouldShow(scrollOffset: 301, viewportHeight: 300))
        #expect(!ScrollToTopBehavior.shouldShow(scrollOffset: -20, viewportHeight: 300))
        #expect(!ScrollToTopBehavior.shouldShow(scrollOffset: 301, viewportHeight: 0))
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

        viewModel.newNoteContent = "https://example.com/new"
        viewModel.newNoteTags = ["Work"]
        viewModel.addNote()
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
            content: "https://example.com/edited",
            tags: []
        )
        let editedNote = try #require(viewModel.notes.first { $0.id == addedNote.id })
        #expect(editedNote.tags == ["Link"])
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
        viewModel.newNoteContent = "https://example.com"
        viewModel.addNote()
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

            do {
                let container = try makeModelContainer(storeURL: storeURL)
                let repository = SwiftDataClipboardRepository(modelContainer: container)
                try repository.upsertItem(firstCopy)
                try repository.upsertItem(secondItem)
                try repository.upsertItem(latestCopy)

                #expect(try repository.fetchItems().map(\.id) == [latestCopy.id, secondItem.id])
                try repository.trimItems(to: 1)
                #expect(try repository.fetchItems().map(\.id) == [latestCopy.id])
            }

            let reopenedContainer = try makeModelContainer(storeURL: storeURL)
            let reopenedRepository = SwiftDataClipboardRepository(modelContainer: reopenedContainer)
            #expect(try reopenedRepository.fetchItems().map(\.id) == [latestCopy.id])
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

    @Test("Add Note only applies the Clipboard tag when content came from its Paste button")
    @MainActor
    func addNoteClipboardSource() throws {
        let repository = try makeRepository()
        try repository.insertTag("Work")
        try repository.insertTag("Clipboard")
        try repository.insertTag("Link")
        let viewModel = try NotesViewModel(
            repository: repository,
            clipboardRepository: makeClipboardRepository(),
            monitorsClipboard: false
        )

        viewModel.newNoteContent = "Typed content"
        viewModel.newNoteTags = ["Work"]
        viewModel.addNote()
        let typedNote = try #require(viewModel.notes.first {
            $0.content == "Typed content"
        })
        #expect(typedNote.tags == ["Work"])

        viewModel.newNoteContent = "https://example.com/pasted"
        viewModel.newNoteTags = ["Work"]
        viewModel.addNote(contentSource: .clipboard)
        let pastedNote = try #require(viewModel.notes.first {
            $0.content == "https://example.com/pasted"
        })
        #expect(pastedNote.tags == ["Work", "Clipboard", "Link"])
    }

    @Test("Markdown export includes title, metadata, and untitled notes")
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
        #expect(markdown.contains("First line\n\nSecond line"))
        #expect(markdown.contains("## Note 2"))
        #expect(markdown.hasSuffix("Without a title\n"))
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
private struct AddNoteFocusTestHost: View {
    @ObservedObject var viewModel: NotesViewModel
    @State private var isSheetPresented = false

    var body: some View {
        Color.clear
            .frame(width: 520, height: 600)
            .sheet(isPresented: $isSheetPresented) {
                AddNoteView()
                    .environmentObject(viewModel)
            }
            .onAppear {
                isSheetPresented = true
            }
    }
}
