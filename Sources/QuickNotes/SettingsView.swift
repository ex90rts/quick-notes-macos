import AppKit
import HighlightSwift
import SwiftUI
import UniformTypeIdentifiers

private enum MCPConfigurationCopyTarget: Equatable {
    case installationPrompt
    case command
    case arguments
}

struct SettingsView: View {
    @EnvironmentObject var vm: NotesViewModel
    @EnvironmentObject var preferences: AppPreferences
    @Environment(\.appLanguage) private var appLanguage
    @State private var showTagSortSheet = false
    @State private var exportMessage: String?
    @State private var exportSucceeded = false
    @State private var isExportTooltipVisible = false
    @State private var importAlert: SettingsImportAlert?
    @State private var isCodeHighlightPreviewExpanded = false
    @State private var isMCPConfigurationExpanded = false
    @State private var copiedMCPConfigurationTarget: MCPConfigurationCopyTarget?
    @State private var agentSkillActionMessage: String?
    @State private var agentSkillActionSucceeded = false
    @FocusState private var isTagInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            settingsContent
        }
        .frame(minWidth: 520, minHeight: 280)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showTagSortSheet) {
            TagSortView(isPresented: $showTagSortSheet, language: appLanguage)
                .environmentObject(vm)
        }
        .alert(item: $importAlert) { alert in
            Alert(
                title: Text(verbatim: alert.title),
                message: Text(verbatim: alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onChange(of: vm.isPanelPresented) { _, isPresented in
            if !isPresented {
                isCodeHighlightPreviewExpanded = false
                isMCPConfigurationExpanded = false
            }
        }
    }

    private var header: some View {
        SubpageHeader(title: "Settings") {
            isCodeHighlightPreviewExpanded = false
            isMCPConfigurationExpanded = false
            vm.currentView = .notesList
        }
        .id(preferences.accentColor)
    }

    private var settingsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                displayLanguageSection
                tagsSection
                // Clipboard behavior remains available; its settings UI is intentionally hidden
                // until the configuration model is ready to be exposed again.
                appearanceSection
                mcpSection
                transferSection
            }
            .padding(AppSpacing.large)
            // AppTheme reads the selected color from preferences. Give every
            // settings control a fresh identity when that source changes so
            // on-screen and off-screen controls repaint in the same update.
            .id(preferences.accentColor)
        }
        .background(AppTheme.canvas)
    }

    private var tagsSection: some View {
        SettingsSection(
            title: "Tags",
            systemImage: "tag",
            description: "Filter and group related notes.",
            headerTrailing: {
                SettingsHeaderAction(
                    title: "Resort order",
                    systemImage: "arrow.up.arrow.down",
                    isEnabled: manageableTags.count > 1
                ) {
                    showTagSortSheet = true
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: AppSpacing.small) {
                    HStack(spacing: 6) {
                        TextField("New tag name", text: $vm.tagInput)
                            .textFieldStyle(.plain)
                            .focused($isTagInputFocused)
                            .tint(AppTheme.accent)
                            .onSubmit { vm.addTag() }

                        if !vm.tagInput.isEmpty {
                            Button {
                                vm.tagInput = ""
                                isTagInputFocused = true
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Clear tag name")
                        }
                    }
                    .padding(.horizontal, 9)
                    .frame(height: AppControlMetrics.formControlHeight)
                    .appInputSurface(isFocused: isTagInputFocused)

                    Button("Add Tag") {
                        vm.addTag()
                        isTagInputFocused = true
                    }
                    .appProminentButton()
                    .disabled(vm.tagInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let error = vm.tagInputError {
                    Text(verbatim: localized(error))
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if !manageableTags.isEmpty {
                    TagSettingsFlowLayout(
                        tags: manageableTags,
                        onTagRemove: { tag in
                            vm.removeTag(tag)
                        }
                    )
                } else {
                    Text("No tags yet. Add one above to start organizing notes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, AppSpacing.xSmall)
                }
            }
        }
    }

    private var clipboardSection: some View {
        SettingsSection(
            title: "Clipboard",
            systemImage: "doc.on.clipboard",
            description: "Control how much recent clipboard text Quick Notes keeps in memory."
        ) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("History limit")
                        .font(.system(size: 13, weight: .medium))
                    Text("Items are removed from the oldest first.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HistoryLimitControl(value: $vm.maxClipboardNotes)
            }
        }
    }

    private var appearanceSection: some View {
        SettingsSection(
            title: "Appearance",
            systemImage: "paintpalette",
            description: "Customize selected appearance settings."
        ) {
            VStack(spacing: 0) {
                SettingsControlRow(title: "Menubar Icon") {
                    SettingsSegmentedControl(
                        options: MenuBarIconStyle.allCases,
                        selection: $preferences.menuBarIconStyle,
                        accessibilityLabel: "Icon style"
                    ) { $0.title }
                }
                .padding(.bottom, AppSpacing.medium)

                SettingsDashedDivider()

                SettingsControlRow(title: "Accent Color") {
                    AccentColorPicker(selection: $preferences.accentColor)
                }
                .padding(.vertical, AppSpacing.medium)

                SettingsDashedDivider()

                SettingsControlRow(title: "Panel Size") {
                    SettingsSegmentedControl(
                        options: PanelSize.allCases,
                        selection: $preferences.panelSize,
                        width: 210,
                        accessibilityLabel: "Panel size"
                    ) { $0.title }
                }
                .padding(.vertical, AppSpacing.medium)

                SettingsDashedDivider()

                VStack(alignment: .leading, spacing: 0) {
                    SettingsControlRow(title: "Code Highlight Theme") {
                        HStack(spacing: AppSpacing.small) {
                            SettingsMenuPicker(
                                selection: $preferences.codeHighlightTheme,
                                options: CodeHighlightTheme.allCases,
                                width: 150,
                                accessibilityLabel: "Code highlight theme"
                            ) { theme in
                                Text(verbatim: theme.title)
                            }

                            CodeHighlightThemePreviewButton(
                                isPreviewExpanded: $isCodeHighlightPreviewExpanded
                            )
                        }
                    }

                    if isCodeHighlightPreviewExpanded {
                        CodeHighlightThemePreview(theme: preferences.codeHighlightTheme)
                            .padding(.top, AppSpacing.medium)
                    }
                }
                .padding(.top, AppSpacing.medium)
            }
        }
    }

    private var transferSection: some View {
        SettingsSection(
            title: "Export / Import",
            systemImage: "arrow.up.arrow.down",
            description: "Use a Markdown document to back up or migrate note data."
        ) {
            VStack(spacing: 0) {
                HStack {
                    Text("Export Notes")
                        .font(.system(size: 13, weight: .medium))

                    Spacer()

                    ZStack {
                        Button {
                            exportMarkdown()
                        } label: {
                            Label("Export…", systemImage: "square.and.arrow.up")
                        }
                        .appProminentButton()
                        .disabled(vm.notes.isEmpty)
                    }
                    .fixedSize()
                    .overlay {
                        if vm.notes.isEmpty {
                            Color.clear
                                .contentShape(.rect)
                                .onHover { isExportTooltipVisible = $0 }
                                .accessibilityHidden(true)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if vm.notes.isEmpty, isExportTooltipVisible {
                            AppTooltip(text: localized("No notes to export."))
                                .offset(y: -30)
                                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottomTrailing)))
                        }
                    }
                    .animation(.easeOut(duration: 0.12), value: isExportTooltipVisible)
                }

                if !vm.notes.isEmpty, let exportMessage {
                    Text(verbatim: exportMessage)
                        .font(.caption)
                        .foregroundStyle(exportSucceeded ? AppTheme.accent : Color.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, AppSpacing.small)
                }

                SettingsDashedDivider()
                    .padding(.vertical, AppSpacing.medium)

                HStack {
                    Text("Import Notes")
                        .font(.system(size: 13, weight: .medium))

                    Spacer()

                    Button {
                        importMarkdown()
                    } label: {
                        Label("Import…", systemImage: "square.and.arrow.down")
                    }
                    .appProminentButton()
                    .fixedSize()
                }
            }
        }
    }

    private var mcpSection: some View {
        SettingsSection(
            title: "MCP Server",
            systemImage: "cpu",
            description: "Connect a local Agent to read and manage note data."
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                SettingsControlRow(
                    title: "Enable MCP Server",
                    description: "When disabled, Agents cannot connect or change your notes."
                ) {
                    Toggle("Enable MCP Server", isOn: $preferences.mcpServerEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(AppTheme.accent)
                        .accessibilityLabel("Enable MCP Server")
                }

                SettingsDashedDivider()

                SettingsControlRow(
                    title: "Allow MCP Delete",
                    description: "Choose whether Agents may delete specified notes or tags."
                ) {
                    Toggle("Allow MCP Delete", isOn: $preferences.mcpDeletionEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(AppTheme.accent)
                        .accessibilityLabel("Allow MCP Delete")
                }

                SettingsDashedDivider()

                HStack(spacing: AppSpacing.medium) {
                    Button {
                        isMCPConfigurationExpanded.toggle()
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: AppSpacing.small) {
                                Text("Agent Installation Configuration")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.primary)

                                Image(systemName: isMCPConfigurationExpanded ? "chevron.up" : "chevron.down")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }

                            Text("Copy the installation prompt to your Agent, or expand to copy the parameters for manual setup.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Agent Installation Configuration")
                    .accessibilityValue(isMCPConfigurationExpanded ? "Expanded" : "Collapsed")

                    Spacer()

                    Button {
                        copyMCPConfigurationValue(
                            QuickNotesMCPStdioConfiguration.installationPrompt,
                            target: .installationPrompt
                        )
                    } label: {
                        Label(
                            copiedMCPConfigurationTarget == .installationPrompt
                                ? "Copied"
                                : "Copy Install Prompt",
                            systemImage: copiedMCPConfigurationTarget == .installationPrompt
                                ? "checkmark"
                                : "doc.on.doc"
                        )
                    }
                    .appProminentButton()
                    .fixedSize()
                    .accessibilityLabel("Copy Install Prompt")
                }

                if isMCPConfigurationExpanded {
                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        MCPConfigurationValueRow(
                            title: "Command",
                            value: QuickNotesMCPStdioConfiguration.command,
                            copyTitle: "Copy Command",
                            isCopied: copiedMCPConfigurationTarget == .command
                        ) {
                            copyMCPConfigurationValue(
                                QuickNotesMCPStdioConfiguration.command,
                                target: .command
                            )
                        }

                        MCPConfigurationValueRow(
                            title: "Arguments",
                            value: QuickNotesMCPStdioConfiguration.arguments.joined(separator: "\n"),
                            copyTitle: "Copy Arguments",
                            isCopied: copiedMCPConfigurationTarget == .arguments
                        ) {
                            copyMCPConfigurationValue(
                                QuickNotesMCPStdioConfiguration.arguments.joined(separator: "\n"),
                                target: .arguments
                            )
                        }
                    }
                }

                SettingsDashedDivider()

                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    SettingsControlRow(
                        title: "Quick Notes Agent Skill",
                        description: "Install the Skill to help Agents manage note data more easily."
                    ) {
                        HStack(spacing: AppSpacing.small) {
                            Button("Save As") {
                                saveQuickNotesAgentSkill()
                            }
                            .appSecondaryButton()
                            .fixedSize()
                            .accessibilityLabel("Save As")

                            Button("Install for Agents") {
                                installQuickNotesAgentSkill()
                            }
                            .appProminentButton()
                            .fixedSize()
                            .accessibilityLabel("Install for Agents")
                        }
                    }

                    if let agentSkillActionMessage {
                        Text(verbatim: agentSkillActionMessage)
                            .font(.caption)
                            .foregroundStyle(agentSkillActionSucceeded ? .green : .red)
                    }
                }
            }
        }
    }

    private var displayLanguageSection: some View {
        SettingsSection(
            title: "Display Language",
            systemImage: "globe",
            description: "Follow the system by default, or choose a language.",
            headerTrailing: {
                SettingsMenuPicker(
                    selection: $preferences.displayLanguage,
                    options: AppLanguagePreference.allCases,
                    width: 180,
                    accessibilityLabel: "Display language"
                ) { language in
                    Text(LocalizedStringKey(language.title))
                }
            }
        ) {
            EmptyView()
        }
    }

    private var manageableTags: [String] {
        vm.tags.filter { $0 != vm.clipboardTag }
    }

    private func exportMarkdown() {
        guard !vm.notes.isEmpty else { return }
        guard let parentWindow = NSApp.keyWindow else {
            exportSucceeded = false
            exportMessage = localized("Could not open the export dialog.")
            return
        }

        let panel = NSSavePanel()
        panel.title = localized("Export Quick Notes")
        panel.prompt = localized("Export")
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = exportFileName

        panel.beginSheetModal(for: parentWindow) { response in
            guard response == .OK, let destination = panel.url else { return }

            do {
                let markdown = MarkdownExporter.document(notes: vm.notes)
                try markdown.write(to: destination, atomically: true, encoding: .utf8)
                exportSucceeded = true
                let key = vm.notes.count == 1
                    ? "Exported %lld note to %@."
                    : "Exported %lld notes to %@."
                exportMessage = AppLocalization.format(
                    key,
                    language: appLanguage,
                    arguments: Int64(vm.notes.count), destination.lastPathComponent
                )
            } catch {
                exportSucceeded = false
                exportMessage = AppLocalization.format(
                    "Export failed: %@",
                    language: appLanguage,
                    arguments: error.localizedDescription
                )
            }
        }
    }

    private func importMarkdown() {
        guard let parentWindow = NSApp.keyWindow else {
            importAlert = SettingsImportAlert(
                title: localized("Import Failed"),
                message: localized("Could not open the import dialog.")
            )
            return
        }

        let panel = NSOpenPanel()
        panel.title = localized("Import Quick Notes")
        panel.prompt = localized("Import")
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        panel.beginSheetModal(for: parentWindow) { response in
            guard response == .OK, let source = panel.url else { return }

            do {
                let document = try String(contentsOf: source, encoding: .utf8)
                let result = try vm.importMarkdownDocument(document)
                importAlert = SettingsImportAlert(
                    title: localized("Import Complete"),
                    message: importResultMessage(result)
                )
            } catch {
                let message = error is MarkdownImportError
                    ? localized("The selected file is not a valid Quick Notes export.")
                    : AppLocalization.format(
                        "Import failed: %@",
                        language: appLanguage,
                        arguments: error.localizedDescription
                    )
                importAlert = SettingsImportAlert(
                    title: localized("Import Failed"),
                    message: message
                )
            }
        }
    }

    private func importResultMessage(_ result: NoteImportResult) -> String {
        let importedKey = result.importedCount == 1
            ? "Successfully imported %lld note."
            : "Successfully imported %lld notes."
        var message = AppLocalization.format(
            importedKey,
            language: appLanguage,
            arguments: Int64(result.importedCount)
        )
        if result.skippedCount > 0 {
            let skippedKey = result.skippedCount == 1
                ? " Ignored %lld note with identical title and content."
                : " Ignored %lld notes with identical title and content."
            message += AppLocalization.format(
                skippedKey,
                language: appLanguage,
                arguments: Int64(result.skippedCount)
            )
        }
        return message
    }

    private func localized(_ key: String) -> String {
        AppLocalization.string(key, language: appLanguage)
    }

    private func copyMCPConfigurationValue(
        _ value: String,
        target: MCPConfigurationCopyTarget
    ) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        copiedMCPConfigurationTarget = target

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            guard copiedMCPConfigurationTarget == target else { return }
            copiedMCPConfigurationTarget = nil
        }
    }

    private func installQuickNotesAgentSkill() {
        do {
            _ = try QuickNotesAgentSkillInstaller.installFromMainBundle()
            agentSkillActionSucceeded = true
            agentSkillActionMessage = localized(
                "Installed Quick Notes skill. Restart your Agent app if it is already open."
            )
        } catch {
            agentSkillActionSucceeded = false
            agentSkillActionMessage = AppLocalization.format(
                "Could not install Quick Notes skill: %@",
                language: appLanguage,
                arguments: error.localizedDescription
            )
        }
    }

    private func saveQuickNotesAgentSkill() {
        guard let parentWindow = NSApp.keyWindow else {
            agentSkillActionSucceeded = false
            agentSkillActionMessage = localized("Could not open the save dialog.")
            return
        }

        let panel = NSSavePanel()
        panel.title = localized("Save Quick Notes Agent Skill")
        panel.prompt = localized("Save")
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "quick-notes-skill.md"

        panel.beginSheetModal(for: parentWindow) { response in
            guard response == .OK, let destination = panel.url else { return }

            do {
                let markdown = try QuickNotesAgentSkillInstaller.bundledSkillMarkdown()
                try markdown.write(to: destination, atomically: true, encoding: .utf8)
                agentSkillActionSucceeded = true
                agentSkillActionMessage = AppLocalization.format(
                    "Saved Quick Notes skill to %@.",
                    language: appLanguage,
                    arguments: destination.lastPathComponent
                )
            } catch {
                agentSkillActionSucceeded = false
                agentSkillActionMessage = AppLocalization.format(
                    "Could not save Quick Notes skill: %@",
                    language: appLanguage,
                    arguments: error.localizedDescription
                )
            }
        }
    }

    private var exportFileName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return "quick-notes-\(formatter.string(from: Date())).md"
    }
}

private struct SettingsImportAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct CodeHighlightThemePreviewButton: View {
    private static let size: CGFloat = 26
    @Binding var isPreviewExpanded: Bool

    var body: some View {
        Button {
            isPreviewExpanded.toggle()
        } label: {
            Image(systemName: isPreviewExpanded ? "eye.slash" : "eye")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(
                    isPreviewExpanded ? AppTheme.accentForeground : Color.secondary
                )
                .frame(
                    width: Self.size,
                    height: Self.size
                )
                .background(
                    isPreviewExpanded ? AppTheme.accentBackground : AppTheme.quietFill
                )
                .clipShape(.rect(cornerRadius: AppControlMetrics.inputCornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: AppControlMetrics.inputCornerRadius)
                        .stroke(isPreviewExpanded ? AppTheme.accent : AppTheme.border)
                }
        }
        .buttonStyle(.plain)
        .contentShape(.rect)
        .accessibilityLabel(
            Text(isPreviewExpanded ? "Close code highlight preview" : "Open code highlight preview")
        )
    }
}

private struct CodeHighlightThemePreview: View {
    let theme: CodeHighlightTheme

    private let swiftSample = """
    struct Note: Identifiable {
        let id = UUID()
        var isPinned = false
    }
    """
    private let javascriptSample = """
    const note = { pinned: true };
    console.log(note);
    """
    private let jsonSample = """
    { "title": "Quick Notes", "pinned": true }
    """
    private let rustSample = """
    let note = Note { pinned: true };
    println!("{note:?}");
    """

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text(verbatim: theme.title)
                .font(.system(size: 13, weight: .semibold))

            previewSnippet("Swift", code: swiftSample, language: .swift)
            previewSnippet("JavaScript", code: javascriptSample, language: .javaScript)
            previewSnippet("JSON", code: jsonSample, language: .json)
            previewSnippet("Rust", code: rustSample, language: .rust)
        }
        .padding(AppSpacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.elevatedSurface)
    }

    private func previewSnippet(
        _ title: String,
        code: String,
        language: HighlightLanguage
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal) {
                CodeText(code)
                    .highlightLanguage(language)
                    .codeTextColors(.theme(theme.highlightTheme))
                    .font(.system(size: 11, design: .monospaced))
                    .fixedSize(horizontal: true, vertical: true)
                    .padding(8)
            }
            .scrollIndicators(.hidden)
            .background(AppTheme.quietFill)
            .clipShape(.rect(cornerRadius: AppControlMetrics.inputCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppControlMetrics.inputCornerRadius)
                    .stroke(AppTheme.border)
            }
        }
    }
}

private struct HistoryLimitControl: View {
    @Binding var value: Int
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 5) {
            HistoryLimitStepButton(
                systemImage: "minus",
                accessibilityLabel: "Decrease history limit",
                isEnabled: value > 1
            ) {
                value = max(1, value - 1)
            }

            TextField(
                "History limit",
                value: $value,
                format: .number.grouping(.never)
            )
            .textFieldStyle(.plain)
            .focused($isFocused)
            .multilineTextAlignment(.center)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .frame(width: 60, height: AppControlMetrics.formControlHeight)
            .appInputSurface(isFocused: isFocused)

            HistoryLimitStepButton(
                systemImage: "plus",
                accessibilityLabel: "Increase history limit",
                isEnabled: value < Int.max
            ) {
                value = value == Int.max ? Int.max : value + 1
            }
        }
        .help("Enter 1 or more")
    }
}

private struct HistoryLimitStepButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let isEnabled: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isEnabled ? Color.primary : AppTheme.disabledForeground)
                .frame(
                    width: AppControlMetrics.formControlHeight,
                    height: AppControlMetrics.formControlHeight
                )
                .background(
                    !isEnabled
                        ? AppTheme.disabledFill
                        : (isHovering ? AppTheme.accentHoverBackground : AppTheme.elevatedSurface)
                )
                .clipShape(.rect(cornerRadius: AppControlMetrics.inputCornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: AppControlMetrics.inputCornerRadius)
                        .stroke(AppTheme.border)
                }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .contentShape(.rect)
        .onHover { isHovering = $0 }
        .accessibilityLabel(Text(LocalizedStringKey(accessibilityLabel)))
    }
}

private struct SettingsHeaderAction: View {
    let title: String
    let systemImage: String
    let isEnabled: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Label(LocalizedStringKey(title), systemImage: systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(
                    isEnabled ? AppTheme.accent : AppTheme.disabledForeground
                )
                .padding(.horizontal, 8)
                .frame(height: 26)
                .background(isHovering && isEnabled ? AppTheme.accentHoverBackground : Color.clear)
                .clipShape(.rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { isHovering = $0 }
        .help("Change tag order")
    }
}

private struct SettingsSegmentedControl<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    var width: CGFloat = 190
    let accessibilityLabel: String
    let title: (Option) -> String

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    Text(LocalizedStringKey(title(option)))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(
                            selection == option ? AppTheme.accentForeground : Color.primary
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(.rect)
                        .background(selection == option ? AppTheme.accentBackground : Color.clear)
                        .clipShape(.rect(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(.rect)
                .accessibilityAddTraits(selection == option ? .isSelected : [])
            }
        }
        .padding(2)
        .frame(width: width, height: AppControlMetrics.formControlHeight)
        .background(AppTheme.quietFill)
        .clipShape(.rect(cornerRadius: AppControlMetrics.inputCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: AppControlMetrics.inputCornerRadius)
                .stroke(AppTheme.border)
        }
        .animation(.easeOut(duration: 0.12), value: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(LocalizedStringKey(accessibilityLabel)))
    }
}

/// A fully themed menu trigger. Native macOS menu pickers reserve the indicator
/// button for the system tint, which can diverge from a user-selected app accent.
private struct SettingsMenuPicker<Option: Hashable, OptionLabel: View>: View {
    @Binding var selection: Option
    let options: [Option]
    let width: CGFloat
    let accessibilityLabel: String
    let optionLabel: (Option) -> OptionLabel
    @State private var isHovering = false
    @State private var isPresented = false

    init(
        selection: Binding<Option>,
        options: [Option],
        width: CGFloat,
        accessibilityLabel: String,
        @ViewBuilder optionLabel: @escaping (Option) -> OptionLabel
    ) {
        _selection = selection
        self.options = options
        self.width = width
        self.accessibilityLabel = accessibilityLabel
        self.optionLabel = optionLabel
    }

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            triggerLabel
        }
        .buttonStyle(.plain)
        .frame(width: width, height: AppControlMetrics.formControlHeight)
        .onHover { isHovering = $0 }
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            optionsPopover
        }
        .accessibilityLabel(Text(LocalizedStringKey(accessibilityLabel)))
    }

    private var triggerLabel: some View {
        HStack(spacing: 0) {
            optionLabel(selection)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.accentForeground)
                .frame(
                    width: AppControlMetrics.formControlHeight,
                    height: AppControlMetrics.formControlHeight
                )
                .background(AppTheme.accentBackground)
        }
        .background(isHovering ? AppTheme.accentHoverBackground : AppTheme.elevatedSurface)
        .clipShape(.rect(cornerRadius: AppControlMetrics.inputCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: AppControlMetrics.inputCornerRadius)
                .stroke(AppTheme.border)
        }
        .contentShape(.rect)
    }

    private var optionsPopover: some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(options, id: \.self) { option in
                    Button {
                        selection = option
                        isPresented = false
                    } label: {
                        HStack(spacing: AppSpacing.small) {
                            optionLabel(option)
                                .lineLimit(1)
                            Spacer(minLength: AppSpacing.small)
                            if selection == option {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                        }
                        .foregroundStyle(
                            selection == option ? AppTheme.accentForeground : Color.primary
                        )
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
                        .background(
                            selection == option ? AppTheme.accentBackground : Color.clear
                        )
                        .clipShape(.rect(cornerRadius: 6))
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
        }
        .frame(width: max(width, 160), height: min(CGFloat(options.count) * 32 + 12, 300))
    }
}

private struct AccentColorPicker: View {
    @Binding var selection: AppAccentColor

    var body: some View {
        SettingsMenuPicker(
            selection: $selection,
            options: AppAccentColor.allCases,
            width: 160,
            accessibilityLabel: "Accent Color"
        ) { option in
            HStack(spacing: AppSpacing.small) {
                Circle()
                    .fill(option.color)
                    .frame(width: 12, height: 12)
                Text(LocalizedStringKey(option.title))
            }
        }
    }
}

private struct MCPConfigurationValueRow: View {
    let title: String
    let value: String
    let copyTitle: String
    let isCopied: Bool
    let copy: () -> Void
    @State private var isCopyButtonHovering = false

    var body: some View {
        HStack(spacing: AppSpacing.small) {
            Text(LocalizedStringKey(title))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 68, alignment: .leading)

            Text(verbatim: value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .padding(.horizontal, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: AppControlMetrics.formControlHeight)
                .background(AppTheme.inputSurface)
                .clipShape(.rect(cornerRadius: AppControlMetrics.inputCornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: AppControlMetrics.inputCornerRadius)
                        .stroke(AppTheme.border)
                }

            Button(action: copy) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: NoteCardLayout.actionIconSize, weight: .medium))
                    .foregroundStyle(
                        isCopied
                            ? Color.green
                            : (isCopyButtonHovering ? AppTheme.accent : Color.secondary)
                    )
                    .frame(
                        width: AppControlMetrics.formControlHeight,
                        height: AppControlMetrics.formControlHeight
                    )
                    .background(isCopyButtonHovering ? AppTheme.accentHoverBackground : Color.clear)
                    .clipShape(.rect(cornerRadius: NoteCardLayout.actionHoverCornerRadius))
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .onHover { isCopyButtonHovering = $0 }
            .animation(.easeOut(duration: 0.14), value: isCopyButtonHovering)
            .accessibilityLabel(Text(LocalizedStringKey(copyTitle)))
            .help(Text(LocalizedStringKey(copyTitle)))
        }
    }
}

private struct SettingsControlRow<Control: View>: View {
    let title: String
    let description: String?
    let control: Control

    init(
        title: String,
        description: String? = nil,
        @ViewBuilder control: () -> Control
    ) {
        self.title = title
        self.description = description
        self.control = control()
    }

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            VStack(alignment: .leading, spacing: 3) {
                Text(LocalizedStringKey(title))
                    .font(.system(size: 13, weight: .medium))
                if let description {
                    Text(LocalizedStringKey(description))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: AppSpacing.small)
            control
        }
        .frame(minHeight: AppControlMetrics.formControlHeight)
    }
}

private struct SettingsDashedDivider: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0.5))
                path.addLine(to: CGPoint(x: geometry.size.width, y: 0.5))
            }
            .stroke(
                AppTheme.border,
                style: StrokeStyle(
                    lineWidth: 1,
                    lineCap: .butt,
                    dash: SettingsDividerMetrics.dashPattern
                )
            )
        }
        .frame(height: 1)
        .accessibilityHidden(true)
    }
}

struct SettingsSection<Content: View, HeaderTrailing: View>: View {
    let title: String
    let systemImage: String
    let description: String
    let content: Content
    let headerTrailing: HeaderTrailing

    init(
        title: String,
        systemImage: String,
        description: String,
        @ViewBuilder headerTrailing: () -> HeaderTrailing,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
        self.headerTrailing = headerTrailing()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.accentHoverBackground)
                    .clipShape(.rect(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(title))
                        .font(.system(size: 14, weight: .semibold))
                    Text(LocalizedStringKey(description))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: AppSpacing.small)
                headerTrailing
            }

            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.elevatedSurface)
        .clipShape(.rect(cornerRadius: 10))
        .shadow(
            color: AppTheme.accent.opacity(0.035),
            radius: 2,
            y: 1
        )
    }
}

extension SettingsSection where HeaderTrailing == EmptyView {
    init(
        title: String,
        systemImage: String,
        description: String,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            systemImage: systemImage,
            description: description,
            headerTrailing: { EmptyView() },
            content: content
        )
    }
}

struct TagSettingsFlowLayout: View {
    @Environment(\.appLanguage) private var appLanguage
    let tags: [String]
    let onTagRemove: (String) -> Void
    @State private var hoveredTag: String? = nil
    @State private var showDeleteAlert = false
    @State private var selectedTag: String = ""

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                HStack(spacing: 4) {
                    Text(tag)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.leading, 10)
                        .padding(.vertical, 4)
                        .foregroundStyle(AppTheme.accent)

                    Button {
                        selectedTag = tag
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(
                                hoveredTag == tag ? Color.red : AppTheme.accent
                            )
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Circle())
                    .padding(.trailing, 6)
                    .onHover { isHovering in
                        hoveredTag = isHovering ? tag : nil
                    }
                    .accessibilityLabel(
                        AppLocalization.format(
                            "Delete %@ tag",
                            language: appLanguage,
                            arguments: tag
                        )
                    )
                }
                .foregroundStyle(AppTheme.accent)
                .background(AppTheme.accentHoverBackground)
                .clipShape(.capsule)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .alert(
            AppLocalization.format(
                "Delete tag %@?",
                language: appLanguage,
                arguments: selectedTag
            ),
            isPresented: $showDeleteAlert
        ) {
            Button("Delete", role: .destructive) {
                onTagRemove(selectedTag)
                selectedTag = ""
            }
            Button("Cancel", role: .cancel) {
                selectedTag = ""
            }
        } message: {
            Text("This tag will be removed from all notes.")
        }
    }
}
