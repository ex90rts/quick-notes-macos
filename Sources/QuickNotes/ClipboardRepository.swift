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
    func upsertItem(_ item: ClipboardItem, limit: Int) throws
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

    func upsertItem(_ item: ClipboardItem, limit: Int) throws {
        let itemID = item.id
        let itemContent = item.content
        let retainedCount = max(limit, 0)

        try performWrite {
            let duplicateDescriptor = FetchDescriptor<ClipboardRecord>(
                predicate: #Predicate {
                    $0.id == itemID || $0.content == itemContent
                }
            )
            for record in try modelContext.fetch(duplicateDescriptor) {
                modelContext.delete(record)
            }

            var overflowDescriptor = FetchDescriptor<ClipboardRecord>(
                predicate: #Predicate {
                    $0.id != itemID && $0.content != itemContent
                },
                sortBy: [SortDescriptor(\ClipboardRecord.timestamp, order: .reverse)]
            )
            overflowDescriptor.fetchOffset = max(retainedCount - 1, 0)
            for record in try modelContext.fetch(overflowDescriptor) {
                modelContext.delete(record)
            }

            if retainedCount > 0 {
                modelContext.insert(Self.makeRecord(item))
            }
        }
    }

    func deleteItem(id: UUID) throws {
        try performWrite {
            let id = id
            let descriptor = FetchDescriptor<ClipboardRecord>(
                predicate: #Predicate { $0.id == id }
            )
            for record in try modelContext.fetch(descriptor) {
                modelContext.delete(record)
            }
        }
    }

    func deleteAllItems() throws {
        try performWrite {
            for record in try modelContext.fetch(FetchDescriptor<ClipboardRecord>()) {
                modelContext.delete(record)
            }
        }
    }

    func trimItems(to limit: Int) throws {
        try performWrite {
            let retainedCount = max(limit, 0)
            var descriptor = FetchDescriptor<ClipboardRecord>(
                sortBy: [SortDescriptor(\ClipboardRecord.timestamp, order: .reverse)]
            )
            descriptor.fetchOffset = retainedCount
            for record in try modelContext.fetch(descriptor) {
                modelContext.delete(record)
            }
        }
    }

    private func saveChanges() throws {
        guard modelContext.hasChanges else { return }
        try modelContext.save()
    }

    private func performWrite(_ mutation: () throws -> Void) throws {
        do {
            try mutation()
            try saveChanges()
        } catch {
            modelContext.rollback()
            throw error
        }
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
