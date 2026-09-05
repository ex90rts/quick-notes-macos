import Foundation
import SwiftData

enum AppPersistence {
    static func applicationSupportDirectory(
        fileManager: FileManager = .default
    ) throws -> URL {
        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = applicationSupport.appendingPathComponent("QuickNotes", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @MainActor
    static func makeModelContainer(
        fileManager: FileManager = .default
    ) throws -> ModelContainer {
        let storeURL = try applicationSupportDirectory(fileManager: fileManager)
            .appendingPathComponent("QuickNotes.store", isDirectory: false)
        let configuration = ModelConfiguration(url: storeURL)
        return try ModelContainer(
            for: NoteRecord.self,
            TagRecord.self,
            ClipboardRecord.self,
            configurations: configuration
        )
    }
}
