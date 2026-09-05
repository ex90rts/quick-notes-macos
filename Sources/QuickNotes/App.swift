import SwiftUI

@main
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
