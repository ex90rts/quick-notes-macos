import Foundation
import SwiftData

@Model
final class ClipboardRecord {
    var id: UUID
    var content: String
    var timestamp: Date

    init(id: UUID, content: String, timestamp: Date) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
    }
}

@MainActor
protocol ClipboardRepository: AnyObject {
    func fetchItems() throws -> [ClipboardItem]
    func upsertItem(_ item: ClipboardItem) throws
    func deleteItem(id: UUID) throws
    func deleteAllItems() throws
    func trimItems(to limit: Int) throws
}

@MainActor
final class SwiftDataClipboardRepository: ClipboardRepository {
    private let modelContext: ModelContext

    init(modelContainer: ModelContainer) {
        modelContext = ModelContext(modelContainer)
        modelContext.autosaveEnabled = false
    }

    func fetchItems() throws -> [ClipboardItem] {
        let descriptor = FetchDescriptor<ClipboardRecord>(
            sortBy: [SortDescriptor(\ClipboardRecord.timestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(Self.makeItem)
    }

    func upsertItem(_ item: ClipboardItem) throws {
        let records = try modelContext.fetch(FetchDescriptor<ClipboardRecord>())
        for record in records where record.id == item.id || record.content == item.content {
            modelContext.delete(record)
        }
        modelContext.insert(Self.makeRecord(item))
        try saveChanges()
    }

    func deleteItem(id: UUID) throws {
        let id = id
        let descriptor = FetchDescriptor<ClipboardRecord>(
            predicate: #Predicate { $0.id == id }
        )
        for record in try modelContext.fetch(descriptor) {
            modelContext.delete(record)
        }
        try saveChanges()
    }

    func deleteAllItems() throws {
        for record in try modelContext.fetch(FetchDescriptor<ClipboardRecord>()) {
            modelContext.delete(record)
        }
        try saveChanges()
    }

    func trimItems(to limit: Int) throws {
        let retainedCount = max(limit, 0)
        let descriptor = FetchDescriptor<ClipboardRecord>(
            sortBy: [SortDescriptor(\ClipboardRecord.timestamp, order: .reverse)]
        )
        let records = try modelContext.fetch(descriptor)
        for record in records.dropFirst(retainedCount) {
            modelContext.delete(record)
        }
        try saveChanges()
    }

    private func saveChanges() throws {
        guard modelContext.hasChanges else { return }
        try modelContext.save()
    }

    private static func makeRecord(_ item: ClipboardItem) -> ClipboardRecord {
        ClipboardRecord(
            id: item.id,
            content: item.content,
            timestamp: item.timestamp
        )
    }

    private static func makeItem(_ record: ClipboardRecord) -> ClipboardItem {
        ClipboardItem(
            id: record.id,
            content: record.content,
            timestamp: record.timestamp
        )
    }
}
