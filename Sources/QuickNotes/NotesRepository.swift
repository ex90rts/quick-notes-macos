import Foundation
import SwiftData

enum NotesDefaults {
    static let tags = ["Work", "Personal", "Ideas", "Todo"]
}

@Model
final class NoteRecord {
    var id: UUID
    var title: String?
    var content: String
    var tags: [String]
    var timestamp: Date
    var isPinned: Bool = false

    init(
        id: UUID,
        title: String?,
        content: String,
        tags: [String],
        timestamp: Date,
        isPinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.tags = tags
        self.timestamp = timestamp
        self.isPinned = isPinned
    }
}

@Model
final class TagRecord {
    var id: UUID
    var name: String
    var sortIndex: Int

    init(id: UUID = UUID(), name: String, sortIndex: Int) {
        self.id = id
        self.name = name
        self.sortIndex = sortIndex
    }
}

@MainActor
protocol NotesRepository: AnyObject {
    func fetchNotes() throws -> [Note]
    func fetchTags() throws -> [String]
    func insertNote(_ note: Note) throws
    func updateNote(_ note: Note) throws
    func deleteNote(id: UUID) throws
    func insertTag(_ tag: String) throws
    func deleteTag(_ tag: String) throws
    func reorderTags(_ tags: [String]) throws
}

@MainActor
final class SwiftDataNotesRepository: NotesRepository {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        modelContext = ModelContext(modelContainer)
        modelContext.autosaveEnabled = false
    }

    func fetchNotes() throws -> [Note] {
        let descriptor = FetchDescriptor<NoteRecord>(
            sortBy: [SortDescriptor(\NoteRecord.timestamp, order: .reverse)]
        )
        return NoteOrdering.pinnedFirst(
            try modelContext.fetch(descriptor).map(Self.makeNote)
        )
    }

    func fetchTags() throws -> [String] {
        let descriptor = FetchDescriptor<TagRecord>(
            sortBy: [
                SortDescriptor(\TagRecord.sortIndex),
                SortDescriptor(\TagRecord.name)
            ]
        )
        return try modelContext.fetch(descriptor).map(\.name)
    }

    func insertNote(_ note: Note) throws {
        guard try noteRecord(id: note.id) == nil else {
            throw NotesRepositoryError.duplicateNoteID(note.id)
        }

        modelContext.insert(Self.makeRecord(note))
        try saveChanges()
    }

    func updateNote(_ note: Note) throws {
        guard let record = try noteRecord(id: note.id) else {
            throw NotesRepositoryError.noteNotFound(note.id)
        }

        record.title = note.title
        record.content = note.content
        record.tags = note.tags
        record.timestamp = note.timestamp
        record.isPinned = note.isPinned
        try saveChanges()
    }

    func deleteNote(id: UUID) throws {
        guard let record = try noteRecord(id: id) else { return }
        modelContext.delete(record)
        try saveChanges()
    }

    func insertTag(_ tag: String) throws {
        let records = try tagRecords()
        guard !records.contains(where: { $0.name == tag }) else {
            throw NotesRepositoryError.duplicateTag(tag)
        }

        modelContext.insert(TagRecord(name: tag, sortIndex: records.count))
        try saveChanges()
    }

    func deleteTag(_ tag: String) throws {
        for record in try tagRecords().filter({ $0.name == tag }) {
            modelContext.delete(record)
        }
        for note in try modelContext.fetch(FetchDescriptor<NoteRecord>()) {
            note.tags.removeAll { $0 == tag }
        }
        try saveChanges()
    }

    func reorderTags(_ tags: [String]) throws {
        let positions = Dictionary(
            uniqueKeysWithValues: tags.enumerated().map { ($1, $0) }
        )
        let records = try tagRecords()
        let trailingOffset = tags.count

        for record in records {
            record.sortIndex = positions[record.name] ?? trailingOffset + record.sortIndex
        }
        try saveChanges()
    }

    func isEmpty() throws -> Bool {
        try modelContext.fetchCount(FetchDescriptor<NoteRecord>()) == 0
            && modelContext.fetchCount(FetchDescriptor<TagRecord>()) == 0
    }

    func seedDefaultTagsIfNeeded() throws {
        guard try isEmpty() else { return }
        for (index, tag) in NotesDefaults.tags.enumerated() {
            modelContext.insert(TagRecord(name: tag, sortIndex: index))
        }
        try saveChanges()
    }

    private func noteRecord(id: UUID) throws -> NoteRecord? {
        let id = id
        var descriptor = FetchDescriptor<NoteRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func tagRecords() throws -> [TagRecord] {
        try modelContext.fetch(
            FetchDescriptor<TagRecord>(
                sortBy: [SortDescriptor(\TagRecord.sortIndex)]
            )
        )
    }

    private func saveChanges() throws {
        guard modelContext.hasChanges else { return }
        try modelContext.save()
    }

    private static func makeRecord(_ note: Note) -> NoteRecord {
        NoteRecord(
            id: note.id,
            title: note.title,
            content: note.content,
            tags: note.tags,
            timestamp: note.timestamp,
            isPinned: note.isPinned
        )
    }

    private static func makeNote(_ record: NoteRecord) -> Note {
        Note(
            id: record.id,
            title: record.title,
            content: record.content,
            tags: record.tags,
            timestamp: record.timestamp,
            isPinned: record.isPinned,
            expanded: false
        )
    }
}

enum NotesRepositoryError: LocalizedError {
    case duplicateNoteID(UUID)
    case noteNotFound(UUID)
    case duplicateTag(String)

    var errorDescription: String? {
        switch self {
        case .duplicateNoteID(let id):
            "A note with ID \(id) already exists."
        case .noteNotFound(let id):
            "The note with ID \(id) could not be found."
        case .duplicateTag(let tag):
            "The tag \"\(tag)\" already exists."
        }
    }
}
