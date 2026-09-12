import Foundation
import AppKit
import Combine
import OSLog

enum NoteContentSource {
    case manual
    case clipboard
}

private struct NoteImportIdentity: Hashable {
    let title: String?
    let content: String

    init(note: Note) {
        title = note.title
        content = note.content
    }
}

@MainActor
final class NotesViewModel: ObservableObject {
    static let maximumPinnedNotes = 3

    @Published var notes: [Note] = []
    @Published var tags: [String] = []
    @Published var selectedTagFilter: String = ""
    @Published var isSearchPresented: Bool = false
    @Published var searchQuery: String = ""
    @Published var newlyCreatedNoteID: UUID?
    @Published private(set) var isPanelPresented = false
    @Published private(set) var persistenceError: String?

    // Settings
    @Published var showAddNote: Bool = false
    @Published var showAbout: Bool = false
    @Published var tagInput: String = ""
    @Published var tagInputError: String? = nil

    // View states for new UI
    @Published var currentView: ViewState = .notesList
    @Published var clipboardData: [ClipboardItem] = []

    enum ViewState {
        case notesList
        case clipboardData
        case settings
    }
    @Published var maxClipboardNotes: Int = 100 {
        didSet {
            let clampedLimit = max(maxClipboardNotes, 1)
            guard clampedLimit == maxClipboardNotes else {
                maxClipboardNotes = clampedLimit
                return
            }
            trimClipboardData()
        }
    }

    // Clipboard monitoring
    private var clipboardMonitor: ClipboardMonitor?
    private let notesRepository: any NotesRepository
    private let clipboardRepository: any ClipboardRepository
    private let logger = Logger(subsystem: "com.webber.QuickNotes", category: "Persistence")
    let clipboardTag = "Clipboard"

    init(
        repository: any NotesRepository,
        clipboardRepository: any ClipboardRepository,
        monitorsClipboard: Bool = true
    ) throws {
        notesRepository = repository
        self.clipboardRepository = clipboardRepository
        notes = try repository.fetchNotes()
        tags = try repository.fetchTags()
        clipboardData = try clipboardRepository.fetchItems()

        if clipboardData.count > maxClipboardNotes {
            try clipboardRepository.trimItems(to: maxClipboardNotes)
            clipboardData = Array(clipboardData.prefix(maxClipboardNotes))
        }

        if monitorsClipboard {
            let monitor = ClipboardMonitor { [weak self] content in
                self?.addClipboardNote(content: content)
            }
            clipboardMonitor = monitor
            monitor.startMonitoring()
        }
    }

    // MARK: - Notes
    @discardableResult
    func addNote(
        title: String = "",
        content: String,
        tags selectedTags: Set<String>,
        renderingMode: NoteRenderingMode = .automatic
    ) -> Bool {
        guard NoteContentPolicy.canSave(content) else { return false }
        let clean = cleanContent(content)
        let note = Note(
            id: UUID(),
            title: TitleSanitizer.sanitize(title),
            content: clean,
            tags: tagsForSaving(
                content: clean,
                selectedTags: selectedTags
            ),
            timestamp: Date(),
            renderingMode: renderingMode.resolvedForSaving(content: clean),
            expanded: false
        )
        guard performNotesPersistence(
            { try notesRepository.insertNote(note) },
            updateCache: { notes = NoteOrdering.inserting(note, into: notes) }
        ) else { return false }

        prepareNewNoteForReveal(note.id)
        return true
    }

    func deleteNote(_ note: Note) {
        performNotesPersistence(
            { try notesRepository.deleteNote(id: note.id) },
            updateCache: { notes.removeAll { $0.id == note.id } }
        )
    }

    func importMarkdownDocument(_ document: String) throws -> NoteImportResult {
        let candidates = try MarkdownImporter.notes(from: document)
        var knownIdentities = Set(notes.map(NoteImportIdentity.init))
        var notesToImport: [Note] = []
        var skippedCount = 0

        for note in candidates {
            if knownIdentities.insert(NoteImportIdentity(note: note)).inserted {
                notesToImport.append(note)
            } else {
                skippedCount += 1
            }
        }

        var knownTags = Set(tags)
        var missingTags: [String] = []
        for note in notesToImport {
            for tag in note.tags where knownTags.insert(tag).inserted {
                missingTags.append(tag)
            }
        }

        guard !notesToImport.isEmpty || !missingTags.isEmpty else {
            return NoteImportResult(importedCount: 0, skippedCount: skippedCount)
        }

        do {
            try notesRepository.importNotes(notesToImport, creatingTags: missingTags)
            notes = NoteOrdering.merging(notesToImport, into: notes)
            tags.append(contentsOf: missingTags)
            persistenceError = nil
            return NoteImportResult(
                importedCount: notesToImport.count,
                skippedCount: skippedCount
            )
        } catch {
            recordPersistenceError(error)
            recoverNotesState()
            throw error
        }
    }

    func toggleExpand(_ note: Note) {
        guard let idx = notes.firstIndex(where: { $0.id == note.id }) else { return }

        NSApp.keyWindow?.makeFirstResponder(nil)
        notes[idx].expanded.toggle()
    }

    func copyNote(_ note: Note) {
        copyToPasteboard(cleanContent(note.content))
    }

    func canTogglePin(for note: Note) -> Bool {
        guard let currentNote = notes.first(where: { $0.id == note.id }) else { return false }
        return currentNote.isPinned
            || notes.lazy.filter(\.isPinned).count < Self.maximumPinnedNotes
    }

    func togglePin(_ note: Note) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }),
              canTogglePin(for: notes[index]) else { return }

        var updatedNote = notes[index]
        updatedNote.isPinned.toggle()
        performNotesPersistence(
            { try notesRepository.updateNote(updatedNote) },
            updateCache: {
                notes = NoteOrdering.replacingAndReordering(updatedNote, in: notes)
            }
        )
    }

    func toggleTodo(in note: Note, at lineIndex: Int) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }),
              let updatedContent = NoteTodo.togglingItem(
                in: notes[index].content,
                at: lineIndex
              ),
              NoteContentPolicy.canSave(updatedContent) else {
            return
        }

        var updatedNote = notes[index]
        updatedNote.content = updatedContent
        updatedNote.tags = tagsForSaving(
            content: updatedContent,
            selectedTags: Set(updatedNote.tags)
        )
        performNotesPersistence(
            { try notesRepository.updateNote(updatedNote) },
            updateCache: { notes[index] = updatedNote }
        )
    }

    func copyClipboardItem(_ item: ClipboardItem) {
        copyToPasteboard(cleanContent(item.content))
    }

    func filteredClipboardData(matching query: String) -> [ClipboardItem] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return filteredClipboardData(matchingNormalizedQuery: query)
    }

    func filteredClipboardData(matchingNormalizedQuery query: String) -> [ClipboardItem] {
        guard !query.isEmpty else { return clipboardData }

        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return clipboardData.filter {
            $0.content.range(of: query, options: options, locale: .current) != nil
        }
    }

    private func copyToPasteboard(_ content: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        clipboardMonitor?.ignoreCurrentPasteboardChange()
    }

    var filteredNotes: [Note] {
        filteredNotes(matching: effectiveSearchQuery)
    }

    func filteredNotes(matching query: String?) -> [Note] {
        notes.filter { note in
            let matchesTag = selectedTagFilter.isEmpty || note.tags.contains(selectedTagFilter)
            return matchesTag && matchesSearch(note, query: query)
        }
    }

    var effectiveSearchQuery: String? {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.count >= 2 ? query : nil
    }

    // MARK: - Clipboard Notes
    func addClipboardNote(content: String) {
        let sanitizedContent = cleanContent(content)
        guard !sanitizedContent.isEmpty else { return }

        let clipboardItem = ClipboardItem(content: sanitizedContent)
        performClipboardPersistence(
            {
                try clipboardRepository.upsertItem(
                    clipboardItem,
                    limit: maxClipboardNotes
                )
            },
            updateCache: {
                clipboardData.removeAll {
                    $0.id == clipboardItem.id || $0.content == clipboardItem.content
                }
                let insertionIndex = clipboardData.firstIndex {
                    $0.timestamp < clipboardItem.timestamp
                } ?? clipboardData.endIndex
                clipboardData.insert(clipboardItem, at: insertionIndex)
                if clipboardData.count > maxClipboardNotes {
                    clipboardData.removeLast(clipboardData.count - maxClipboardNotes)
                }
            }
        )
    }

    // MARK: - Clipboard to Note Conversion
    @discardableResult
    func addNoteFromClipboard(
        title: String = "",
        content: String,
        tags: Set<String>,
        renderingMode: NoteRenderingMode = .automatic
    ) -> Bool {
        guard NoteContentPolicy.canSave(content) else { return false }
        let sanitizedContent = cleanContent(content)

        let note = Note(
            id: UUID(),
            title: TitleSanitizer.sanitize(title),
            content: sanitizedContent,
            tags: tagsForSaving(
                content: sanitizedContent,
                selectedTags: tags,
                contentSource: .clipboard
            ),
            timestamp: Date(),
            renderingMode: renderingMode.resolvedForSaving(content: sanitizedContent),
            expanded: false
        )
        guard performNotesPersistence(
            { try notesRepository.insertNote(note) },
            updateCache: { notes = NoteOrdering.inserting(note, into: notes) }
        ) else { return false }

        prepareNewNoteForReveal(note.id)
        return true
    }

    func removeClipboardItem(_ item: ClipboardItem) {
        performClipboardPersistence(
            { try clipboardRepository.deleteItem(id: item.id) },
            updateCache: { clipboardData.removeAll { $0.id == item.id } }
        )
    }

    func clearClipboardData() {
        performClipboardPersistence(
            { try clipboardRepository.deleteAllItems() },
            updateCache: { clipboardData.removeAll() }
        )
    }

    // MARK: - View Navigation
    func navigateToNotesList() {
        currentView = .notesList
    }

    func navigateToClipboardData() {
        currentView = .clipboardData
    }

    func navigateToSettings() {
        currentView = .settings
    }

    func setPanelPresented(_ isPresented: Bool) {
        isPanelPresented = isPresented
    }

    // MARK: - Tags
    func addTag() {
        tagInputError = nil
        let raw = tagInput
        let newTag = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newTag.isEmpty else {
            tagInputError = "Tag cannot be empty."
            return
        }
        guard newTag.count <= 10 else {
            tagInputError = "Tag must be at most 10 characters."
            return
        }
        guard !tags.contains(newTag) else {
            tagInputError = "This tag already exists."
            return
        }
        let allowed = CharacterSet.alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn: "-_"))
        if newTag.rangeOfCharacter(from: allowed.inverted) != nil {
            tagInputError = "Only letters, numbers, spaces, hyphens, and underscores are allowed."
            return
        }
        guard performNotesPersistence(
            { try notesRepository.insertTag(newTag) },
            updateCache: { tags.append(newTag) }
        ) else { return }
        tagInput = ""
    }

    func removeTag(_ tag: String) {
        // Prevent removal of Clipboard tag
        guard tag != clipboardTag else { return }
        performNotesPersistence(
            { try notesRepository.deleteTag(tag) },
            updateCache: {
                tags.removeAll { $0 == tag }
                notes = notes.map { note in
                    var updatedNote = note
                    updatedNote.tags.removeAll { $0 == tag }
                    return updatedNote
                }
            }
        )
    }

    func updateTagsOrder(_ newOrder: [String]) {
        // Update the tags array with the new order
        // Ensure Clipboard tag is not included in the reordering
        let filteredOrder = newOrder.filter { $0 != clipboardTag }
        performNotesPersistence(
            { try notesRepository.reorderTags(filteredOrder) },
            updateCache: {
                let reorderedTags = Set(filteredOrder)
                tags = filteredOrder + tags.filter { !reorderedTags.contains($0) }
            }
        )
    }

    // MARK: - Note Tag Management
    func addTag(to note: Note, tag: String) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return }
        guard !notes[index].tags.contains(tag) else { return }

        var updatedNote = notes[index]
        updatedNote.tags.append(tag)
        performNotesPersistence(
            { try notesRepository.updateNote(updatedNote) },
            updateCache: { notes[index] = updatedNote }
        )
    }

    func removeTag(from note: Note, tag: String) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return }

        var updatedNote = notes[index]
        updatedNote.tags.removeAll { $0 == tag }
        performNotesPersistence(
            { try notesRepository.updateNote(updatedNote) },
            updateCache: { notes[index] = updatedNote }
        )
    }

    @discardableResult
    func updateNote(
        _ note: Note,
        title: String,
        content: String,
        tags newTags: Set<String>,
        renderingMode: NoteRenderingMode
    ) -> Bool {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return false }
        guard NoteContentPolicy.canSave(content) else { return false }
        let cleanedContent = cleanContent(content)

        var updatedNote = notes[index]
        updatedNote.title = TitleSanitizer.sanitize(title)
        updatedNote.content = cleanedContent
        updatedNote.tags = tagsForSaving(content: cleanedContent, selectedTags: newTags)
        updatedNote.renderingMode = renderingMode.resolvedForSaving(content: cleanedContent)
        updatedNote.expanded = false
        return performNotesPersistence(
            { try notesRepository.updateNote(updatedNote) },
            updateCache: { notes[index] = updatedNote }
        )
    }

    // MARK: - Utilities
    func cleanContent(_ s: String) -> String {
        ContentSanitizer.sanitize(s)
    }

    private func trimClipboardData() {
        guard clipboardData.count > maxClipboardNotes else { return }
        performClipboardPersistence(
            { try clipboardRepository.trimItems(to: maxClipboardNotes) },
            updateCache: {
                clipboardData.removeLast(clipboardData.count - maxClipboardNotes)
            }
        )
    }

    private func orderedTags(from selectedTags: Set<String>) -> [String] {
        let knownTags = tags.filter(selectedTags.contains)
        let remainingTags = selectedTags.subtracting(knownTags).sorted()
        return knownTags + remainingTags
    }

    private func prepareNewNoteForReveal(_ noteID: UUID) {
        selectedTagFilter = ""
        searchQuery = ""
        isSearchPresented = false
        newlyCreatedNoteID = noteID
    }

    private func tagsForSaving(
        content: String,
        selectedTags: Set<String>,
        contentSource: NoteContentSource = .manual
    ) -> [String] {
        var resolvedTags = selectedTags
        if contentSource == .clipboard {
            resolvedTags.insert(clipboardTag)
        }
        if NoteContentLink.containsURL(content),
           let linkTag = tags.first(where: {
               $0.caseInsensitiveCompare("Link") == .orderedSame
           }) {
            resolvedTags.insert(linkTag)
        }
        return orderedTags(from: resolvedTags)
    }

    @discardableResult
    private func performNotesPersistence(
        _ operation: () throws -> Void,
        updateCache: () -> Void
    ) -> Bool {
        do {
            try operation()
            updateCache()
            persistenceError = nil
            return true
        } catch {
            recordPersistenceError(error)
            recoverNotesState()
            return false
        }
    }

    @discardableResult
    private func performClipboardPersistence(
        _ operation: () throws -> Void,
        updateCache: () -> Void
    ) -> Bool {
        do {
            try operation()
            updateCache()
            persistenceError = nil
            return true
        } catch {
            recordPersistenceError(error)
            recoverClipboardState()
            return false
        }
    }

    private func recordPersistenceError(_ error: Error) {
        let message = error.localizedDescription
        persistenceError = message
        logger.error("Persistence operation failed: \(message, privacy: .public)")
    }

    private func recoverNotesState() {
        let expandedNoteIDs = Set(
            notes.lazy
                .filter(\.expanded)
                .map(\.id)
        )
        do {
            let recoveredNotes = try notesRepository.fetchNotes().map { note in
                var note = note
                note.expanded = expandedNoteIDs.contains(note.id)
                return note
            }
            let recoveredTags = try notesRepository.fetchTags()
            notes = recoveredNotes
            tags = recoveredTags
        } catch {
            logger.error(
                "Unable to recover notes after a persistence failure: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func recoverClipboardState() {
        do {
            clipboardData = try clipboardRepository.fetchItems()
        } catch {
            logger.error(
                "Unable to recover clipboard history after a persistence failure: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func matchesSearch(_ note: Note, query: String?) -> Bool {
        guard let query else { return true }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return note.title?.range(of: query, options: options, locale: .current) != nil
            || note.content.range(of: query, options: options, locale: .current) != nil
    }
}
