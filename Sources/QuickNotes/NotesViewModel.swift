import Foundation
import AppKit
import Combine
import OSLog

enum NoteContentSource {
    case manual
    case clipboard
}

@MainActor
final class NotesViewModel: ObservableObject {
    static let maximumPinnedNotes = 3

    @Published var notes: [Note] = []
    @Published var tags: [String] = []
    @Published var selectedTagFilter: String = ""
    @Published var isSearchPresented: Bool = false
    @Published var searchQuery: String = ""
    @Published var newNoteTitle: String = ""
    @Published var newNoteContent: String = ""
    @Published var newNoteTags: Set<String> = []
    @Published var shouldScrollToTop: Bool = false
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
            clipboardData = try clipboardRepository.fetchItems()
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
    func addNote(contentSource: NoteContentSource = .manual) {
        guard NoteContentPolicy.canSave(newNoteContent) else { return }
        let clean = cleanContent(newNoteContent)
        let note = Note(
            id: UUID(),
            title: TitleSanitizer.sanitize(newNoteTitle),
            content: clean,
            tags: tagsForSaving(
                content: clean,
                selectedTags: newNoteTags,
                contentSource: contentSource
            ),
            timestamp: Date(),
            expanded: false
        )
        guard performNotesPersistence({ try notesRepository.insertNote(note) }) else { return }
        newNoteTitle = ""
        newNoteContent = ""
        newNoteTags.removeAll()

        // Trigger scroll to top after adding a new note
        shouldScrollToTop = true
    }

    func deleteNote(_ note: Note) {
        performNotesPersistence { try notesRepository.deleteNote(id: note.id) }
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
        performNotesPersistence { try notesRepository.updateNote(updatedNote) }
    }

    func copyClipboardItem(_ item: ClipboardItem) {
        copyToPasteboard(cleanContent(item.content))
    }

    func filteredClipboardData(matching query: String) -> [ClipboardItem] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
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
        notes.filter { note in
            let matchesTag = selectedTagFilter.isEmpty || note.tags.contains(selectedTagFilter)
            return matchesTag && matchesSearch(note)
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
        guard performClipboardPersistence({
            try clipboardRepository.upsertItem(clipboardItem)
        }) else { return }
        trimClipboardData()
    }

    // MARK: - Clipboard to Note Conversion
    func addNoteFromClipboard(title: String = "", content: String, tags: Set<String>) {
        guard NoteContentPolicy.canSave(content) else { return }
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
            expanded: false
        )
        guard performNotesPersistence({ try notesRepository.insertNote(note) }) else { return }

        // Trigger scroll to top after adding a new note
        shouldScrollToTop = true
    }

    func removeClipboardItem(_ item: ClipboardItem) {
        performClipboardPersistence {
            try clipboardRepository.deleteItem(id: item.id)
        }
    }

    func clearClipboardData() {
        performClipboardPersistence {
            try clipboardRepository.deleteAllItems()
        }
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
        guard performNotesPersistence({ try notesRepository.insertTag(newTag) }) else { return }
        tagInput = ""
    }

    func removeTag(_ tag: String) {
        // Prevent removal of Clipboard tag
        guard tag != clipboardTag else { return }
        performNotesPersistence { try notesRepository.deleteTag(tag) }
    }

    func updateTagsOrder(_ newOrder: [String]) {
        // Update the tags array with the new order
        // Ensure Clipboard tag is not included in the reordering
        let filteredOrder = newOrder.filter { $0 != clipboardTag }
        performNotesPersistence { try notesRepository.reorderTags(filteredOrder) }
    }

    // MARK: - Note Tag Management
    func addTag(to note: Note, tag: String) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return }
        guard !notes[index].tags.contains(tag) else { return }

        var updatedNote = notes[index]
        updatedNote.tags.append(tag)
        performNotesPersistence { try notesRepository.updateNote(updatedNote) }
    }

    func removeTag(from note: Note, tag: String) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return }

        var updatedNote = notes[index]
        updatedNote.tags.removeAll { $0 == tag }
        performNotesPersistence { try notesRepository.updateNote(updatedNote) }
    }

    func updateNote(
        _ note: Note,
        title: String,
        content: String,
        tags newTags: Set<String>
    ) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return }
        guard NoteContentPolicy.canSave(content) else { return }
        let cleanedContent = cleanContent(content)

        var updatedNote = notes[index]
        updatedNote.title = TitleSanitizer.sanitize(title)
        updatedNote.content = cleanedContent
        updatedNote.tags = tagsForSaving(content: cleanedContent, selectedTags: newTags)
        updatedNote.expanded = false
        performNotesPersistence(
            { try notesRepository.updateNote(updatedNote) },
            collapsingNoteID: updatedNote.id
        )
    }

    // MARK: - Utilities
    func cleanContent(_ s: String) -> String {
        ContentSanitizer.sanitize(s)
    }

    private func trimClipboardData() {
        guard clipboardData.count > maxClipboardNotes else { return }
        performClipboardPersistence {
            try clipboardRepository.trimItems(to: maxClipboardNotes)
        }
    }

    private func orderedTags(from selectedTags: Set<String>) -> [String] {
        let knownTags = tags.filter(selectedTags.contains)
        let remainingTags = selectedTags.subtracting(knownTags).sorted()
        return knownTags + remainingTags
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
        if NoteContentLink.url(from: content) != nil,
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
        collapsingNoteID: UUID? = nil
    ) -> Bool {
        do {
            try operation()
            try reloadPersistedState(collapsingNoteID: collapsingNoteID)
            persistenceError = nil
            return true
        } catch {
            recordPersistenceError(error)
            return false
        }
    }

    @discardableResult
    private func performClipboardPersistence(
        _ operation: () throws -> Void
    ) -> Bool {
        do {
            try operation()
            clipboardData = try clipboardRepository.fetchItems()
            persistenceError = nil
            return true
        } catch {
            recordPersistenceError(error)
            return false
        }
    }

    private func recordPersistenceError(_ error: Error) {
        let message = error.localizedDescription
        persistenceError = message
        logger.error("Persistence operation failed: \(message, privacy: .public)")
    }

    private func reloadPersistedState(collapsingNoteID: UUID?) throws {
        let expandedNoteIDs = Set(
            notes.lazy
                .filter(\.expanded)
                .map(\.id)
        )
        notes = try notesRepository.fetchNotes().map { note in
            var note = note
            note.expanded = note.id != collapsingNoteID && expandedNoteIDs.contains(note.id)
            return note
        }
        tags = try notesRepository.fetchTags()
    }

    private func matchesSearch(_ note: Note) -> Bool {
        guard let query = effectiveSearchQuery else { return true }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return note.title?.range(of: query, options: options, locale: .current) != nil
            || note.content.range(of: query, options: options, locale: .current) != nil
    }
}
