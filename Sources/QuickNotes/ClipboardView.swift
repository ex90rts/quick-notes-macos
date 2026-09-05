import SwiftUI

struct ClipboardView: View {
    private static let topAnchor = "clipboard-list-top"

    @EnvironmentObject var vm: NotesViewModel
    @State private var isClearHovering = false
    @State private var showClearAlert = false
    @State private var searchQuery = ""
    @State private var isScrollToTopVisible = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            filterBar
            clipboardList
        }
        .background(AppTheme.canvas)
        .frame(minWidth: 520, minHeight: 280)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var filterBar: some View {
        HStack(spacing: AppSpacing.small) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.brandBlue)

            TextField("Filter clipboard content", text: $searchQuery)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                    isSearchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear clipboard filter")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(AppTheme.elevatedSurface)
        .clipShape(.rect(cornerRadius: AppControlMetrics.inputCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: AppControlMetrics.inputCornerRadius)
                .stroke(isSearchFocused ? AppTheme.brandBlue : AppTheme.border)
        }
        .padding(.horizontal, AppSpacing.large)
        .padding(.top, 10)
    }

    private var header: some View {
        SubpageHeader(title: "Clipboard") {
            vm.currentView = .notesList
        } trailing: {
            Button {
                showClearAlert = true
            } label: {
                Label("Clear", systemImage: "trash")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(vm.clipboardData.isEmpty ? AppTheme.disabledForeground : Color.red)
                    .padding(.horizontal, 9)
                    .frame(height: 28)
                    .background(
                        isClearHovering && !vm.clipboardData.isEmpty
                            ? Color.red.opacity(0.10)
                            : (vm.clipboardData.isEmpty ? AppTheme.disabledFill : AppTheme.elevatedSurface)
                    )
                    .clipShape(.rect(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(vm.clipboardData.isEmpty ? AppTheme.border.opacity(0.72) : Color.red.opacity(0.28))
                    }
            }
            .buttonStyle(.plain)
            .onHover { isClearHovering = $0 }
            .disabled(vm.clipboardData.isEmpty)
            .accessibilityLabel("Clear clipboard history")
            .help("Clear clipboard history")
            .alert("Clear clipboard history?", isPresented: $showClearAlert) {
                Button("Clear", role: .destructive) {
                    vm.clearClipboardData()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }

    private var clipboardList: some View {
        Group {
            if vm.clipboardData.isEmpty {
                VStack(alignment: .center, spacing: 8) {
                    Text("No clipboard data yet.")
                        .foregroundColor(.secondary)
                    Text("Copy text in another app to see it here.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if filteredClipboardData.isEmpty {
                VStack(alignment: .center, spacing: 8) {
                    Text("No matching clipboard items.")
                        .foregroundStyle(.secondary)
                    Text("Try a different search.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            Color.clear
                                .frame(height: 0)
                                .id(Self.topAnchor)

                            LazyVStack(spacing: AppSpacing.small) {
                                ForEach(filteredClipboardData) { item in
                                    ClipboardItemRow(
                                        item: item,
                                        highlightQuery: effectiveSearchQuery
                                    )
                                }
                            }
                            .padding(AppSpacing.large)
                        }
                    }
                    .onScrollGeometryChange(for: Bool.self) { geometry in
                        ScrollToTopBehavior.shouldShow(
                            scrollOffset: geometry.visibleRect.minY,
                            viewportHeight: geometry.visibleRect.height
                        )
                    } action: { _, shouldShow in
                        withAnimation(.easeOut(duration: 0.18)) {
                            isScrollToTopVisible = shouldShow
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if isScrollToTopVisible {
                            ScrollToTopButton {
                                withAnimation(.easeInOut(duration: 0.42)) {
                                    proxy.scrollTo(Self.topAnchor, anchor: .top)
                                }
                            }
                            .padding(AppSpacing.large)
                            .transition(
                                .move(edge: .bottom)
                                    .combined(with: .opacity)
                                    .combined(with: .scale(scale: 0.9, anchor: .bottomTrailing))
                            )
                        }
                    }
                    .background(AppTheme.canvas)
                }
            }
        }
    }

    private var filteredClipboardData: [ClipboardItem] {
        vm.filteredClipboardData(matching: searchQuery)
    }

    private var effectiveSearchQuery: String? {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? nil : query
    }
}

struct ClipboardItemRow: View {
    @EnvironmentObject var vm: NotesViewModel
    let item: ClipboardItem
    let highlightQuery: String?
    @State private var showAddToNote = false
    @State private var didJustCopy = false
    @State private var isHovering = false
    @State private var isExpanded = false
    @State private var contentHeight: CGFloat = 0
    @State private var maxHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.timestamp, format: AppFormatters.noteTimestamp)
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundColor(.secondary)

                Spacer()

                HStack(spacing: AppSpacing.xSmall) {
                    ClipboardItemAction(
                        title: didJustCopy ? "Copied" : "Copy",
                        systemImage: didJustCopy ? "checkmark" : "doc.on.doc",
                        accent: didJustCopy ? Color.green : Color.secondary
                    ) {
                        vm.copyClipboardItem(item)
                        didJustCopy = true
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(2))
                            didJustCopy = false
                        }
                    }

                    ClipboardItemAction(
                        title: "Add to Note",
                        systemImage: "plus",
                        accent: AppTheme.brandBlue
                    ) {
                        showAddToNote = true
                    }
                }
            }

            clipboardContent
            .padding(10)
            .background(AppTheme.quietFill)
            .clipShape(.rect(cornerRadius: 6))

            if maxHeight > contentHeight && !isExpanded {
                Button("Show more") {
                    isExpanded = true
                }
                .buttonStyle(.link)
                .font(.system(size: 12))
            } else if isExpanded && maxHeight > 0 {
                Button("Show less") {
                    isExpanded = false
                }
                .buttonStyle(.link)
                .font(.system(size: 12))
            }
        }
        .padding(AppSpacing.medium)
        .background(AppTheme.elevatedSurface)
        .clipShape(.rect(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(AppTheme.border)
        }
        .shadow(
            color: AppTheme.brandBlue.opacity(isHovering ? 0.10 : 0.035),
            radius: isHovering ? 7 : 2,
            y: isHovering ? 3 : 1
        )
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.18), value: isHovering)
        .sheet(isPresented: $showAddToNote) {
            AddNoteFromClipboardView(clipboardItem: item, isPresented: $showAddToNote)
                .environmentObject(vm)
        }
    }

    private var clipboardContent: some View {
        HStack {
            if isExpanded {
                renderedContent
                    .fixedSize(horizontal: false, vertical: true)
                    .id("\(item.id)-expanded")
            } else {
                renderedContent
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
                    .id("\(item.id)-collapsed")
                    .background {
                        GeometryReader { geometry in
                            Color.clear
                                .onAppear {
                                    contentHeight = geometry.size.height
                                }
                                .onChange(of: geometry.size.height) {
                                    contentHeight = geometry.size.height
                                }
                        }
                    }
                    .background {
                        Text(item.content)
                            .font(.system(size: 13))
                            .fixedSize(horizontal: false, vertical: true)
                            .hidden()
                            .background {
                                GeometryReader { geometry in
                                    Color.clear
                                        .onAppear {
                                            maxHeight = geometry.size.height
                                        }
                                        .onChange(of: geometry.size.height) {
                                            maxHeight = geometry.size.height
                                        }
                                }
                            }
                    }
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 13))
    }

    private var renderedContent: some View {
        HighlightedText(item.content, query: highlightQuery)
            .textSelection(.enabled)
    }
}

private struct ClipboardItemAction: View {
    let title: String
    let systemImage: String
    let accent: Color
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(accent)
                .padding(.horizontal, 7)
                .frame(height: 25)
                .background(isHovering ? accent.opacity(0.10) : Color.clear)
                .clipShape(.rect(cornerRadius: 5))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityLabel(title)
    }
}

struct AddNoteFromClipboardView: View {
    private enum Field: Hashable {
        case title
        case content
    }

    @EnvironmentObject var vm: NotesViewModel
    let clipboardItem: ClipboardItem
    @Binding var isPresented: Bool
    @State private var editedTitle = ""
    @State private var editedContent: String
    @State private var selectedTags: Set<String> = []
    @FocusState private var focusedField: Field?

    init(clipboardItem: ClipboardItem, isPresented: Binding<Bool>) {
        self.clipboardItem = clipboardItem
        self._isPresented = isPresented
        self._editedContent = State(initialValue: clipboardItem.content)
    }

    var body: some View {
        AppSheet(
            title: "Add to Note",
            primaryActionTitle: "Add Note",
            isPrimaryActionEnabled: NoteContentPolicy.canSave(editedContent),
            minHeight: 440,
            closeAction: { isPresented = false },
            cancelAction: { isPresented = false },
            primaryAction: addNote
        ) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Title (Optional)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("Give it a short title, or leave it blank", text: $editedTitle)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .title)
                        .padding(.horizontal, 9)
                        .frame(height: AppControlMetrics.formControlHeight)
                        .appInputSurface(isFocused: focusedField == .title)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Note Content")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    TextEditor(text: $editedContent)
                        .font(.system(size: 14))
                        .focused($focusedField, equals: .content)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 120)
                        .padding(.vertical, AppControlMetrics.editorVerticalPadding)
                        .appInputSurface(isFocused: focusedField == .content)
                    NoteContentLengthHint(content: editedContent)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Tags")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    if vm.tags.isEmpty {
                        Text("No tags available")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        TagFlowLayout(
                            tags: vm.tags,
                            selectedTags: selectedTags,
                            onTagToggle: { tag in
                                if selectedTags.contains(tag) {
                                    selectedTags.remove(tag)
                                } else {
                                    selectedTags.insert(tag)
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    private func addNote() {
        vm.addNoteFromClipboard(
            title: editedTitle,
            content: editedContent,
            tags: selectedTags
        )
        vm.removeClipboardItem(clipboardItem)
        vm.currentView = .notesList
        isPresented = false
    }
}
