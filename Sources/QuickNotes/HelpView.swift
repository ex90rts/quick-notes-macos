import SwiftUI

struct HelpView: View {
    @EnvironmentObject private var vm: NotesViewModel
    @Environment(\.appLanguage) private var appLanguage

    var body: some View {
        VStack(spacing: 0) {
            SubpageHeader(title: "Help") {
                vm.navigateToNotesList()
            }
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.large) {
                    HelpCard {
                        MarkdownContentView(
                            blocks: NoteContentParser.blocks(from: helpMarkdown),
                            highlightQuery: nil,
                            onToggleTodo: { _ in },
                            style: .helpDocument,
                            fontDesign: helpFontDesign
                        )
                    }

                    agentPrompts
                }
                .padding(AppSpacing.large)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(AppTheme.canvas)
        }
        .frame(minWidth: 520, minHeight: 280)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var helpMarkdown: String {
        AppLocalization.format(
            "Help Markdown Document",
            language: appLanguage,
            arguments: Int64(NotesViewModel.maximumPinnedNotes)
        )
    }

    private var helpFontDesign: Font.Design {
        appLanguage == .englishUS ? .serif : .default
    }

    private var agentPrompts: some View {
        HelpSubsection(title: "Try asking your Agent", systemImage: "text.bubble") {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                HelpPrompt(text: "Read all notes with the Work tag and organize them by topic.")
                HelpPrompt(text: "Create a Quick Note from the following content, generate a title, and match suitable tags: …")
                HelpPrompt(text: "Update note #UUID and mark its status as complete.")
                HelpPrompt(text: "Create a new tag named Research.")
                HelpPrompt(text: "Interpret my 100 most recent notes and identify themes, problems, and three next actions.")
            }
        }
    }
}

private struct HelpCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.medium)
        .background(AppTheme.elevatedSurface)
        .clipShape(.rect(cornerRadius: 9))
    }
}

private struct HelpSubsection<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        HelpCard {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Label {
                    Text(LocalizedStringKey(title))
                        .font(.system(size: 13, weight: .semibold))
                } icon: {
                    Image(systemName: systemImage)
                        .foregroundStyle(AppTheme.accent)
                }

                content
            }
        }
    }
}

private struct HelpPrompt: View {
    @EnvironmentObject private var vm: NotesViewModel
    @Environment(\.appLanguage) private var appLanguage
    let text: String
    @State private var didJustCopy = false
    @State private var isCopyHovering = false

    var body: some View {
        HStack(spacing: AppSpacing.small) {
            Text(verbatim: localizedText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: AppSpacing.small)

            Button {
                vm.copyHelpPrompt(localizedText)
                didJustCopy = true
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    didJustCopy = false
                }
            } label: {
                Image(systemName: didJustCopy ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(
                        didJustCopy
                            ? Color.green
                            : (isCopyHovering ? AppTheme.accent : Color.secondary)
                    )
                    .frame(width: 24, height: 24)
                    .background(isCopyHovering ? AppTheme.accentHoverBackground : Color.clear)
                    .clipShape(.rect(cornerRadius: 5))
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .onHover { isCopyHovering = $0 }
            .accessibilityLabel(LocalizedStringKey(didJustCopy ? "Copied" : "Copy"))
            .help(LocalizedStringKey(didJustCopy ? "Copied" : "Copy"))
        }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.inputSurface)
            .clipShape(.rect(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(AppTheme.border)
            }
    }

    private var localizedText: String {
        AppLocalization.string(text, language: appLanguage)
    }
}
