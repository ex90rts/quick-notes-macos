import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vm: NotesViewModel

    var body: some View {
        switch vm.currentView {
        case .notesList:
            NotesListView()
                .environmentObject(vm)
        case .clipboardData:
            ClipboardView()
                .environmentObject(vm)
        case .settings:
            SettingsView()
                .environmentObject(vm)
        }
    }
}

struct TagFilterFlowLayout: View {
    @Binding var selectedTagFilter: String
    @Binding var isSearchPresented: Bool
    @Binding var searchQuery: String
    let tags: [String]
    let clipboardTag: String
    @State private var isSearchButtonHovering = false
    @State private var isCloseSearchHovering = false
    @State private var hoveredTag: String?
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        Group {
            if isSearchPresented {
                searchField
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                tagControls
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isSearchPresented)
        .frame(minHeight: NotesFilterBarLayout.controlHeight, alignment: .top)
        .padding(.horizontal, AppSpacing.medium)
        .padding(.vertical, NotesFilterBarLayout.verticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tagControls: some View {
        HStack(alignment: .top, spacing: AppSpacing.small) {
            FlowLayout(spacing: AppSpacing.small) {
                ForEach(allTags, id: \.self) { tag in
                    let selected = isSelected(tag)
                    Button {
                        selectedTagFilter = tag == "All" ? "" : tag
                    } label: {
                        tagLabel(tag)
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 9)
                            .frame(height: NotesFilterBarLayout.controlHeight)
                            .foregroundStyle(selected ? Color.white : Color.primary)
                            .background(
                                selected
                                    ? AppTheme.brandBlue
                                    : (hoveredTag == tag ? AppTheme.brandBlue.opacity(0.07) : AppTheme.elevatedSurface)
                            )
                            .clipShape(.capsule)
                            .overlay {
                                Capsule()
                                    .stroke(selected ? AppTheme.brandBlue : AppTheme.border)
                            }
                    }
                    .buttonStyle(.plain)
                    .onHover { hoveredTag = $0 ? tag : nil }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isSearchPresented = true
                }
                Task { @MainActor in
                    await Task.yield()
                    isSearchFocused = true
                }
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.brandBlue)
                    .frame(
                        width: NotesFilterBarLayout.controlHeight,
                        height: NotesFilterBarLayout.controlHeight
                    )
                    .background(isSearchButtonHovering ? AppTheme.selectedFill : AppTheme.elevatedSurface)
                    .clipShape(.capsule)
                    .overlay {
                        Capsule().stroke(AppTheme.border)
                    }
            }
            .buttonStyle(.plain)
            .fixedSize()
            .onHover { isSearchButtonHovering = $0 }
            .accessibilityLabel("Search notes")
            .help("Search titles and content")
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.brandBlue)

                TextField("Search titles and content (2+ characters)", text: $searchQuery)
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
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 10)
            .frame(height: NotesFilterBarLayout.controlHeight)
            .background(AppTheme.elevatedSurface)
            .clipShape(.rect(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSearchFocused ? AppTheme.brandBlue : AppTheme.border)
            }

            Button {
                searchQuery = ""
                withAnimation(.easeInOut(duration: 0.18)) {
                    isSearchPresented = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(
                        width: NotesFilterBarLayout.controlHeight,
                        height: NotesFilterBarLayout.controlHeight
                    )
                    .background(
                        isCloseSearchHovering
                            ? AppTheme.hoverFill
                            : AppTheme.elevatedSurface
                    )
                    .clipShape(.circle)
                    .overlay {
                        Circle().stroke(AppTheme.border)
                    }
            }
            .buttonStyle(.plain)
            .fixedSize()
            .onHover { isCloseSearchHovering = $0 }
            .accessibilityLabel("Close search")
            .help("Close search")
        }
    }

    private var allTags: [String] {
        ["All", clipboardTag] + tags.filter { $0 != clipboardTag }
    }

    @ViewBuilder
    private func tagLabel(_ tag: String) -> some View {
        if tag == "All" {
            Text("All")
        } else if tag == clipboardTag {
            Text("Clipboard")
        } else {
            Text(verbatim: tag)
        }
    }

    private func isSelected(_ tag: String) -> Bool {
        tag == "All" ? selectedTagFilter.isEmpty : selectedTagFilter == tag
    }
}

struct NotesListView: View {
    @EnvironmentObject var vm: NotesViewModel
    @Environment(\.appLanguage) private var appLanguage
    @State private var isHeaderMenuPresented = false
    @State private var isHeaderMenuHovering = false
    @State private var isFilterBarShadowVisible = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            filterBar
            notesList
        }
        .frame(minWidth: 520, minHeight: 280)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.canvas)
        .overlayPreferenceValue(PinTooltipPreferenceKey.self) { tooltip in
            GeometryReader { geometry in
                if let tooltip {
                    let buttonFrame = geometry[tooltip.anchor]
                    AppTooltip(text: tooltip.text)
                        .position(
                            x: buttonFrame.midX,
                            y: buttonFrame.minY - 18
                        )
                        .transition(
                            .opacity.combined(
                                with: .scale(scale: 0.96, anchor: .bottom)
                            )
                        )
                }
            }
            .allowsHitTesting(false)
        }
    }

    private var header: some View {
        HStack(spacing: AppSpacing.small) {
            if let appIcon = NSImage(named: "AppIcon") {
                Image(nsImage: appIcon)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .clipShape(.rect(cornerRadius: 6))
                    .shadow(color: AppTheme.brandBlue.opacity(0.14), radius: 3, y: 1)
                    .accessibilityHidden(true)
            }

            Text("Quick Notes")
                .font(.title3)
                .fontWeight(.semibold)
            Spacer()
            Button("Add Note") { vm.showAddNote = true }
                .appProminentButton()

            Button {
                isHeaderMenuPresented.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .semibold))
                    Text("More")
                        .font(.system(size: 12, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(isHeaderMenuPresented ? AppTheme.brandBlue : Color.primary)
                .padding(.horizontal, 10)
                .frame(height: AppControlMetrics.formControlHeight)
                .background(
                    isHeaderMenuPresented || isHeaderMenuHovering
                        ? AppTheme.selectedFill
                        : AppTheme.elevatedSurface
                )
                .clipShape(.rect(cornerRadius: 7))
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(isHeaderMenuPresented ? AppTheme.brandBlue : AppTheme.border)
                }
            }
            .buttonStyle(.plain)
            .fixedSize()
            .contentShape(.rect)
            .onHover { isHeaderMenuHovering = $0 }
            .popover(isPresented: $isHeaderMenuPresented, arrowEdge: .top) {
                headerMenu
            }
            .accessibilityLabel("More options")
            .help("More options")
        }
        .padding(AppSpacing.medium)
        .background(AppTheme.canvas)
    }

    private var headerMenu: some View {
        VStack(spacing: 2) {
            HeaderMenuAction(title: "Clipboard", systemImage: "doc.on.clipboard") {
                isHeaderMenuPresented = false
                vm.currentView = .clipboardData
            }

            HeaderMenuAction(title: "Settings", systemImage: "gearshape") {
                isHeaderMenuPresented = false
                vm.currentView = .settings
            }

            HeaderMenuAction(title: "About", systemImage: "info.circle") {
                isHeaderMenuPresented = false
                Task { @MainActor in
                    await Task.yield()
                    vm.showAbout = true
                }
            }

            Divider()
                .padding(.vertical, 3)

            HeaderMenuAction(
                title: "Quit Quick Notes",
                systemImage: "power",
                isDestructive: true
            ) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(6)
        .frame(width: 184)
        .background(AppTheme.modalSurface)
    }

    // New note sheet presentation
    private var filterBar: some View {
        TagFilterFlowLayout(
            selectedTagFilter: $vm.selectedTagFilter,
            isSearchPresented: $vm.isSearchPresented,
            searchQuery: $vm.searchQuery,
            tags: vm.tags,
            clipboardTag: vm.clipboardTag
        )
        .background(AppTheme.surface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.08),
                    Color.black.opacity(0.025),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: NotesFilterBarLayout.shadowHeight)
            .offset(y: NotesFilterBarLayout.shadowHeight)
            .opacity(isFilterBarShadowVisible ? 1 : 0)
            .allowsHitTesting(false)
        }
        .animation(.easeOut(duration: 0.15), value: isFilterBarShadowVisible)
        .zIndex(1)
    }

    private var notesList: some View {
        let effectiveSearchQuery = vm.effectiveSearchQuery
        let filtered = vm.filteredNotes(matching: effectiveSearchQuery)
        let canPinMore = vm.notes.lazy.filter(\.isPinned).count
            < NotesViewModel.maximumPinnedNotes
        return ZStack {
            VirtualizedNotesList(
                notes: filtered,
                availableTags: vm.tags,
                highlightQuery: effectiveSearchQuery,
                canPinMore: canPinMore,
                shouldScrollToTop: $vm.shouldScrollToTop,
                isFilterBarShadowVisible: $isFilterBarShadowVisible,
                selectedTagFilter: $vm.selectedTagFilter,
                onCopy: vm.copyNote,
                onToggleExpand: vm.toggleExpand,
                onTogglePin: vm.togglePin,
                onToggleTodo: vm.toggleTodo,
                onDelete: vm.deleteNote,
                onUpdate: vm.updateNote
            )

            if filtered.isEmpty {
                VStack(alignment: .center, spacing: 8) {
                    if let query = effectiveSearchQuery {
                        Text(verbatim: AppLocalization.format(
                            "No notes matching \"%@\".",
                            language: appLanguage,
                            arguments: query
                        ))
                            .foregroundColor(.secondary)
                    } else if vm.selectedTagFilter.isEmpty {
                        Text("No notes yet. Click \"Add Note\" to create your first note!")
                            .foregroundColor(.secondary)
                    } else {
                        Text(verbatim: AppLocalization.format(
                            "No notes under tag \"%@\" yet.",
                            language: appLanguage,
                            arguments: vm.selectedTagFilter
                        ))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .transition(.opacity)
                .allowsHitTesting(false)
            }
        }
        .sheet(isPresented: $vm.showAddNote) {
            AddNoteView(language: appLanguage)
                .environmentObject(vm)
        }
        .sheet(isPresented: $vm.showAbout) {
            AboutView(language: appLanguage)
        }
    }
}

private struct HeaderMenuAction: View {
    @Environment(\.appLanguage) private var appLanguage
    let title: String
    let systemImage: String
    var isDestructive = false
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.small) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 16)
                Text(verbatim: AppLocalization.string(title, language: appLanguage))
                    .font(.system(size: 13, weight: .medium))
                Spacer(minLength: 0)
            }
            .foregroundStyle(isDestructive ? Color.red : Color.primary)
            .padding(.horizontal, AppSpacing.small)
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            .background(
                isHovering
                    ? (isDestructive ? Color.red.opacity(0.10) : AppTheme.hoverFill)
                    : Color.clear
            )
            .clipShape(.rect(cornerRadius: 6))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

private struct PinnedNoteCornerBadge: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + 9))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + 9, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct PinTooltipPreference {
    let anchor: Anchor<CGRect>
    let text: String
}

private struct PinTooltipPreferenceKey: PreferenceKey {
    static let defaultValue: PinTooltipPreference? = nil

    static func reduce(
        value: inout PinTooltipPreference?,
        nextValue: () -> PinTooltipPreference?
    ) {
        if let nextValue = nextValue() {
            value = nextValue
        }
    }
}

struct NoteRow: View {
    private static let deletionAnimation = Animation.spring(
        response: 0.28,
        dampingFraction: 0.92,
        blendDuration: 0.08
    )
    private static let pinReorderingAnimation = Animation.spring(
        response: 0.44,
        dampingFraction: 0.86,
        blendDuration: 0.12
    )

    private enum HoveredAction: Equatable {
        case pin
        case copy
        case edit
        case delete
    }

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.appLanguage) private var appLanguage
    let note: Note
    let availableTags: [String]
    let highlightQuery: String?
    let canTogglePin: Bool
    let onCopy: (Note) -> Void
    let onToggleExpand: (Note) -> Void
    let onTogglePin: (Note) -> Void
    let onToggleTodo: (Note, Int) -> Void
    let onDelete: (Note) -> Void
    let onUpdate: (Note, String, String, Set<String>) -> Bool
    @State private var showDeleteAlert: Bool = false
    @State private var didJustCopy: Bool = false
    @State private var showEditSheet: Bool = false
    @State private var contentHeight: CGFloat = 0
    @State private var maxHeight: CGFloat = 0
    @State private var isHovering = false
    @State private var hoveredAction: HoveredAction?
    @State private var isPinTooltipPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(note.timestamp, format: AppFormatters.noteTimestamp)
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                Spacer()
                HStack(spacing: NoteCardLayout.actionSpacing) {
                    ZStack {
                        Button(action: togglePin) {
                            Image(systemName: note.isPinned ? "pin.slash" : "pin")
                                .frame(width: 14, height: 14)
                                .foregroundStyle(
                                    note.isPinned || hoveredAction == .pin
                                        ? AppTheme.brandBlue
                                        : Color.secondary
                                )
                                .opacity(canTogglePin ? 1 : 0.38)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canTogglePin)
                        .contentShape(Rectangle().inset(by: -8))
                        .accessibilityLabel(
                            Text(LocalizedStringKey(note.isPinned ? "Unpin" : "Pin"))
                        )
                    }
                    .contentShape(Rectangle().inset(by: -8))
                    .onHover { hoveredAction = $0 ? .pin : nil }
                    .task(id: hoveredAction == .pin) {
                        isPinTooltipPresented = false
                        guard hoveredAction == .pin else { return }

                        try? await Task.sleep(for: .milliseconds(500))
                        guard !Task.isCancelled, hoveredAction == .pin else { return }

                        withAnimation(.easeOut(duration: 0.12)) {
                            isPinTooltipPresented = true
                        }
                    }
                    .anchorPreference(
                        key: PinTooltipPreferenceKey.self,
                        value: .bounds
                    ) { anchor in
                        guard isPinTooltipPresented else { return nil }
                        return PinTooltipPreference(
                            anchor: anchor,
                            text: pinHelpText
                        )
                    }

                    Button(action: {
                        onCopy(note)
                        didJustCopy = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            didJustCopy = false
                        }
                    }) {
                        Image(systemName: didJustCopy ? "checkmark" : "doc.on.doc")
                            .frame(width: 14, height: 14)
                            .foregroundStyle(
                                didJustCopy
                                    ? Color.green
                                    : (hoveredAction == .copy ? AppTheme.brandBlue : Color.secondary)
                            )
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle().inset(by: -8))
                    .onHover { hoveredAction = $0 ? .copy : nil }
                    .accessibilityLabel(
                        Text(LocalizedStringKey(didJustCopy ? "Copied" : "Copy"))
                    )
                    .help(Text(LocalizedStringKey(didJustCopy ? "Copied" : "Copy")))

                    Button(action: { showEditSheet = true }) {
                        Image(systemName: "highlighter")
                            .frame(width: 14, height: 14)
                            .foregroundStyle(hoveredAction == .edit ? AppTheme.brandBlue : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle().inset(by: -8))
                    .onHover { hoveredAction = $0 ? .edit : nil }
                    .accessibilityLabel("Edit")
                    .help("Edit")

                    Button(action: { showDeleteAlert = true }) {
                        Image(systemName: "trash")
                            .frame(width: 14, height: 14)
                            .foregroundStyle(hoveredAction == .delete ? Color.red : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle().inset(by: -8))
                    .onHover { hoveredAction = $0 ? .delete : nil }
                    .accessibilityLabel("Delete")
                    .help("Delete")
                }
                .buttonStyle(.link)
            }

            if note.title?.isEmpty == false || !note.tags.isEmpty {
                FlowLayout(spacing: AppSpacing.xSmall) {
                    if let title = note.title, !title.isEmpty {
                        NoteMetadataBadge(
                            text: title,
                            kind: .title,
                            highlightQuery: highlightQuery
                        )
                    }
                    ForEach(note.tags, id: \.self) { tag in
                        NoteMetadataBadge(text: tag, kind: .tag)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 2)
            }

            // Content
            HStack {
                renderedContent
                    .font(.system(size: 13))
                    .fixedSize(horizontal: false, vertical: true)
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .onAppear {
                                    maxHeight = geometry.size.height
                                }
                                .onChange(of: geometry.size.height) {
                                    maxHeight = geometry.size.height
                                }
                        }
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(
                        maxHeight: note.expanded ? nil : NoteContentLayout.collapsedViewportHeight,
                        alignment: .top
                    )
                    .clipped()
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .onAppear {
                                    contentHeight = geometry.size.height
                                }
                                .onChange(of: geometry.size.height) {
                                    contentHeight = geometry.size.height
                                }
                        }
                    )
                    .id("\(note.id)-\(note.expanded)-\(note.content)")
                Spacer(minLength: 0)
            }
            .padding(NoteContentLayout.containerPadding)
            .background(AppTheme.quietFill)
            .clipShape(.rect(cornerRadius: 6))

            // Show more/less button - only show if content is truncated
            if maxHeight > contentHeight + 0.5 && !note.expanded {
                Button("Show more") {
                    onToggleExpand(note)
                }
                .buttonStyle(.link)
                .font(.system(size: 12))
            } else if note.expanded && maxHeight > 0 {
                Button("Show less") {
                    onToggleExpand(note)
                }
                .buttonStyle(.link)
                .font(.system(size: 12))
            }
        }
        .padding(AppSpacing.medium)
        .background {
            RoundedRectangle(cornerRadius: 9)
                .fill(AppTheme.elevatedSurface)
        }
        .overlay(alignment: .topLeading) {
            if note.isPinned {
                ZStack {
                    PinnedNoteCornerBadge()
                        .fill(AppTheme.pinnedGold)

                    Text("T")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
                        .offset(x: -3, y: -4)
                }
                    .frame(width: 21, height: 21)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .transition(
                        .scale(scale: 0.55, anchor: .topLeading)
                            .combined(with: .opacity)
                    )
            }
        }
        .shadow(
            color: AppTheme.brandBlue.opacity(isHovering ? 0.10 : 0.035),
            radius: isHovering ? 7 : 2,
            y: isHovering ? 3 : 1
        )
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.18), value: isHovering)
        .animation(.easeOut(duration: 0.14), value: hoveredAction)
        .animation(Self.pinReorderingAnimation, value: note.isPinned)
        .alert("Delete this note?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive, action: deleteNote)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
        .sheet(isPresented: $showEditSheet) {
            EditNoteSheet(
                note: note,
                availableTags: availableTags,
                isPresented: $showEditSheet,
                language: appLanguage,
                onSave: onUpdate
            )
        }
    }

    @ViewBuilder
    private var renderedContent: some View {
        NoteRenderedContent(
            content: note.content,
            highlightQuery: highlightQuery,
            onToggleTodo: { lineIndex in
                onToggleTodo(note, lineIndex)
            }
        )
    }

    private var pinHelpText: String {
        if note.isPinned {
            return AppLocalization.string("Unpin note", language: appLanguage)
        }
        if canTogglePin {
            return AppLocalization.string("Pin note", language: appLanguage)
        }
        return AppLocalization.format(
            "You can pin up to %lld notes",
            language: appLanguage,
            arguments: Int64(NotesViewModel.maximumPinnedNotes)
        )
    }

    private func togglePin() {
        withAnimation(Self.pinReorderingAnimation) {
            onTogglePin(note)
        }
    }

    private func deleteNote() {
        let animation = accessibilityReduceMotion
            ? Animation.easeOut(duration: 0.12)
            : Self.deletionAnimation
        withAnimation(animation) {
            onDelete(note)
        }
    }
}

struct EditNoteSheet: View {
    private enum Field: Hashable {
        case title
        case content
    }

    let note: Note
    let availableTags: [String]
    @Binding var isPresented: Bool
    let language: SupportedAppLanguage
    let onSave: (Note, String, String, Set<String>) -> Bool
    @State private var editedTitle: String
    @State private var editedContent: String
    @State private var editedTags: Set<String>
    @FocusState private var focusedField: Field?

    init(
        note: Note,
        availableTags: [String],
        isPresented: Binding<Bool>,
        language: SupportedAppLanguage,
        onSave: @escaping (Note, String, String, Set<String>) -> Bool
    ) {
        self.note = note
        self.availableTags = availableTags
        self._isPresented = isPresented
        self.language = language
        self.onSave = onSave
        self._editedTitle = State(initialValue: note.title ?? "")
        self._editedContent = State(initialValue: note.content)
        self._editedTags = State(initialValue: Set(note.tags))
    }

    var body: some View {
        AppSheet(
            title: "Edit Note",
            language: language,
            primaryActionTitle: "Save",
            isPrimaryActionEnabled: NoteContentPolicy.canSave(editedContent),
            minHeight: 450,
            closeAction: { isPresented = false },
            cancelAction: { isPresented = false },
            primaryAction: save
        ) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Title (Optional)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
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

                    if availableTags.isEmpty {
                        Text("No tags available")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        TagFlowLayout(
                            tags: availableTags,
                            selectedTags: editedTags,
                            onTagToggle: { tag in
                                if editedTags.contains(tag) {
                                    editedTags.remove(tag)
                                } else {
                                    editedTags.insert(tag)
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    private func save() {
        guard onSave(
            note,
            editedTitle,
            editedContent,
            editedTags
        ) else { return }
        isPresented = false
    }
}
