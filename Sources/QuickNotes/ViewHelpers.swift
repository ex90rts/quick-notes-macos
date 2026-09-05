import AppKit
import SwiftUI

enum AppTheme {
    private static let modalNSColor = NSColor.windowBackgroundColor.blended(
        withFraction: 0.5,
        of: NSColor.textBackgroundColor
    ) ?? NSColor.controlBackgroundColor

    static let brandBlue = Color(red: 0.29, green: 0.53, blue: 0.91)
    static let brandBlueDeep = Color(red: 0.22, green: 0.47, blue: 0.84)
    static let pinnedGold = Color(red: 0.93, green: 0.65, blue: 0.16)
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let elevatedSurface = Color(nsColor: .textBackgroundColor)
    static let inputSurface = Color(nsColor: .textBackgroundColor)
    static let modalSurface = Color(nsColor: modalNSColor)
    static let border = Color(nsColor: .separatorColor).opacity(0.72)
    static let quietFill = Color.primary.opacity(0.055)
    static let hoverFill = Color.primary.opacity(0.085)
    static let selectedFill = brandBlue.opacity(0.12)
    static let disabledFill = Color.primary.opacity(0.045)
    static let disabledForeground = Color(nsColor: .disabledControlTextColor)
    static let secondaryActionFill = Color(
        red: 235.0 / 255.0,
        green: 235.0 / 255.0,
        blue: 235.0 / 255.0
    )
    static let secondaryActionForeground = Color(
        red: 71.0 / 255.0,
        green: 71.0 / 255.0,
        blue: 71.0 / 255.0
    )
    static let disabledActionFill = Color(
        red: 235.0 / 255.0,
        green: 235.0 / 255.0,
        blue: 235.0 / 255.0
    )
    static let disabledActionForeground = Color(
        red: 181.0 / 255.0,
        green: 181.0 / 255.0,
        blue: 181.0 / 255.0
    )
    static let tooltipBackground = Color(nsColor: .labelColor).opacity(0.92)
    static let tooltipForeground = Color(nsColor: .windowBackgroundColor)
    static let titleGradient = LinearGradient(
        colors: [brandBlueDeep, brandBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

enum AppSpacing {
    static let xSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xLarge: CGFloat = 20
}

enum AppControlMetrics {
    static let formControlHeight: CGFloat = 30
    static let inputCornerRadius: CGFloat = 6
    static let editorVerticalPadding: CGFloat = 6
}

enum ScrollToTopBehavior {
    static let visibleViewportCount: CGFloat = 2

    static func shouldShow(scrollOffset: CGFloat, viewportHeight: CGFloat) -> Bool {
        guard viewportHeight > 0 else { return false }
        let scrollThreshold = viewportHeight * (visibleViewportCount - 1)
        return max(0, scrollOffset) > scrollThreshold
    }
}

struct ScrollToTopButton: View {
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isHovering ? Color.white : AppTheme.brandBlueDeep)
                .frame(width: 34, height: 34)
                .background(isHovering ? AppTheme.brandBlue : AppTheme.elevatedSurface)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(isHovering ? AppTheme.brandBlueDeep.opacity(0.45) : AppTheme.border)
                }
                .shadow(
                    color: AppTheme.brandBlue.opacity(isHovering ? 0.22 : 0.12),
                    radius: isHovering ? 7 : 4,
                    y: 2
                )
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .onHover { isHovering = $0 }
        .scaleEffect(isHovering ? 1.04 : 1)
        .animation(.easeOut(duration: 0.14), value: isHovering)
        .accessibilityLabel("Back to top")
        .help("Back to top")
    }
}

struct AppTooltip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(AppTheme.tooltipForeground)
            .padding(.horizontal, AppSpacing.small)
            .frame(height: 24)
            .background(AppTheme.tooltipBackground)
            .clipShape(.rect(cornerRadius: 5))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.white.opacity(0.14))
            }
            .fixedSize()
            .allowsHitTesting(false)
    }
}

struct NoteContentLengthHint: View {
    let content: String

    private var isOverLimit: Bool {
        !NoteContentPolicy.isWithinLimit(content)
    }

    var body: some View {
        Text("\(content.count) / \(NoteContentPolicy.maximumCharacterCount)")
            .font(.system(size: 11, weight: isOverLimit ? .medium : .regular))
            .monospacedDigit()
            .foregroundStyle(isOverLimit ? Color.red : Color.secondary)
            .accessibilityLabel(
                "\(content.count) of \(NoteContentPolicy.maximumCharacterCount) characters"
            )
    }
}

struct AppInputSurfaceModifier: ViewModifier {
    let isFocused: Bool

    func body(content: Content) -> some View {
        content
            .background(AppTheme.inputSurface)
            .clipShape(.rect(cornerRadius: AppControlMetrics.inputCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppControlMetrics.inputCornerRadius)
                    .stroke(isFocused ? AppTheme.brandBlue : AppTheme.border)
            }
    }
}

extension View {
    func appInputSurface(isFocused: Bool) -> some View {
        modifier(AppInputSurfaceModifier(isFocused: isFocused))
    }

    func appProminentButton() -> some View {
        buttonStyle(AppActionButtonStyle(appearance: .primary))
    }

    func appSecondaryButton() -> some View {
        buttonStyle(AppActionButtonStyle(appearance: .secondary))
    }
}

private struct AppActionButtonStyle: ButtonStyle {
    enum Appearance {
        case primary
        case secondary
    }

    let appearance: Appearance
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 14)
            .frame(height: AppControlMetrics.formControlHeight)
            .background {
                RoundedRectangle(cornerRadius: AppControlMetrics.inputCornerRadius)
                    .fill(backgroundColor)
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppControlMetrics.inputCornerRadius)
                    .stroke(borderColor)
            }
            .shadow(
                color: shadowColor,
                radius: 1,
                y: 1
            )
            .brightness(configuration.isPressed && isEnabled ? -0.06 : 0)
            .scaleEffect(configuration.isPressed && isEnabled ? 0.985 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }

    private var foregroundColor: Color {
        guard isEnabled else { return AppTheme.disabledActionForeground }
        return appearance == .primary ? .white : AppTheme.secondaryActionForeground
    }

    private var backgroundColor: Color {
        guard isEnabled else { return AppTheme.disabledActionFill }
        return appearance == .primary ? AppTheme.brandBlue : AppTheme.secondaryActionFill
    }

    private var borderColor: Color {
        guard isEnabled else { return .clear }
        return appearance == .primary
            ? AppTheme.brandBlueDeep.opacity(0.48)
            : .clear
    }

    private var shadowColor: Color {
        isEnabled && appearance == .primary
            ? Color.black.opacity(0.10)
            : .clear
    }
}

struct BackNavigationButton: View {
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isHovering ? AppTheme.brandBlueDeep : Color.primary)
                .frame(width: 28, height: 28)
                .background(isHovering ? Color.white : Color.clear)
                .clipShape(.rect(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(AppTheme.border)
                }
        }
        .buttonStyle(.plain)
        .contentShape(.rect)
        .onHover { isHovering = $0 }
        .accessibilityLabel("Back")
        .help("Back")
    }
}

struct SubpageHeader<Trailing: View>: View {
    let title: String
    let backAction: () -> Void
    let trailing: Trailing

    init(
        title: String,
        backAction: @escaping () -> Void,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.backAction = backAction
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: AppSpacing.small) {
            BackNavigationButton(action: backAction)

            Text(title)
                .font(.system(size: 16, weight: .semibold))

            Spacer()
            trailing
        }
        .padding(.horizontal, AppSpacing.medium)
        .padding(.vertical, 10)
        .background(AppTheme.canvas)
    }
}

extension SubpageHeader where Trailing == EmptyView {
    init(title: String, backAction: @escaping () -> Void) {
        self.init(title: title, backAction: backAction) { EmptyView() }
    }
}

struct SheetHeader: View {
    let title: String
    let closeAction: () -> Void
    @State private var isCloseHovering = false

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            Button(action: closeAction) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isCloseHovering ? AppTheme.brandBlueDeep : Color.secondary)
                    .frame(width: 26, height: 26)
                    .background(isCloseHovering ? AppTheme.selectedFill : AppTheme.quietFill)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(
                                isCloseHovering ? AppTheme.brandBlue.opacity(0.32) : AppTheme.border.opacity(0.72)
                            )
                    }
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
            .onHover { isCloseHovering = $0 }
            .animation(.easeOut(duration: 0.14), value: isCloseHovering)
            .accessibilityLabel("Close")
            .help("Close")
        }
    }
}

struct AppSheet<Content: View>: View {
    let title: String
    let minWidth: CGFloat
    let minHeight: CGFloat
    let closeAction: () -> Void
    let content: Content
    private let actions: AppSheetActionConfiguration?

    init(
        title: String,
        primaryActionTitle: String,
        isPrimaryActionEnabled: Bool = true,
        minWidth: CGFloat = 420,
        minHeight: CGFloat,
        closeAction: @escaping () -> Void,
        cancelAction: @escaping () -> Void,
        primaryAction: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.minWidth = minWidth
        self.minHeight = minHeight
        self.closeAction = closeAction
        self.content = content()
        self.actions = AppSheetActionConfiguration(
            primaryActionTitle: primaryActionTitle,
            isPrimaryActionEnabled: isPrimaryActionEnabled,
            cancelAction: cancelAction,
            primaryAction: primaryAction
        )
    }

    init(
        title: String,
        minWidth: CGFloat = 420,
        minHeight: CGFloat,
        closeAction: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.minWidth = minWidth
        self.minHeight = minHeight
        self.closeAction = closeAction
        self.content = content()
        self.actions = nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: title, closeAction: closeAction)
                .padding(.horizontal, AppSpacing.large)
                .padding(.vertical, AppSpacing.medium)

            Divider()

            content
                .padding(.horizontal, AppSpacing.large)
                .padding(.top, AppSpacing.large)

            if let actions {
                Spacer(minLength: AppSpacing.xLarge)

                AppSheetActions(
                    primaryActionTitle: actions.primaryActionTitle,
                    isPrimaryActionEnabled: actions.isPrimaryActionEnabled,
                    cancelAction: actions.cancelAction,
                    primaryAction: actions.primaryAction
                )
                .padding(.horizontal, AppSpacing.large)
                .padding(.bottom, AppSpacing.large)
            } else {
                Spacer(minLength: AppSpacing.large)
            }
        }
        .frame(minWidth: minWidth, minHeight: minHeight, alignment: .topLeading)
        .background(AppTheme.modalSurface)
    }
}

private struct AppSheetActionConfiguration {
    let primaryActionTitle: String
    let isPrimaryActionEnabled: Bool
    let cancelAction: () -> Void
    let primaryAction: () -> Void
}

private struct AppSheetActions: View {
    let primaryActionTitle: String
    let isPrimaryActionEnabled: Bool
    let cancelAction: () -> Void
    let primaryAction: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.small) {
            Spacer()

            Button("Cancel", action: cancelAction)
                .appSecondaryButton()

            Button(primaryActionTitle, action: primaryAction)
                .appProminentButton()
                .disabled(!isPrimaryActionEnabled)
        }
    }
}

struct NoteMetadataBadge: View {
    enum Kind {
        case title
        case tag
    }

    let text: String
    let kind: Kind
    var highlightQuery: String? = nil

    var body: some View {
        HighlightedText(
            text,
            query: highlightQuery,
            baseForeground: kind == .title ? .white : AppTheme.brandBlue,
            matchForeground: kind == .title ? Color(red: 0.20, green: 0.16, blue: 0.03) : nil
        )
            .font(.system(size: kind == .title ? 11 : 10, weight: kind == .title ? .semibold : .medium))
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, kind == .title ? 8 : 7)
            .frame(height: 20)
            .background {
                if kind == .title {
                    AppTheme.titleGradient
                } else {
                    AppTheme.selectedFill
                }
            }
            .clipShape(.rect(cornerRadius: kind == .title ? 5 : 10))
            .frame(maxWidth: kind == .title ? 280 : nil)
    }
}

struct HighlightedText: View {
    let text: String
    let query: String?
    let baseForeground: Color?
    let matchForeground: Color?

    init(
        _ text: String,
        query: String?,
        baseForeground: Color? = nil,
        matchForeground: Color? = nil
    ) {
        self.text = text
        self.query = query
        self.baseForeground = baseForeground
        self.matchForeground = matchForeground
    }

    var body: some View {
        Text(attributedText)
    }

    private var attributedText: AttributedString {
        var result = AttributedString(text)
        if let baseForeground {
            result.foregroundColor = baseForeground
        }

        guard let query, !query.isEmpty else { return result }

        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        var remainingRange = text.startIndex..<text.endIndex
        while let match = text.range(
            of: query,
            options: options,
            range: remainingRange,
            locale: .current
        ) {
            if let attributedRange = Range(match, in: result) {
                result[attributedRange].backgroundColor = Color(red: 1.0, green: 0.86, blue: 0.42)
                if let matchForeground {
                    result[attributedRange].foregroundColor = matchForeground
                }
            }

            guard match.upperBound < text.endIndex else { break }
            remainingRange = match.upperBound..<text.endIndex
        }

        return result
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let fallbackWidth = sizes.reduce(CGFloat.zero) { $0 + $1.width }
            + spacing * CGFloat(max(0, sizes.count - 1))
        return layout(sizes: sizes, availableWidth: proposal.width ?? fallbackWidth).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let result = layout(sizes: sizes, availableWidth: bounds.width)

        for (index, subview) in subviews.enumerated() {
            let position = result.positions[index]
            subview.place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                anchor: .topLeading,
                proposal: ProposedViewSize(sizes[index])
            )
        }
    }

    private func layout(
        sizes: [CGSize],
        availableWidth: CGFloat
    ) -> (size: CGSize, positions: [CGPoint]) {
        guard !sizes.isEmpty else { return (.zero, []) }

        var positions: [CGPoint] = []
        var cursor = CGPoint.zero
        var rowHeight: CGFloat = 0
        var contentWidth: CGFloat = 0

        for size in sizes {
            if cursor.x > 0, cursor.x + size.width > availableWidth {
                cursor.x = 0
                cursor.y += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(cursor)
            contentWidth = max(contentWidth, cursor.x + size.width)
            rowHeight = max(rowHeight, size.height)
            cursor.x += size.width + spacing
        }

        return (
            CGSize(width: min(contentWidth, availableWidth), height: cursor.y + rowHeight),
            positions
        )
    }
}

enum AppFormatters {
    static let noteTimestamp = Date.FormatStyle(date: .numeric, time: .standard)
}
