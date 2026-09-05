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
        .padding(.horizontal, AppSpacing.medium)
        .padding(.vertical, 10)
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
                        Text(tag)
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 9)
                            .frame(height: 28)
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
                    .frame(width: 28, height: 28)
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
            .frame(height: 32)
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
                    .frame(width: 32, height: 32)
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

    private func isSelected(_ tag: String) -> Bool {
        tag == "All" ? selectedTagFilter.isEmpty : selectedTagFilter == tag
    }
}

struct NotesListView: View {
    @EnvironmentObject var vm: NotesViewModel
    @State private var isHeaderMenuPresented = false
    @State private var isHeaderMenuHovering = false

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
    }

    private var notesList: some View {
        let filtered = vm.filteredNotes
        return ZStack {
            VirtualizedNotesList(notes: filtered)
                .environmentObject(vm)

            if filtered.isEmpty {
                VStack(alignment: .center, spacing: 8) {
                    if let query = vm.effectiveSearchQuery {
                        Text("No notes matching \"\(query)\".")
                            .foregroundColor(.secondary)
                    } else if vm.selectedTagFilter.isEmpty {
                        Text("No notes yet. Click \"Add Note\" to create your first note!")
                            .foregroundColor(.secondary)
                    } else {
                        Text("No notes under tag \"\(vm.selectedTagFilter)\" yet.")
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
            AddNoteView()
                .environmentObject(vm)
        }
        .sheet(isPresented: $vm.showAbout) {
            AboutView()
        }
    }
}

private struct HeaderMenuAction: View {
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
                Text(title)
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

    @EnvironmentObject var vm: NotesViewModel
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    let note: Note
    @State private var showDeleteAlert: Bool = false
    @State private var didJustCopy: Bool = false
    @State private var showEditSheet: Bool = false
    @State private var contentHeight: CGFloat = 0
    @State private var maxHeight: CGFloat = 0
    @State private var isHovering = false
    @State private var hoveredAction: HoveredAction?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(note.timestamp, format: AppFormatters.noteTimestamp)
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 12) {
                    ZStack {
                        Button(action: togglePin) {
                            Image(systemName: note.isPinned ? "pin.slash" : "pin")
                                .frame(width: 14, height: 14)
                                .foregroundStyle(
                                    note.isPinned || hoveredAction == .pin
                                        ? AppTheme.brandBlue
                                        : Color.secondary
                                )
                                .opacity(vm.canTogglePin(for: note) ? 1 : 0.38)
                        }
                        .buttonStyle(.plain)
                        .disabled(!vm.canTogglePin(for: note))
                        .contentShape(Rectangle().inset(by: -8))
                        .accessibilityLabel(note.isPinned ? "Unpin" : "Pin")
                    }
                    .contentShape(Rectangle().inset(by: -8))
                    .onHover { hoveredAction = $0 ? .pin : nil }
                    .overlay(alignment: .top) {
                        if hoveredAction == .pin {
                            AppTooltip(text: pinHelpText)
                                .offset(y: -30)
                                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))
                        }
                    }
                    .zIndex(hoveredAction == .pin ? 1 : 0)

                    Button(action: {
                        vm.copyNote(note)
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
                    .accessibilityLabel(didJustCopy ? "Copied" : "Copy")
                    .help(didJustCopy ? "Copied" : "Copy")

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
                            highlightQuery: vm.effectiveSearchQuery
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
                if note.expanded {
                    renderedContent
                    .font(.system(size: 13))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id("\(note.id)-\(note.expanded)")
                } else {
                    // Collapsed content with line limit
                    renderedContent
                        .font(.system(size: 13))
                        .lineLimit(3)
                        .truncationMode(.tail)
                        .fixedSize(horizontal: false, vertical: true)
                        .id("\(note.id)-\(note.expanded)")
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
                        .background(
                            Text(note.content)
                                .font(.system(size: 13))
                                .fixedSize(horizontal: false, vertical: true)
                                .hidden()
                                .background(
                                    GeometryReader { geometry in
                                        Color.clear
                                            .onAppear {
                                                maxHeight = geometry.size.height
                                            }
                                            .onChange(of: note.content) {
                                                maxHeight = geometry.size.height
                                            }
                                    }
                                )
                        )
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(AppTheme.quietFill)
            .clipShape(.rect(cornerRadius: 6))

            // Show more/less button - only show if content is truncated
            if maxHeight > contentHeight && !note.expanded {
                Button("Show more") {
                    vm.toggleExpand(note)
                }
                .buttonStyle(.link)
                .font(.system(size: 12))
            } else if note.expanded && maxHeight > 0 {
                Button("Show less") {
                    vm.toggleExpand(note)
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
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(AppTheme.border)
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
            EditNoteSheet(note: note, isPresented: $showEditSheet)
                .environmentObject(vm)
        }
    }

    @ViewBuilder
    private var renderedContent: some View {
        if let url = NoteContentLink.url(from: note.content) {
            Link(destination: url) {
                HighlightedText(
                    note.content,
                    query: vm.effectiveSearchQuery,
                    baseForeground: AppTheme.brandBlue
                )
            }
            .buttonStyle(.plain)
            .help("Open link")
        } else {
            HighlightedText(
                note.content,
                query: vm.effectiveSearchQuery
            )
            .textSelection(.enabled)
        }
    }

    private var pinHelpText: String {
        if note.isPinned {
            return "Unpin note"
        }
        return vm.canTogglePin(for: note)
            ? "Pin note"
            : "You can pin up to \(NotesViewModel.maximumPinnedNotes) notes"
    }

    private func togglePin() {
        withAnimation(Self.pinReorderingAnimation) {
            vm.togglePin(note)
        }
    }

    private func deleteNote() {
        let animation = accessibilityReduceMotion
            ? Animation.easeOut(duration: 0.12)
            : Self.deletionAnimation
        withAnimation(animation) {
            vm.deleteNote(note)
        }
    }
}

struct EditNoteSheet: View {
    private enum Field: Hashable {
        case title
        case content
    }

    @EnvironmentObject var vm: NotesViewModel
    let note: Note
    @Binding var isPresented: Bool
    @State private var editedTitle: String
    @State private var editedContent: String
    @State private var editedTags: Set<String>
    @FocusState private var focusedField: Field?

    init(note: Note, isPresented: Binding<Bool>) {
        self.note = note
        self._isPresented = isPresented
        self._editedTitle = State(initialValue: note.title ?? "")
        self._editedContent = State(initialValue: note.content)
        self._editedTags = State(initialValue: Set(note.tags))
    }

    var body: some View {
        AppSheet(
            title: "Edit Note",
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

                    if vm.tags.isEmpty {
                        Text("No tags available")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        TagFlowLayout(
                            tags: vm.tags,
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
        vm.updateNote(
            note,
            title: editedTitle,
            content: editedContent,
            tags: editedTags
        )
        isPresented = false
    }
}
