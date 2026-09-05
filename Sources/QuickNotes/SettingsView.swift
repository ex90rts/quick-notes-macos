import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var vm: NotesViewModel
    @EnvironmentObject var preferences: AppPreferences
    @State private var showTagSortSheet = false
    @State private var exportMessage: String?
    @State private var exportSucceeded = false
    @State private var isExportTooltipVisible = false
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
            TagSortView(isPresented: $showTagSortSheet)
                .environmentObject(vm)
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
                tagsSection
                clipboardSection
                appearanceSection
                exportSection
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
                    Text(error)
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
                SettingsControlRow(title: "Menubar Icon") {
                    SettingsSegmentedControl(
                        options: MenuBarIconStyle.allCases,
                        selection: $preferences.menuBarIconStyle,
                        accessibilityLabel: "Icon style"
                    ) { $0.title }
                }
                .padding(.bottom, AppSpacing.medium)

                RecessedDivider()
                    .padding(.horizontal, AppSpacing.xSmall)

                SettingsControlRow(title: "Panel Size") {
                    SettingsSegmentedControl(
                        options: PanelSize.allCases,
                        selection: $preferences.panelSize,
                        width: 210,
                        accessibilityLabel: "Panel size"
                    ) { $0.title }
                }
                .padding(.top, AppSpacing.medium)
            }
        }
    }

    private var exportSection: some View {
        SettingsSection(
            title: "Export",
            systemImage: "doc.badge.arrow.up",
            description: "Create one Markdown document containing every saved note."
        ) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Markdown document")
                        .font(.system(size: 13, weight: .medium))
                    Text("Includes titles, creation dates, tags, and note content.")
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
                        AppTooltip(text: "No notes to export.")
                            .offset(y: -30)
                            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottomTrailing)))
                    }
                }
                .animation(.easeOut(duration: 0.12), value: isExportTooltipVisible)
            }

            if !vm.notes.isEmpty, let exportMessage {
                Text(exportMessage)
                    .font(.caption)
                    .foregroundStyle(exportSucceeded ? AppTheme.brandBlue : Color.red)
            }
        }
    }

    private var manageableTags: [String] {
        vm.tags.filter { $0 != vm.clipboardTag }
    }

    private func exportMarkdown() {
        guard !vm.notes.isEmpty else { return }
        guard let parentWindow = NSApp.keyWindow else {
            exportSucceeded = false
            exportMessage = "Could not open the export dialog."
            return
        }

        let panel = NSSavePanel()
        panel.title = "Export Quick Notes"
        panel.prompt = "Export"
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = exportFileName

        panel.beginSheetModal(for: parentWindow) { response in
            guard response == .OK, let destination = panel.url else { return }

            do {
                let markdown = MarkdownExporter.document(notes: vm.notes)
                try markdown.write(to: destination, atomically: true, encoding: .utf8)
                exportSucceeded = true
                exportMessage = "Exported \(vm.notes.count) notes to \(destination.lastPathComponent)."
            } catch {
                exportSucceeded = false
                exportMessage = "Export failed: \(error.localizedDescription)"
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
                    isEnabled && isHovering
                        ? AppTheme.hoverFill
                        : AppTheme.elevatedSurface
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
        .accessibilityLabel(accessibilityLabel)
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
            Label(title, systemImage: systemImage)
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
                    Text(title(option))
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
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct SettingsControlRow<Control: View>: View {
    let title: String
    let control: Control

    init(title: String, @ViewBuilder control: () -> Control) {
        self.title = title
        self.control = control()
    }

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
            Spacer(minLength: AppSpacing.small)
            control
        }
        .frame(minHeight: AppControlMetrics.formControlHeight)
    }
}

private struct RecessedDivider: View {
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.primary.opacity(0.18))
                .frame(height: 1)
            Rectangle()
                .fill(Color.primary.opacity(0.055))
                .frame(height: 1)
            Rectangle()
                .fill(Color.white.opacity(0.64))
                .frame(height: 1)
        }
        .clipShape(.rect(cornerRadius: 1.5))
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
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                    Text(description)
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
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppTheme.border)
        }
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
                    .accessibilityLabel("Delete \(tag) tag")
                }
                .foregroundStyle(AppTheme.brandBlue)
                .background(AppTheme.selectedFill)
                .clipShape(.capsule)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .alert("Delete tag \(selectedTag)?", isPresented: $showDeleteAlert) {
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
