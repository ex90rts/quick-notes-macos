import SwiftUI

struct NoteListWindow: Equatable {
    let range: Range<Int>
    let leadingHeight: CGFloat
    let trailingHeight: CGFloat
}

enum NoteListVirtualizer {
    static func window(
        itemHeights: [CGFloat],
        spacing: CGFloat,
        visibleRange: Range<CGFloat>?,
        overscan: Int = 5
    ) -> NoteListWindow {
        guard !itemHeights.isEmpty else {
            return NoteListWindow(range: 0..<0, leadingHeight: 0, trailingHeight: 0)
        }

        let visibleIndices = visibleItemRange(
            itemHeights: itemHeights,
            spacing: spacing,
            visibleRange: visibleRange
        )
        let lowerBound = max(0, visibleIndices.lowerBound - overscan)
        let upperBound = min(itemHeights.count, visibleIndices.upperBound + overscan)

        return NoteListWindow(
            range: lowerBound..<upperBound,
            leadingHeight: skippedHeight(
                itemHeights[..<lowerBound],
                spacing: spacing,
                includesBoundarySpacing: lowerBound > 0
            ),
            trailingHeight: skippedHeight(
                itemHeights[upperBound...],
                spacing: spacing,
                includesBoundarySpacing: upperBound < itemHeights.count
            )
        )
    }

    private static func visibleItemRange(
        itemHeights: [CGFloat],
        spacing: CGFloat,
        visibleRange: Range<CGFloat>?
    ) -> Range<Int> {
        guard let visibleRange, visibleRange.upperBound > visibleRange.lowerBound else {
            return 0..<min(itemHeights.count, 4)
        }

        let minimumY = max(0, visibleRange.lowerBound)
        let maximumY = max(minimumY, visibleRange.upperBound)
        var itemStart: CGFloat = 0
        var firstVisible: Int?
        var lastVisible: Int?

        for index in itemHeights.indices {
            let itemEnd = itemStart + itemHeights[index]
            if itemEnd >= minimumY && itemStart <= maximumY {
                firstVisible = firstVisible ?? index
                lastVisible = index
            } else if itemStart > maximumY {
                break
            }
            itemStart = itemEnd + spacing
        }

        if let firstVisible, let lastVisible {
            return firstVisible..<(lastVisible + 1)
        }

        let fallbackIndex = minimumY >= itemStart ? itemHeights.count - 1 : 0
        return fallbackIndex..<(fallbackIndex + 1)
    }

    private static func skippedHeight(
        _ heights: ArraySlice<CGFloat>,
        spacing: CGFloat,
        includesBoundarySpacing: Bool
    ) -> CGFloat {
        guard !heights.isEmpty else { return 0 }
        let internalSpacingCount = max(0, heights.count - 1)
        let boundarySpacingCount = includesBoundarySpacing ? 1 : 0
        return heights.reduce(0, +)
            + CGFloat(internalSpacingCount + boundarySpacingCount) * spacing
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

    @EnvironmentObject private var vm: NotesViewModel
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    let notes: [Note]
    @State private var measuredHeights: [UUID: CGFloat] = [:]
    @State private var viewport: NoteListViewport?
    @State private var isScrollToTopVisible = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: layout.leadingHeight)
                        .id(Self.topAnchor)

                    VStack(spacing: AppSpacing.small) {
                        ForEach(Array(notes[layout.range])) { note in
                            NoteRow(note: note)
                                .id(note.id)
                                .transition(noteRemovalTransition)
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

                    Color.clear.frame(height: layout.trailingHeight)
                }
                .padding(AppSpacing.large)
            }
            .background(AppTheme.canvas)
            .onPreferenceChange(NoteRowHeightPreferenceKey.self, perform: updateMeasuredHeights)
            .onScrollGeometryChange(for: NoteListViewport.self) { geometry in
                let visibleRect = geometry.visibleRect
                let contentTop = AppSpacing.large
                return NoteListViewport(
                    minimumY: max(0, visibleRect.minY - contentTop),
                    maximumY: max(0, visibleRect.maxY - contentTop)
                )
            } action: { _, newViewport in
                updateViewportIfWindowChanged(newViewport)
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
            .onChange(of: vm.shouldScrollToTop) {
                guard vm.shouldScrollToTop else { return }
                vm.selectedTagFilter = ""
                viewport = NoteListViewport(minimumY: 0, maximumY: viewport?.maximumY ?? 320)

                Task { @MainActor in
                    await Task.yield()
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(Self.topAnchor, anchor: .top)
                    }
                    vm.shouldScrollToTop = false
                }
            }
        }
    }

    private var itemHeights: [CGFloat] {
        notes.map { measuredHeights[$0.id] ?? Self.estimatedItemHeight }
    }

    private var layout: NoteListWindow {
        NoteListVirtualizer.window(
            itemHeights: itemHeights,
            spacing: AppSpacing.small,
            visibleRange: viewport?.range,
            overscan: Self.overscanCount
        )
    }

    private var noteRemovalTransition: AnyTransition {
        let fade = AnyTransition.opacity
        guard !accessibilityReduceMotion else { return fade }
        return .asymmetric(
            insertion: .identity,
            removal: fade.combined(with: .scale(scale: 0.96, anchor: .trailing))
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

    private func updateViewportIfWindowChanged(_ newViewport: NoteListViewport) {
        let newWindow = NoteListVirtualizer.window(
            itemHeights: itemHeights,
            spacing: AppSpacing.small,
            visibleRange: newViewport.range,
            overscan: Self.overscanCount
        )
        guard viewport == nil || newWindow.range != layout.range else { return }
        viewport = newViewport
    }
}
