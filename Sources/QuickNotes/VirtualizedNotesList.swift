import SwiftUI

struct NoteListWindow: Equatable {
    let range: Range<Int>
    let leadingHeight: CGFloat
    let trailingHeight: CGFloat
}

struct NoteListHeightIndex {
    let itemHeights: [CGFloat]
    let itemStarts: [CGFloat]
    let itemEnds: [CGFloat]
    let totalHeight: CGFloat

    init(itemHeights: [CGFloat], spacing: CGFloat) {
        self.itemHeights = itemHeights

        var starts: [CGFloat] = []
        var ends: [CGFloat] = []
        starts.reserveCapacity(itemHeights.count)
        ends.reserveCapacity(itemHeights.count)

        var nextStart: CGFloat = 0
        for height in itemHeights {
            starts.append(nextStart)
            let end = nextStart + height
            ends.append(end)
            nextStart = end + spacing
        }

        itemStarts = starts
        itemEnds = ends
        totalHeight = ends.last ?? 0
    }

    var count: Int {
        itemHeights.count
    }

    func itemRange(at index: Int) -> Range<CGFloat>? {
        guard itemStarts.indices.contains(index) else { return nil }
        return itemStarts[index]..<itemEnds[index]
    }

    func firstItemEnding(atOrAfter position: CGFloat) -> Int {
        lowerBound(in: itemEnds) { $0 >= position }
    }

    func firstItemStarting(after position: CGFloat) -> Int {
        lowerBound(in: itemStarts) { $0 > position }
    }

    private func lowerBound(
        in values: [CGFloat],
        matching predicate: (CGFloat) -> Bool
    ) -> Int {
        var lower = 0
        var upper = values.count

        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if predicate(values[middle]) {
                upper = middle
            } else {
                lower = middle + 1
            }
        }
        return lower
    }
}

enum NewNoteRevealBehavior {
    static let defaultViewportHeight: CGFloat = 320
    static let scrollAnimationDuration = 0.42
    static let targetRenderDelayMilliseconds = 24
    static let scrollSettleDelayMilliseconds = 140

    static func shouldWaitForScrollCompletion(
        itemIndex: Int,
        heightIndex: NoteListHeightIndex,
        visibleRange: Range<CGFloat>
    ) -> Bool {
        !isItemVisible(
            itemIndex: itemIndex,
            heightIndex: heightIndex,
            visibleRange: visibleRange
        )
    }

    static func isItemVisible(
        itemIndex: Int,
        heightIndex: NoteListHeightIndex,
        visibleRange: Range<CGFloat>
    ) -> Bool {
        guard let itemRange = heightIndex.itemRange(at: itemIndex) else { return false }
        return itemRange.overlaps(visibleRange)
    }
}

@MainActor
final class NewNoteScrollSettleObserver: ObservableObject {
    private var pendingNoteID: UUID?
    private var settleTask: Task<Void, Never>?

    func begin(noteID: UUID) {
        settleTask?.cancel()
        settleTask = nil
        pendingNoteID = noteID
    }

    func observeScrollChange(
        noteID: UUID,
        targetIsVisible: Bool,
        completion: @escaping @MainActor (UUID) -> Void
    ) {
        guard pendingNoteID == noteID else { return }

        settleTask?.cancel()
        settleTask = nil
        guard targetIsVisible else { return }

        settleTask = Task { @MainActor [weak self] in
            try? await Task.sleep(
                for: .milliseconds(NewNoteRevealBehavior.scrollSettleDelayMilliseconds)
            )
            guard !Task.isCancelled, self?.pendingNoteID == noteID else { return }
            self?.pendingNoteID = nil
            self?.settleTask = nil
            completion(noteID)
        }
    }

    func cancel() {
        settleTask?.cancel()
        settleTask = nil
        pendingNoteID = nil
    }
}

enum NoteListVirtualizer {
    static func window(
        itemHeights: [CGFloat],
        spacing: CGFloat,
        visibleRange: Range<CGFloat>?,
        overscan: Int = 5
    ) -> NoteListWindow {
        window(
            heightIndex: NoteListHeightIndex(
                itemHeights: itemHeights,
                spacing: spacing
            ),
            visibleRange: visibleRange,
            overscan: overscan
        )
    }

    static func window(
        heightIndex: NoteListHeightIndex,
        visibleRange: Range<CGFloat>?,
        overscan: Int = 5
    ) -> NoteListWindow {
        guard heightIndex.count > 0 else {
            return NoteListWindow(range: 0..<0, leadingHeight: 0, trailingHeight: 0)
        }

        let visibleIndices = visibleItemRange(
            heightIndex: heightIndex,
            visibleRange: visibleRange
        )
        let lowerBound = max(0, visibleIndices.lowerBound - overscan)
        let upperBound = min(heightIndex.count, visibleIndices.upperBound + overscan)
        let leadingHeight = lowerBound > 0
            ? heightIndex.itemStarts[lowerBound]
            : 0
        let trailingHeight = upperBound < heightIndex.count
            ? heightIndex.totalHeight - heightIndex.itemEnds[upperBound - 1]
            : 0

        return NoteListWindow(
            range: lowerBound..<upperBound,
            leadingHeight: leadingHeight,
            trailingHeight: trailingHeight
        )
    }

    private static func visibleItemRange(
        heightIndex: NoteListHeightIndex,
        visibleRange: Range<CGFloat>?
    ) -> Range<Int> {
        guard let visibleRange, visibleRange.upperBound > visibleRange.lowerBound else {
            return 0..<min(heightIndex.count, 4)
        }

        let minimumY = max(0, visibleRange.lowerBound)
        let maximumY = max(minimumY, visibleRange.upperBound)
        let firstVisible = heightIndex.firstItemEnding(atOrAfter: minimumY)
        let visibleUpperBound = heightIndex.firstItemStarting(after: maximumY)

        if firstVisible < visibleUpperBound {
            return firstVisible..<visibleUpperBound
        }

        let fallbackIndex = minimumY >= heightIndex.totalHeight
            ? heightIndex.count - 1
            : 0
        return fallbackIndex..<(fallbackIndex + 1)
    }
}

private struct NoteListViewport: Equatable {
    let minimumY: CGFloat
    let maximumY: CGFloat

    var range: Range<CGFloat> {
        minimumY..<maximumY
    }
}

private struct NoteRowHeightPreferenceKey: PreferenceKey {
    static let defaultValue: [UUID: CGFloat] = [:]

    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

struct VirtualizedNotesList: View {
    private static let estimatedItemHeight: CGFloat = 132
    private static let overscanCount = 5
    private static let topAnchor = "virtual-notes-top"

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    let notes: [Note]
    let availableTags: [String]
    let highlightQuery: String?
    let canPinMore: Bool
    @Binding var newlyCreatedNoteID: UUID?
    @Binding var isFilterBarShadowVisible: Bool
    let onCopy: (Note) -> Void
    let onToggleExpand: (Note) -> Void
    let onTogglePin: (Note) -> Void
    let onToggleTodo: (Note, Int) -> Void
    let onDelete: (Note) -> Void
    let onUpdate: (Note, String, String, Set<String>, NoteRenderingMode) -> Bool
    @State private var measuredHeights: [UUID: CGFloat] = [:]
    @State private var viewport: NoteListViewport?
    @State private var isScrollToTopVisible = false
    @State private var attentionNoteID: UUID?
    @State private var pendingAttentionNoteID: UUID?
    @StateObject private var scrollSettleObserver = NewNoteScrollSettleObserver()

    var body: some View {
        let itemHeights = notes.map {
            measuredHeights[$0.id] ?? Self.estimatedItemHeight
        }
        let heightIndex = NoteListHeightIndex(
            itemHeights: itemHeights,
            spacing: AppSpacing.small
        )
        let currentLayout = NoteListVirtualizer.window(
            heightIndex: heightIndex,
            visibleRange: viewport?.range,
            overscan: Self.overscanCount
        )

        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: 0)
                        .id(Self.topAnchor)

                    VStack(spacing: 0) {
                        Color.clear.frame(height: currentLayout.leadingHeight)

                        VStack(spacing: AppSpacing.small) {
                            ForEach(Array(notes[currentLayout.range])) { note in
                                NoteRow(
                                    note: note,
                                    attentionRequestID: attentionNoteID == note.id ? note.id : nil,
                                    availableTags: availableTags,
                                    highlightQuery: highlightQuery,
                                    canTogglePin: note.isPinned || canPinMore,
                                    onCopy: onCopy,
                                    onToggleExpand: onToggleExpand,
                                    onTogglePin: onTogglePin,
                                    onToggleTodo: onToggleTodo,
                                    onDelete: onDelete,
                                    onUpdate: onUpdate
                                )
                                    .id(note.id)
                                    .transition(.identity)
                                    .background {
                                        GeometryReader { geometry in
                                            Color.clear.preference(
                                                key: NoteRowHeightPreferenceKey.self,
                                                value: [note.id: geometry.size.height]
                                            )
                                        }
                                    }
                            }
                        }

                        Color.clear.frame(height: currentLayout.trailingHeight)
                    }
                    .padding(AppSpacing.large)
                }
            }
            .onPreferenceChange(NoteRowHeightPreferenceKey.self, perform: updateMeasuredHeights)
            .onScrollGeometryChange(for: NoteListViewport.self) { geometry in
                let visibleRect = geometry.visibleRect
                let contentTop = AppSpacing.large
                return NoteListViewport(
                    minimumY: max(0, visibleRect.minY - contentTop),
                    maximumY: max(0, visibleRect.maxY - contentTop)
                )
            } action: { _, newViewport in
                observePendingAttentionScroll(
                    newViewport,
                    heightIndex: heightIndex
                )
                updateViewportIfWindowChanged(
                    newViewport,
                    heightIndex: heightIndex,
                    currentRange: currentLayout.range
                )
            }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                NotesFilterBarShadowBehavior.shouldShow(
                    scrollOffset: geometry.visibleRect.minY
                )
            } action: { _, shouldShow in
                isFilterBarShadowVisible = shouldShow
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
            .task(id: newlyCreatedNoteID) {
                guard let noteID = newlyCreatedNoteID,
                      let noteIndex = notes.firstIndex(where: { $0.id == noteID }) else { return }

                pendingAttentionNoteID = nil
                scrollSettleObserver.cancel()
                let visibleRange = viewport?.range
                    ?? 0..<NewNoteRevealBehavior.defaultViewportHeight
                let shouldWaitForScrollCompletion =
                    NewNoteRevealBehavior.shouldWaitForScrollCompletion(
                        itemIndex: noteIndex,
                        heightIndex: heightIndex,
                        visibleRange: visibleRange
                    )

                if !shouldWaitForScrollCompletion {
                    beginAttention(for: noteID)
                }

                let needsTargetRender = !currentLayout.range.contains(noteIndex)
                if needsTargetRender {
                    let viewportHeight = max(
                        visibleRange.upperBound - visibleRange.lowerBound,
                        NewNoteRevealBehavior.defaultViewportHeight
                    )
                    viewport = NoteListViewport(minimumY: 0, maximumY: viewportHeight)
                }

                await Task.yield()
                if needsTargetRender {
                    try? await Task.sleep(
                        for: .milliseconds(NewNoteRevealBehavior.targetRenderDelayMilliseconds)
                    )
                }
                guard !Task.isCancelled, newlyCreatedNoteID == noteID else { return }
                let scrollAnimation = Animation.easeInOut(
                    duration: NewNoteRevealBehavior.scrollAnimationDuration
                )
                if shouldWaitForScrollCompletion {
                    pendingAttentionNoteID = noteID
                    scrollSettleObserver.begin(noteID: noteID)
                }
                withAnimation(scrollAnimation) {
                    proxy.scrollTo(noteID, anchor: .center)
                }
            }
            .task(id: attentionNoteID) {
                guard let noteID = attentionNoteID else { return }
                let attentionLifetime = accessibilityReduceMotion
                    ? NoteAttentionAnimationMetrics.reducedMotionLifetimeMilliseconds
                    : NoteAttentionAnimationMetrics.standardLifetimeMilliseconds
                try? await Task.sleep(for: .milliseconds(attentionLifetime))
                guard !Task.isCancelled, attentionNoteID == noteID else { return }
                attentionNoteID = nil
                if newlyCreatedNoteID == noteID {
                    newlyCreatedNoteID = nil
                }
            }
        }
    }

    private func beginAttention(for noteID: UUID) {
        guard newlyCreatedNoteID == noteID else { return }
        scrollSettleObserver.cancel()
        pendingAttentionNoteID = nil
        attentionNoteID = noteID
    }

    private func observePendingAttentionScroll(
        _ newViewport: NoteListViewport,
        heightIndex: NoteListHeightIndex
    ) {
        guard let noteID = pendingAttentionNoteID,
              let noteIndex = notes.firstIndex(where: { $0.id == noteID }) else { return }

        let targetIsVisible = NewNoteRevealBehavior.isItemVisible(
            itemIndex: noteIndex,
            heightIndex: heightIndex,
            visibleRange: newViewport.range
        )
        scrollSettleObserver.observeScrollChange(
            noteID: noteID,
            targetIsVisible: targetIsVisible,
            completion: beginAttention
        )
    }

    private func updateMeasuredHeights(_ newHeights: [UUID: CGFloat]) {
        var updatedHeights = measuredHeights
        var didChange = false

        for (id, height) in newHeights where height > 0 {
            if abs((updatedHeights[id] ?? 0) - height) > 0.5 {
                updatedHeights[id] = height
                didChange = true
            }
        }
        if didChange {
            measuredHeights = updatedHeights
        }
    }

    private func updateViewportIfWindowChanged(
        _ newViewport: NoteListViewport,
        heightIndex: NoteListHeightIndex,
        currentRange: Range<Int>
    ) {
        let newWindow = NoteListVirtualizer.window(
            heightIndex: heightIndex,
            visibleRange: newViewport.range,
            overscan: Self.overscanCount
        )
        guard viewport == nil || newWindow.range != currentRange else { return }
        viewport = newViewport
    }
}
