import AppKit
import HighlightSwift
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var vm: NotesViewModel
    @EnvironmentObject var preferences: AppPreferences
    @Environment(\.appLanguage) private var appLanguage
    @State private var showTagSortSheet = false
    @State private var exportMessage: String?
    @State private var exportSucceeded = false
    @State private var isExportTooltipVisible = false
    @State private var importAlert: SettingsImportAlert?
    @FocusState private var isTagInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            settingsContent
        }
        .background(AppTheme.canvas)
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
    }

    private var header: some View {
        SubpageHeader(title: "Settings") {
            vm.currentView = .notesList
        }
    }

    private var settingsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                displayLanguageSection
                tagsSection
                clipboardSection
                appearanceSection
                transferSection
            }
            .padding(AppSpacing.large)
        }
        .background(AppTheme.canvas)
    }

    private var tagsSection: some View {
        SettingsSection(
            title: "Tags",
            systemImage: "tag",
            description: "Create labels for filtering and grouping related notes.",
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
                            .tint(AppTheme.brandBlue)
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
            description: "Customize the menu bar and panel."
        ) {
            VStack(spacing: 0) {
                SettingsControlRow(
                    title: "Menubar Icon",
                    description: "Choose the menu bar icon style."
                ) {
                    SettingsSegmentedControl(
                        options: MenuBarIconStyle.allCases,
                        selection: $preferences.menuBarIconStyle,
                        accessibilityLabel: "Icon style"
                    ) { $0.title }
                }
                .padding(.bottom, AppSpacing.medium)

                SettingsDashedDivider()

                SettingsControlRow(
                    title: "Panel Size",
                    description: "Adjust the panel size."
                ) {
                    SettingsSegmentedControl(
                        options: PanelSize.allCases,
                        selection: $preferences.panelSize,
                        width: 210,
                        accessibilityLabel: "Panel size"
                    ) { $0.title }
                }
                .padding(.vertical, AppSpacing.medium)

                SettingsDashedDivider()

                SettingsControlRow(
                    title: "Code Highlight Theme",
                    description: "Code highlighting color scheme for code in note content."
                ) {
                    HStack(spacing: AppSpacing.small) {
                        Picker("", selection: $preferences.codeHighlightTheme) {
                            ForEach(CodeHighlightTheme.allCases) { theme in
                                Text(verbatim: theme.title)
                                    .tag(theme)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .controlSize(.large)
                        .frame(
                            width: 150,
                            height: AppControlMetrics.formControlHeight
                        )
                        .accessibilityLabel(Text("Code highlight theme"))

                        CodeHighlightThemePreviewButton(theme: preferences.codeHighlightTheme)
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
            description: "Move notes between Quick Notes installations using a Markdown document."
        ) {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Export Notes")
                            .font(.system(size: 13, weight: .medium))
                        Text("Save titles, creation dates, tags, and Markdown content.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

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
                        .foregroundStyle(exportSucceeded ? AppTheme.brandBlue : Color.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, AppSpacing.small)
                }

                SettingsDashedDivider()
                    .padding(.vertical, AppSpacing.medium)

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Import Notes")
                            .font(.system(size: 13, weight: .medium))
                        Text("Merge another Quick Notes Markdown export into this library.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

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

    private var displayLanguageSection: some View {
        SettingsSection(
            title: "Display Language",
            systemImage: "globe",
            description: "Follow the system, or choose manually.",
            headerTrailing: {
                Picker("", selection: $preferences.displayLanguage) {
                    ForEach(AppLanguagePreference.allCases) { language in
                        Text(LocalizedStringKey(language.title))
                            .tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.large)
                .frame(
                    width: 180,
                    height: AppControlMetrics.formControlHeight
                )
                .accessibilityLabel(Text("Display language"))
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
    let theme: CodeHighlightTheme
    @State private var isHovering = false
    @State private var isPreviewPresented = false

    var body: some View {
        Image(systemName: "eye")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(isHovering ? AppTheme.brandBlue : Color.secondary)
            .frame(
                width: AppControlMetrics.formControlHeight,
                height: AppControlMetrics.formControlHeight
            )
            .background(isHovering ? AppTheme.selectedFill : AppTheme.quietFill)
            .clipShape(.rect(cornerRadius: AppControlMetrics.inputCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppControlMetrics.inputCornerRadius)
                    .stroke(AppTheme.border)
            }
            .contentShape(.rect)
            .onHover { hovering in
                isHovering = hovering
                isPreviewPresented = hovering
            }
            .popover(isPresented: $isPreviewPresented, arrowEdge: .trailing) {
                CodeHighlightThemePreview(theme: theme)
            }
            .help("Preview code highlight theme")
            .accessibilityElement()
            .accessibilityLabel(Text("Preview code highlight theme"))
    }
}

private struct CodeHighlightThemePreview: View {
    let theme: CodeHighlightTheme

    private let sample = """
    struct Note: Identifiable {
        let id = UUID()
        let title: String
        var isPinned = false
    }
    """

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text(verbatim: theme.title)
                .font(.system(size: 13, weight: .semibold))

            ScrollView(.horizontal) {
                CodeText(sample)
                    .highlightLanguage(.swift)
                    .codeTextColors(.theme(theme.highlightTheme))
                    .font(.system(size: 12, design: .monospaced))
                    .fixedSize(horizontal: true, vertical: true)
                    .padding(AppSpacing.medium)
            }
            .scrollIndicators(.hidden)
            .background(AppTheme.quietFill)
            .clipShape(.rect(cornerRadius: AppControlMetrics.inputCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppControlMetrics.inputCornerRadius)
                    .stroke(AppTheme.border)
            }
        }
        .padding(AppSpacing.large)
        .frame(width: 360, alignment: .leading)
        .background(AppTheme.elevatedSurface)
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
                        : (isHovering ? AppTheme.hoverFill : AppTheme.elevatedSurface)
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
                .foregroundStyle(isEnabled ? AppTheme.brandBlue : AppTheme.disabledForeground)
                .padding(.horizontal, 8)
                .frame(height: 26)
                .background(isHovering && isEnabled ? AppTheme.selectedFill : Color.clear)
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
                        .foregroundStyle(selection == option ? Color.white : Color.primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(.rect)
                        .background(selection == option ? AppTheme.brandBlue : Color.clear)
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

private struct SettingsControlRow<Control: View>: View {
    let title: String
    let description: String
    let control: Control

    init(
        title: String,
        description: String,
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
                Text(LocalizedStringKey(description))
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    .foregroundStyle(AppTheme.brandBlue)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.selectedFill)
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
            color: AppTheme.brandBlue.opacity(0.035),
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
                        .foregroundStyle(.primary)

                    Button {
                        selectedTag = tag
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(hoveredTag == tag ? Color.red : Color.secondary)
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
                .foregroundStyle(AppTheme.brandBlue)
                .background(AppTheme.selectedFill)
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
