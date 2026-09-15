import Darwin
import Foundation
import HighlightSwift
import SwiftUI

@main
@MainActor
struct QuickNotesLauncher {
    private static let highlightResourceVerificationArgument = "--verify-highlight-resource"

    static func main() {
        if CommandLine.arguments.contains(QuickNotesMCPStdioConfiguration.launchArgument) {
            QuickNotesMCPStdioServer.run()
            return
        }
        if CommandLine.arguments.contains(highlightResourceVerificationArgument) {
            verifyHighlightResource()
            return
        }
        QuickNotesApp.main()
    }

    private static func verifyHighlightResource() {
        Task { @MainActor in
            do {
                _ = try await Highlight().attributedText(
                    "let quickNotes = true",
                    language: "swift"
                )
                exit(EXIT_SUCCESS)
            } catch {
                let message = "Unable to load HighlightSwift resources: \(error.localizedDescription)\n"
                FileHandle.standardError.write(Data(message.utf8))
                exit(EXIT_FAILURE)
            }
        }
        RunLoop.main.run()
    }
}

@MainActor
struct QuickNotesApp: App {
    @StateObject private var viewModel: NotesViewModel
    @StateObject private var preferences: AppPreferences
    @StateObject private var menuBarController: MenuBarController

    init() {
        do {
            let modelContainer = try AppPersistence.makeModelContainer()
            let notesRepository = SwiftDataNotesRepository(modelContainer: modelContainer)
            let clipboardRepository = SwiftDataClipboardRepository(modelContainer: modelContainer)
            try notesRepository.seedDefaultTagsIfNeeded()

            let viewModel = try NotesViewModel(
                repository: notesRepository,
                clipboardRepository: clipboardRepository
            )
            let preferences = AppPreferences()
            _viewModel = StateObject(wrappedValue: viewModel)
            _preferences = StateObject(wrappedValue: preferences)
            _menuBarController = StateObject(
                wrappedValue: MenuBarController(
                    viewModel: viewModel,
                    preferences: preferences
                )
            )
        } catch {
            fatalError("Unable to initialize Quick Notes persistence: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
