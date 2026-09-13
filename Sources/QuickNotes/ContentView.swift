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
    @State private var isPasteButtonHovering = false
    @State private var clipboardNoteContent: String?
    @State private var clipboardChangeCount = -1
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
        .background(alignment: .topLeading) {
            PasteShortcutMonitor(
                isEnabled: !isHeaderMenuPresented && !vm.showAddNote && !vm.showAbout,
                onPaste: addNoteFromClipboard
            )
            .frame(width: 1, height: 1)
            .allowsHitTesting(false)
        }
        .task(id: vm.isPanelPresented) {
            guard vm.isPanelPresented else { return }
            await refreshClipboardQuickAddAvailability()
        }
        .overlayPreferenceValue(PinTooltipPreferenceKey.self) { tooltip in
            GeometryReader { geometry in
                if let tooltip {
                    let buttonFrame = geometry[tooltip.anchor]
                    AppTooltip(text: tooltip.text)
                        .position(
                            x: buttonFrame.midX,
                            y: buttonFrame.minY - 18
                        )
                        .opacity(tooltip.isPresented ? 1 : 0)
                        .animation(
                            .easeOut(duration: 0.12),
                            value: tooltip.isPresented
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
            Button { vm.showAddNote = true } label: {
                HStack(spacing: HeaderActionLayout.labelSpacing) {
                    Image(systemName: "plus")
                        .font(.system(
                            size: HeaderActionLayout.iconFontSize,
                            weight: .semibold
                        ))
                    Text("Add Note")
                        .font(.system(
                            size: HeaderActionLayout.labelFontSize,
                            weight: .medium
                        ))
                }
            }
            .appProminentButton(
                horizontalPadding: HeaderActionLayout.horizontalPadding
            )

            Button {
                _ = addNoteFromClipboard()
            } label: {
                headerPasteLabel
            }
            .buttonStyle(.plain)
            .fixedSize()
            .contentShape(.rect)
            .disabled(clipboardNoteContent == nil)
            .onHover { isHovering in
                isPasteButtonHovering = isHovering && clipboardNoteContent != nil
            }
            .accessibilityLabel("Add note from clipboard")
            .help("Add note from clipboard")

            Button {
                isHeaderMenuPresented.toggle()
            } label: {
                headerMenuLabel
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
    }

    private var headerPasteLabel: some View {
        HStack(spacing: HeaderActionLayout.labelSpacing) {
            Image(systemName: "clipboard.fill")
                .font(.system(
                    size: HeaderActionLayout.iconFontSize,
                    weight: .semibold
                ))
            Text("Paste")
                .font(.system(
                    size: HeaderActionLayout.labelFontSize,
                    weight: .medium
                ))
        }
        .foregroundStyle(
            clipboardNoteContent == nil
                ? AppTheme.disabledActionForeground
                : AppTheme.secondaryActionForeground
        )
        .padding(.horizontal, HeaderActionLayout.horizontalPadding)
        .frame(height: AppControlMetrics.formControlHeight)
        .background(
            clipboardNoteContent == nil
                ? AppTheme.disabledActionFill
                : (isPasteButtonHovering ? AppTheme.selectedFill : AppTheme.elevatedSurface)
        )
        .clipShape(.rect(cornerRadius: HeaderActionLayout.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: HeaderActionLayout.cornerRadius)
                .stroke(
                    clipboardNoteContent == nil
                        ? AppTheme.disabledActionBorder
                        : AppTheme.border
                )
        }
    }

    private var headerMenuLabel: some View {
        HStack(spacing: HeaderActionLayout.labelSpacing) {
            Image(systemName: "ellipsis")
                .font(.system(
                    size: HeaderActionLayout.iconFontSize,
                    weight: .semibold
                ))
            Text("More")
                .font(.system(
                    size: HeaderActionLayout.labelFontSize,
                    weight: .medium
                ))
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(isHeaderMenuPresented ? AppTheme.brandBlue : Color.primary)
        .padding(.horizontal, HeaderActionLayout.horizontalPadding)
        .frame(height: AppControlMetrics.formControlHeight)
        .background(
            isHeaderMenuPresented || isHeaderMenuHovering
                ? AppTheme.selectedFill
                : AppTheme.elevatedSurface
        )
        .clipShape(.rect(cornerRadius: HeaderActionLayout.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: HeaderActionLayout.cornerRadius)
                .stroke(isHeaderMenuPresented ? AppTheme.brandBlue : AppTheme.border)
        }
    }

    @discardableResult
    private func addNoteFromClipboard() -> Bool {
        updateClipboardQuickAddContent(force: true)
        guard let clipboardNoteContent else { return false }
        return vm.addNoteFromClipboard(
            content: clipboardNoteContent,
            tags: []
        )
    }

    private func refreshClipboardQuickAddAvailability() async {
        updateClipboardQuickAddContent(force: true)

        while !Task.isCancelled, vm.isPanelPresented {
            try? await Task.sleep(
                for: .milliseconds(HeaderMenuBehavior.clipboardRefreshMilliseconds)
            )
            guard !Task.isCancelled, vm.isPanelPresented else { return }
            updateClipboardQuickAddContent()
        }
    }

    private func updateClipboardQuickAddContent(force: Bool = false) {
        let pasteboard = NSPasteboard.general
        guard force || clipboardChangeCount != pasteboard.changeCount else { return }
        clipboardChangeCount = pasteboard.changeCount
        clipboardNoteContent = ClipboardQuickAddContent.sanitizedText(
            from: pasteboard.string(forType: .string)
        )
    }

    private var headerMenu: some View {
        VStack(spacing: 2) {
            HeaderMenuAction(title: "Clipboard History", systemImage: "doc.on.clipboard") {
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
        .background(AppTheme.elevatedSurface)
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
                newlyCreatedNoteID: $vm.newlyCreatedNoteID,
                isFilterBarShadowVisible: $isFilterBarShadowVisible,
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
        .background(AppTheme.canvas)
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

private struct NoteDeletionFogEffect: AnimatableModifier {
    var progress: Double

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .compositingGroup()
            .mask {
                NoteDissolveMask(progress: progress)
            }
            .overlay {
                NoteDissolveParticles(progress: progress)
            }
            .saturation(1 - progress * 0.55)
            .blur(radius: NoteDeletionAnimationMetrics.maximumBlurRadius * progress)
            .scaleEffect(
                x: 1 + progress * 0.012,
                y: 1 - progress * 0.018,
                anchor: .trailing
            )
            .offset(
                x: NoteDeletionAnimationMetrics.horizontalDrift * progress,
                y: -2 * progress
            )
            .opacity(1 - progress * 0.88)
    }
}

private struct NoteDissolveMask: View {
    let progress: Double

    var body: some View {
        Canvas { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(.white)
            )
            context.blendMode = .destinationOut

            for index in 0..<NoteDeletionAnimationMetrics.particleCount {
                let particle = NoteDissolveParticle(index: index)
                let localProgress = particle.localProgress(for: progress)
                guard localProgress > 0 else { continue }

                let center = CGPoint(
                    x: particle.normalizedX * size.width,
                    y: particle.normalizedY * size.height
                )
                let radius = particle.size * (0.55 + localProgress * 2.5)
                let hole = CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                context.fill(
                    Path(ellipseIn: hole),
                    with: .color(.white.opacity(localProgress))
                )
            }
        }
    }
}

private struct NoteDissolveParticles: View {
    let progress: Double

    var body: some View {
        Canvas { context, size in
            for index in 0..<NoteDeletionAnimationMetrics.particleCount {
                let particle = NoteDissolveParticle(index: index)
                let localProgress = particle.localProgress(for: progress)
                guard localProgress > 0, localProgress < 1 else { continue }

                let start = CGPoint(
                    x: particle.normalizedX * size.width,
                    y: particle.normalizedY * size.height
                )
                let drift = 6 + particle.drift * 24
                let center = CGPoint(
                    x: start.x + drift * localProgress,
                    y: start.y + particle.verticalDrift * 15 * localProgress
                )
                let side = particle.size * (1 - localProgress * 0.45)
                let opacity = sin(localProgress * .pi) * 0.8
                let rect = CGRect(
                    x: center.x - side / 2,
                    y: center.y - side / 2,
                    width: side,
                    height: side
                )
                let color = index.isMultiple(of: 7)
                    ? AppTheme.brandBlue
                    : (index.isMultiple(of: 3) ? Color.secondary : Color.primary)
                context.fill(
                    Path(roundedRect: rect, cornerRadius: side * 0.35),
                    with: .color(color.opacity(opacity))
                )
            }
        }
        .allowsHitTesting(false)
    }
}

private struct NoteDissolveParticle {
    let normalizedX: Double
    let normalizedY: Double
    let size: Double
    let drift: Double
    let verticalDrift: Double
    let activation: Double

    init(index: Int) {
        normalizedX = Self.random(index, salt: 11)
        normalizedY = Self.random(index, salt: 29)
        size = 1.2 + Self.random(index, salt: 47) * 2.8
        drift = Self.random(index, salt: 71)
        verticalDrift = Self.random(index, salt: 97) * 2 - 1
        activation = (1 - normalizedX) * 0.34 + Self.random(index, salt: 131) * 0.18
    }

    func localProgress(for progress: Double) -> Double {
        guard progress > activation else { return 0 }
        return min(1, (progress - activation) / max(0.001, 1 - activation))
    }

    private static func random(_ index: Int, salt: Int) -> Double {
        let value = sin(Double(index * 1_103 + salt * 7_919)) * 43_758.5453
        return value - floor(value)
    }
}

private struct PinTooltipPreference {
    let anchor: Anchor<CGRect>
    let text: String
    let isPresented: Bool
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

private struct NoteActionButton<Label: View>: View {
    let isEnabled: Bool
    let action: () -> Void
    let onHover: (Bool) -> Void
    @ViewBuilder let label: () -> Label
    @State private var isHovering = false

    init(
        isEnabled: Bool = true,
        action: @escaping () -> Void,
        onHover: @escaping (Bool) -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.isEnabled = isEnabled
        self.action = action
        self.onHover = onHover
        self.label = label
    }

    var body: some View {
        Button(action: action) {
            label()
                .frame(
                    width: NoteCardLayout.actionIconSize,
                    height: NoteCardLayout.actionIconSize
                )
                .padding(NoteCardLayout.actionHoverPadding)
                .background(
                    isHovering && isEnabled ? AppTheme.hoverFill : Color.clear
                )
                .clipShape(.rect(cornerRadius: NoteCardLayout.actionHoverCornerRadius))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { hovering in
            isHovering = hovering && isEnabled
            onHover(hovering && isEnabled)
        }
        .padding(.horizontal, NoteCardLayout.actionHorizontalMargin)
    }
}

struct NoteRow: View {
    private static let deletionAnimation = Animation.spring(
        response: 0.22,
        dampingFraction: 0.94,
        blendDuration: 0.04
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
    let attentionRequestID: UUID?
    let availableTags: [String]
    let highlightQuery: String?
    let canTogglePin: Bool
    let onCopy: (Note) -> Void
    let onToggleExpand: (Note) -> Void
    let onTogglePin: (Note) -> Void
    let onToggleTodo: (Note, Int) -> Void
    let onDelete: (Note) -> Void
    let onUpdate: (Note, String, String, Set<String>, NoteRenderingMode) -> Bool
    @State private var showDeleteAlert: Bool = false
    @State private var didJustCopy: Bool = false
    @State private var showEditSheet: Bool = false
    @State private var contentHeight: CGFloat = 0
    @State private var maxHeight: CGFloat = 0
    @State private var isHovering = false
    @State private var hoveredAction: HoveredAction?
    @State private var isPinTooltipPresented = false
    @State private var attentionIntensity: Double = 0
    @State private var deletionProgress: Double = 0
    @State private var deletionTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(note.timestamp, format: AppFormatters.noteTimestamp)
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 0) {
                    NoteActionButton(
                        isEnabled: canTogglePin,
                        action: togglePin,
                        onHover: { hoveredAction = $0 ? .pin : nil }
                    ) {
                        Image(systemName: note.isPinned ? "pin.slash" : "pin")
                            .foregroundStyle(
                                note.isPinned || hoveredAction == .pin
                                    ? AppTheme.brandBlue
                                    : Color.secondary
                            )
                            .opacity(canTogglePin ? 1 : 0.38)
                    }
                    .accessibilityLabel(
                        Text(LocalizedStringKey(note.isPinned ? "Unpin" : "Pin"))
                    )
                    .task(id: hoveredAction == .pin) {
                        isPinTooltipPresented = false
                        guard hoveredAction == .pin else { return }

                        try? await Task.sleep(for: .milliseconds(500))
                        guard !Task.isCancelled, hoveredAction == .pin else { return }

                        isPinTooltipPresented = true
                    }
                    .anchorPreference(
                        key: PinTooltipPreferenceKey.self,
                        value: .bounds
                    ) { anchor in
                        guard hoveredAction == .pin else { return nil }
                        return PinTooltipPreference(
                            anchor: anchor,
                            text: pinHelpText,
                            isPresented: isPinTooltipPresented
                        )
                    }

                    NoteActionButton(
                        action: {
                            onCopy(note)
                            didJustCopy = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                didJustCopy = false
                            }
                        },
                        onHover: { hoveredAction = $0 ? .copy : nil }
                    ) {
                        Image(systemName: didJustCopy ? "checkmark" : "doc.on.doc")
                            .foregroundStyle(
                                didJustCopy
                                    ? Color.green
                                    : (hoveredAction == .copy ? AppTheme.brandBlue : Color.secondary)
                            )
                    }
                    .accessibilityLabel(
                        Text(LocalizedStringKey(didJustCopy ? "Copied" : "Copy"))
                    )
                    .help(Text(LocalizedStringKey(didJustCopy ? "Copied" : "Copy")))

                    NoteActionButton(
                        action: { showEditSheet = true },
                        onHover: { hoveredAction = $0 ? .edit : nil }
                    ) {
                        Image(systemName: "highlighter")
                            .foregroundStyle(hoveredAction == .edit ? AppTheme.brandBlue : Color.secondary)
                    }
                    .accessibilityLabel("Edit")
                    .help("Edit")

                    NoteActionButton(
                        action: { showDeleteAlert = true },
                        onHover: { hoveredAction = $0 ? .delete : nil }
                    ) {
                        Image(systemName: "trash")
                            .foregroundStyle(hoveredAction == .delete ? Color.red : Color.secondary)
                    }
                    .accessibilityLabel("Delete")
                    .help("Delete")
                }
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
            contentContainer

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
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .fill(AppTheme.pinnedGold.opacity(0.15 * attentionIntensity))
                .overlay {
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(
                            AppTheme.pinnedGold.opacity(0.82 * attentionIntensity),
                            lineWidth: 1.5
                        )
                }
                .shadow(
                    color: AppTheme.pinnedGold.opacity(0.34 * attentionIntensity),
                    radius: 9
                )
                .allowsHitTesting(false)
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
        .modifier(NoteDeletionFogEffect(progress: deletionProgress))
        .allowsHitTesting(deletionProgress == 0)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.18), value: isHovering)
        .animation(.easeOut(duration: 0.14), value: hoveredAction)
        .animation(Self.pinReorderingAnimation, value: note.isPinned)
        .task(id: attentionRequestID) {
            guard attentionRequestID == note.id else {
                attentionIntensity = 0
                return
            }
            await playAttentionAnimation()
        }
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
        .onDisappear {
            deletionTask?.cancel()
        }
    }

    @ViewBuilder
    private var renderedContent: some View {
        NoteRenderedContent(
            content: note.content,
            renderingMode: note.renderingMode,
            highlightQuery: highlightQuery,
            onToggleTodo: { lineIndex in
                onToggleTodo(note, lineIndex)
            }
        )
    }

    @ViewBuilder
    private var contentContainer: some View {
        if note.renderingMode.rendersCode(for: note.content) {
            contentViewport
        } else {
            contentViewport
                .padding(NoteContentLayout.containerPadding)
                .background(AppTheme.quietFill)
                .clipShape(.rect(cornerRadius: 6))
        }
    }

    private var contentViewport: some View {
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
        guard deletionTask == nil else { return }
        deletionTask = Task { @MainActor in
            if accessibilityReduceMotion {
                withAnimation(.easeOut(duration: 0.16)) {
                    deletionProgress = 1
                }
                try? await Task.sleep(for: .milliseconds(160))
            } else {
                withAnimation(.easeIn(
                    duration: NoteDeletionAnimationMetrics.dissolveDuration
                )) {
                    deletionProgress = 1
                }
                try? await Task.sleep(for: .milliseconds(335))
            }
            guard !Task.isCancelled else { return }

            withAnimation(Self.deletionAnimation) {
                onDelete(note)
            }

            // A persistence failure leaves the row alive; restore it instead of
            // leaving an invisible, non-interactive card behind.
            try? await Task.sleep(for: .milliseconds(140))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                deletionProgress = 0
            }
            deletionTask = nil
        }
    }

    @MainActor
    private func playAttentionAnimation() async {
        if accessibilityReduceMotion {
            withAnimation(.easeOut(duration: 0.18)) {
                attentionIntensity = 0.72
            }
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.22)) {
                attentionIntensity = 0
            }
            return
        }

        for _ in 0..<NoteAttentionAnimationMetrics.pulseCount {
            withAnimation(.easeInOut(
                duration: NoteAttentionAnimationMetrics.pulseInDuration
            )) {
                attentionIntensity = 1
            }
            try? await Task.sleep(
                for: .milliseconds(NoteAttentionAnimationMetrics.pulseInHoldMilliseconds)
            )
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(
                duration: NoteAttentionAnimationMetrics.pulseOutDuration
            )) {
                attentionIntensity = 0.12
            }
            try? await Task.sleep(
                for: .milliseconds(NoteAttentionAnimationMetrics.pulseOutHoldMilliseconds)
            )
            guard !Task.isCancelled else { return }
        }

        withAnimation(.easeOut(duration: 0.22)) {
            attentionIntensity = 0
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
    let onSave: (Note, String, String, Set<String>, NoteRenderingMode) -> Bool
    @State private var editedTitle: String
    @State private var editedContent: String
    @State private var editedTags: Set<String>
    @State private var editedRenderingMode: NoteRenderingMode
    @FocusState private var focusedField: Field?

    init(
        note: Note,
        availableTags: [String],
        isPresented: Binding<Bool>,
        language: SupportedAppLanguage,
        onSave: @escaping (Note, String, String, Set<String>, NoteRenderingMode) -> Bool
    ) {
        self.note = note
        self.availableTags = availableTags
        self._isPresented = isPresented
        self.language = language
        self.onSave = onSave
        self._editedTitle = State(initialValue: note.title ?? "")
        self._editedContent = State(initialValue: note.content)
        self._editedTags = State(initialValue: Set(note.tags))
        let editableRenderingMode = note.renderingMode == .code(.automatic)
            ? NoteRenderingMode.automatic
            : note.renderingMode
        self._editedRenderingMode = State(initialValue: editableRenderingMode)
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
                    VStack(alignment: .leading, spacing: AppControlMetrics.editorMetadataSpacing) {
                        TextEditor(text: $editedContent)
                            .font(.system(size: 14))
                            .focused($focusedField, equals: .content)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 120)
                            .padding(.vertical, AppControlMetrics.editorVerticalPadding)
                            .appInputSurface(isFocused: focusedField == .content)

                        HStack {
                            NoteRenderingModePicker(renderingMode: $editedRenderingMode)

                            Spacer()

                            NoteContentLengthHint(content: editedContent)
                        }
                    }
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
            editedTags,
            editedRenderingMode
        ) else { return }
        isPresented = false
    }
}
