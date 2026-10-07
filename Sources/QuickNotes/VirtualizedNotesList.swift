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
    private let waitForScrollSettle: @MainActor () async throws -> Void
    private var pendingNoteID: UUID?
    private var settleTask: Task<Void, Never>?

    init(
        waitForScrollSettle: @escaping @MainActor () async throws -> Void = {
            try await Task.sleep(
                for: .milliseconds(NewNoteRevealBehavior.scrollSettleDelayMilliseconds)
            )
        }
    ) {
        self.waitForScrollSettle = waitForScrollSettle
    }

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

        let waitForScrollSettle = self.waitForScrollSettle
        settleTask = Task { @MainActor [weak self] in
            do {
                try await waitForScrollSettle()
            } catch {
                return
            }
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

enum NoteListHeightStability {
    /// Returns the amount by which the scroll offset must move when rows before
    /// the visible anchor switch from their estimated to measured heights.
    static func scrollCompensation(
        changedHeights: [(index: Int, old: CGFloat, new: CGFloat)],
        anchorIndex: Int
    ) -> CGFloat {
        changedHeights.reduce(into: CGFloat.zero) { compensation, change in
            guard change.index < anchorIndex else { return }
            compensation += change.new - change.old
        }
    }
}

enum NoteListPagination {
    static let pageSize = 50
    static let defaultPreloadDistance: CGFloat = 480

    static func initialCount(totalCount: Int) -> Int {
        min(max(totalCount, 0), pageSize)
    }

    static func nextCount(currentCount: Int, totalCount: Int) -> Int {
        min(max(currentCount, 0) + pageSize, max(totalCount, 0))
    }

    static func shouldLoadNextPage(
        maximumY: CGFloat,
        contentHeight: CGFloat,
        viewportHeight: CGFloat,
        preloadDistance: CGFloat = defaultPreloadDistance
    ) -> Bool {
        guard contentHeight > 0, viewportHeight > 0 else { return false }
        let distanceToBottom = contentHeight - maximumY
        return distanceToBottom <= max(preloadDistance, viewportHeight * 1.5)
    }

    static func shouldResetToFirstPage(
        minimumY: CGFloat,
        loadedCount: Int,
        totalCount: Int,
        topThreshold: CGFloat = 1
    ) -> Bool {
        loadedCount > initialCount(totalCount: totalCount)
            && minimumY <= topThreshold
    }
}

struct NoteListPaginationIdentity: Equatable {
    let selectedTag: String
    let searchQuery: String?
}

private struct NoteListViewport: Equatable {
    let minimumY: CGFloat
    let maximumY: CGFloat
    let contentHeight: CGFloat
    let viewportHeight: CGFloat

    var range: Range<CGFloat> {
        minimumY..<maximumY
    }
}

@MainActor
final class NoteListScrollMetrics: ObservableObject {
    // This object intentionally does not publish offset changes. Updating a
    // SwiftUI @State value for every scroll tick would rebuild the row window
    // while the user is dragging the scrollbar.
    var contentOffsetY: CGFloat = 0
    var correctionGeneration = 0

    func resetToTop() {
        contentOffsetY = 0
        correctionGeneration += 1
    }
}

private struct NoteRowHeightPreferenceKey: PreferenceKey {
    static let defaultValue: [UUID: CGFloat] = [:]

    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

struct VirtualizedNotesList: View {
    private static let fallbackEstimatedItemHeight: CGFloat = 150
    private static let overscanCount = 8
    private static let topAnchor = "virtual-notes-top"

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    let notes: [Note]
    let availableTags: [String]
    let highlightQuery: String?
    let paginationIdentity: NoteListPaginationIdentity
    let canPinMore: Bool
    @Binding var newlyCreatedNoteID: UUID?
    @Binding var isFilterBarShadowVisible: Bool
    let onCopy: (Note) -> Void
    let onCopyIdentifier: (Note) -> Void
    let onToggleExpand: (Note) -> Void
    let onTogglePin: (Note) -> Void
    let onToggleTodo: (Note, Int) -> Void
    let onDelete: (Note) -> Void
    let onUpdate: (Note, String, String, Set<String>, NoteRenderingMode) -> Bool
    @State private var measuredHeights: [UUID: CGFloat] = [:]
    @State private var loadedCount = NoteListPagination.pageSize
    @State private var viewport: NoteListViewport?
    @State private var scrollPosition = ScrollPosition()
    @State private var scrollContainerGeneration = 0
    @State private var isScrollToTopVisible = false
    @State private var attentionNoteID: UUID?
    @State private var pendingAttentionNoteID: UUID?
    @StateObject private var scrollSettleObserver = NewNoteScrollSettleObserver()
    @StateObject private var scrollMetrics = NoteListScrollMetrics()

    var body: some View {
        let containerGeneration = scrollContainerGeneration
        let loadedNotes = Array(notes.prefix(loadedCount))
        let itemHeights = loadedNotes.map {
            measuredHeights[$0.id] ?? Self.estimatedItemHeight(for: $0)
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
                            ForEach(Array(loadedNotes[currentLayout.range])) { note in
                                NoteRow(
                                    note: note,
                                    attentionRequestID: attentionNoteID == note.id ? note.id : nil,
                                    availableTags: availableTags,
                                    highlightQuery: highlightQuery,
                                    canTogglePin: note.isPinned || canPinMore,
                                    onCopy: onCopy,
                                    onCopyIdentifier: onCopyIdentifier,
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
            .scrollPosition($scrollPosition)
            .id(containerGeneration)
            .onPreferenceChange(NoteRowHeightPreferenceKey.self) { newHeights in
                guard containerGeneration == scrollContainerGeneration else { return }
                updateMeasuredHeights(
                    newHeights,
                    heightIndex: heightIndex,
                    currentRange: currentLayout.range
                )
            }
            .onScrollGeometryChange(for: NoteListViewport.self) { geometry in
                let visibleRect = geometry.visibleRect
                let contentTop = AppSpacing.large
                return NoteListViewport(
                    minimumY: max(0, visibleRect.minY - contentTop),
                    maximumY: max(0, visibleRect.maxY - contentTop),
                    contentHeight: max(0, geometry.contentSize.height - contentTop),
                    viewportHeight: visibleRect.height
                )
            } action: { _, newViewport in
                guard containerGeneration == scrollContainerGeneration else { return }
                scrollMetrics.contentOffsetY = newViewport.minimumY
                if NoteListPagination.shouldResetToFirstPage(
                    minimumY: newViewport.minimumY,
                    loadedCount: loadedCount,
                    totalCount: notes.count
                ) {
                    resetPagination()
                } else if loadedCount < notes.count,
                          NoteListPagination.shouldLoadNextPage(
                              maximumY: newViewport.maximumY,
                              contentHeight: newViewport.contentHeight,
                              viewportHeight: newViewport.viewportHeight
                          ) {
                    loadedCount = NoteListPagination.nextCount(
                        currentCount: loadedCount,
                        totalCount: notes.count
                    )
                    scrollMetrics.correctionGeneration += 1
                }
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
                guard containerGeneration == scrollContainerGeneration else { return }
                isFilterBarShadowVisible = shouldShow
            }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                ScrollToTopBehavior.shouldShow(
                    scrollOffset: geometry.visibleRect.minY,
                    viewportHeight: geometry.visibleRect.height
                )
            } action: { _, shouldShow in
                guard containerGeneration == scrollContainerGeneration else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    isScrollToTopVisible = shouldShow
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if isScrollToTopVisible {
                    ScrollToTopButton {
                        // Reusing the virtualized scroll container can preserve its
                        // old viewport or let a height correction replace the jump.
                        // Recreate it together with the first-page layout instead.
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            resetPagination()
                            scrollMetrics.resetToTop()
                            scrollPosition = ScrollPosition(edge: .top)
                            isScrollToTopVisible = false
                            isFilterBarShadowVisible = false
                            scrollContainerGeneration += 1
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

                if noteIndex >= loadedCount {
                    loadedCount = min(
                        notes.count,
                        ((noteIndex / NoteListPagination.pageSize) + 1)
                            * NoteListPagination.pageSize
                    )
                    scrollMetrics.correctionGeneration += 1
                }

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
                    viewport = NoteListViewport(
                        minimumY: 0,
                        maximumY: viewportHeight,
                        contentHeight: heightIndex.totalHeight,
                        viewportHeight: viewportHeight
                    )
                }

                await Task.yield()
                if needsTargetRender {
                    try? await Task.sleep(
                        for: .milliseconds(NewNoteRevealBehavior.targetRenderDelayMilliseconds)
                    )
                }
                guard !Task.isCancelled, newlyCreatedNoteID == noteID else { return }
                if shouldWaitForScrollCompletion {
                    pendingAttentionNoteID = noteID
                    scrollSettleObserver.begin(noteID: noteID)
                }
                proxy.scrollTo(noteID, anchor: .center)
            }
            .task(id: paginationIdentity) {
                resetPagination()
                guard newlyCreatedNoteID == nil else { return }
                await Task.yield()
                guard !Task.isCancelled else { return }
                proxy.scrollTo(Self.topAnchor, anchor: .top)
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
              let noteIndex = notes.firstIndex(where: { $0.id == noteID }),
              noteIndex < heightIndex.count else { return }

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

    private func updateMeasuredHeights(
        _ newHeights: [UUID: CGFloat],
        heightIndex: NoteListHeightIndex,
        currentRange: Range<Int>
    ) {
        var updatedHeights = measuredHeights
        var didChange = false
        var changedRows: [(index: Int, old: CGFloat, new: CGFloat)] = []

        let loadedNotes = Array(notes.prefix(loadedCount))
        for index in currentRange where loadedNotes.indices.contains(index) {
            let id = loadedNotes[index].id
            guard let height = newHeights[id], height > 0 else { continue }
            let oldHeight = updatedHeights[id] ?? Self.estimatedItemHeight(for: loadedNotes[index])
            if abs(oldHeight - height) > 0.5 {
                updatedHeights[id] = height
                didChange = true
                changedRows.append((index: index, old: oldHeight, new: height))
            }
        }
        if didChange {
            measuredHeights = updatedHeights

            let anchorIndex = heightIndex.firstItemEnding(
                atOrAfter: max(0, scrollMetrics.contentOffsetY)
            )
            let compensation = NoteListHeightStability.scrollCompensation(
                changedHeights: changedRows,
                anchorIndex: anchorIndex
            )
            guard abs(compensation) > 0.5 else { return }

            scrollMetrics.correctionGeneration += 1
            let generation = scrollMetrics.correctionGeneration
            Task { @MainActor in
                await Task.yield()
                guard generation == scrollMetrics.correctionGeneration else { return }
                let targetOffset = max(0, scrollMetrics.contentOffsetY + compensation)
                var transaction = Transaction()
                transaction.animation = nil
                withTransaction(transaction) {
                    scrollPosition.scrollTo(y: targetOffset)
                }
            }
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

    private func resetPagination() {
        loadedCount = NoteListPagination.initialCount(totalCount: notes.count)
        let currentIDs = Set(notes.map(\.id))
        measuredHeights = measuredHeights.filter { currentIDs.contains($0.key) }
        viewport = nil
        scrollMetrics.correctionGeneration += 1
    }

    private static func estimatedItemHeight(for note: Note) -> CGFloat {
        let lineCount = max(1, note.content.split(separator: "\n", omittingEmptySubsequences: false).count)
        let estimatedLineCount = note.expanded
            ? min(lineCount, 28)
            : min(lineCount, 5)
        let estimatedContentHeight = note.expanded
            ? CGFloat(estimatedLineCount) * 18
            : min(
                NoteContentLayout.collapsedViewportHeight,
                CGFloat(estimatedLineCount) * 18
            )
        let metadataHeight: CGFloat = note.title?.isEmpty == false || !note.tags.isEmpty ? 28 : 0
        let expandControlHeight: CGFloat = lineCount > 5 ? 32 : 0
        let estimate = 24 + 22 + 6 + metadataHeight + estimatedContentHeight + expandControlHeight
        return max(Self.fallbackEstimatedItemHeight, estimate)
    }
}
