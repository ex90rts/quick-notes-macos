import AppKit
import HighlightSwift
import SwiftUI

enum AppTheme {
    static let brandBlue = Color(red: 0.29, green: 0.53, blue: 0.91)
    static let brandBlueDeep = Color(red: 0.22, green: 0.47, blue: 0.84)
    static let pinnedGold = Color(red: 0.93, green: 0.65, blue: 0.16)
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let elevatedSurface = Color(nsColor: .textBackgroundColor)
    static let inputSurface = Color(nsColor: .textBackgroundColor)
    static let modalSurface = Color(nsColor: .windowBackgroundColor)
    static let border = Color(nsColor: .separatorColor).opacity(0.72)
    static let quietFill = Color.primary.opacity(0.055)
    static let hoverFill = Color.primary.opacity(0.085)
    static let selectedFill = brandBlue.opacity(0.12)
    static let disabledFill = Color.primary.opacity(0.045)
    static let disabledForeground = Color(nsColor: .disabledControlTextColor)
    static let secondaryActionFill = Color.primary.opacity(0.085)
    static let secondaryActionForeground = Color.primary
    static let disabledActionFill = Color.primary.opacity(0.075)
    static let disabledActionBorder = Color.primary.opacity(0.12)
    static let disabledActionForeground = disabledForeground
    static let searchHighlightFill = Color(red: 1.0, green: 0.86, blue: 0.42)
    static let searchHighlightForeground = Color(red: 0.20, green: 0.16, blue: 0.03)
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
    static let editorMetadataSpacing: CGFloat = 1
}

enum HeaderMenuBehavior {
    static let clipboardRefreshMilliseconds = 500
}

enum HeaderActionLayout {
    static let labelSpacing: CGFloat = 6
    static let horizontalPadding: CGFloat = 10
    static let iconFontSize: CGFloat = 12
    static let labelFontSize: CGFloat = 12
    static let cornerRadius: CGFloat = 7
}

enum PasteShortcutBehavior {
    static func matches(
        charactersIgnoringModifiers: String?,
        modifierFlags: NSEvent.ModifierFlags,
        isRepeat: Bool
    ) -> Bool {
        guard !isRepeat,
              charactersIgnoringModifiers?.lowercased() == "v" else { return false }
        let modifiers = modifierFlags.intersection(.deviceIndependentFlagsMask)
        return modifiers == .command
    }
}

enum NoteCardLayout {
    static let actionIconSize: CGFloat = 14
    static let actionHoverPadding: CGFloat = 4
    static let actionHorizontalMargin: CGFloat = 2
    static let actionHoverCornerRadius: CGFloat = 5
}

enum NoteRenderingMenuLayout {
    static let fontSize: CGFloat = 12
    static let itemWidth: CGFloat = 156
    static let itemHeight: CGFloat = 24
    static let selectionWidth: CGFloat = 156
    static let indicatorFontSize: CGFloat = 8
}

enum NoteDeletionAnimationMetrics {
    static let dissolveDuration = 0.34
    static let particleCount = 112
    static let maximumBlurRadius: CGFloat = 4
    static let horizontalDrift: CGFloat = 18
}

enum NoteAttentionAnimationMetrics {
    static let pulseCount = 2
    static let pulseInDuration = 0.16
    static let pulseOutDuration = 0.14
    static let pulseInHoldMilliseconds = 170
    static let pulseOutHoldMilliseconds = 140
    static let standardLifetimeMilliseconds = 820
    static let reducedMotionLifetimeMilliseconds = 760
}

enum SettingsDividerMetrics {
    static let dashPattern: [CGFloat] = [4, 3]
}

enum NotesFilterBarLayout {
    static let controlHeight: CGFloat = 28
    static let verticalPadding: CGFloat = 10
    static let shadowHeight: CGFloat = 10

    static var singleLineHeight: CGFloat {
        controlHeight + verticalPadding * 2
    }
}

enum NotesFilterBarShadowBehavior {
    static let scrollThreshold: CGFloat = 10

    static func shouldShow(scrollOffset: CGFloat) -> Bool {
        max(0, scrollOffset) > scrollThreshold
    }
}

enum NoteContentLayout {
    static let collapsedViewportHeight: CGFloat = 100
    static let containerPadding: CGFloat = 10

    static var collapsedContainerHeight: CGFloat {
        collapsedViewportHeight + containerPadding * 2
    }
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
    @Environment(\.appLanguage) private var appLanguage
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
                AppLocalization.format(
                    "%lld of %lld characters",
                    language: appLanguage,
                    arguments: Int64(content.count),
                    Int64(NoteContentPolicy.maximumCharacterCount)
                )
            )
    }
}

struct PasteShortcutMonitor: NSViewRepresentable {
    let isEnabled: Bool
    let onPaste: @MainActor () -> Bool

    func makeNSView(context: Context) -> PasteShortcutMonitorView {
        let view = PasteShortcutMonitorView()
        view.isEnabled = isEnabled
        view.onPaste = onPaste
        view.startMonitoring()
        return view
    }

    func updateNSView(_ view: PasteShortcutMonitorView, context: Context) {
        view.isEnabled = isEnabled
        view.onPaste = onPaste
    }

    static func dismantleNSView(
        _ view: PasteShortcutMonitorView,
        coordinator: Void
    ) {
        view.stopMonitoring()
    }
}

final class PasteShortcutMonitorView: NSView {
    var isEnabled = false
    var onPaste: @MainActor () -> Bool = { false }
    private var eventMonitor: Any?

    func startMonitoring() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            [weak self] event in
            let characters = event.charactersIgnoringModifiers
            let modifiers = event.modifierFlags
            let isRepeat = event.isARepeat
            let wasHandled = MainActor.assumeIsolated {
                self?.handle(
                    charactersIgnoringModifiers: characters,
                    modifierFlags: modifiers,
                    isRepeat: isRepeat
                ) ?? false
            }
            return wasHandled ? nil : event
        }
    }

    func stopMonitoring() {
        guard let eventMonitor else { return }
        NSEvent.removeMonitor(eventMonitor)
        self.eventMonitor = nil
    }

    private func handle(
        charactersIgnoringModifiers: String?,
        modifierFlags: NSEvent.ModifierFlags,
        isRepeat: Bool
    ) -> Bool {
        guard isEnabled,
              let window,
              window.isVisible,
              NSApp.keyWindow === window,
              window.attachedSheet == nil,
              NSApp.modalWindow == nil,
              PasteShortcutBehavior.matches(
                  charactersIgnoringModifiers: charactersIgnoringModifiers,
                  modifierFlags: modifierFlags,
                  isRepeat: isRepeat
              ) else { return false }

        return onPaste()
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

    func appProminentButton(horizontalPadding: CGFloat = 14) -> some View {
        buttonStyle(
            AppActionButtonStyle(
                appearance: .primary,
                horizontalPadding: horizontalPadding
            )
        )
    }

    func appSecondaryButton() -> some View {
        buttonStyle(
            AppActionButtonStyle(
                appearance: .secondary,
                horizontalPadding: 14
            )
        )
    }

}

private struct AppActionButtonStyle: ButtonStyle {
    enum Appearance {
        case primary
        case secondary
    }

    let appearance: Appearance
    let horizontalPadding: CGFloat
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, horizontalPadding)
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
        switch appearance {
        case .primary:
            return .white
        case .secondary:
            return AppTheme.secondaryActionForeground
        }
    }

    private var backgroundColor: Color {
        guard isEnabled else { return AppTheme.disabledActionFill }
        switch appearance {
        case .primary:
            return AppTheme.brandBlue
        case .secondary:
            return AppTheme.secondaryActionFill
        }
    }

    private var borderColor: Color {
        guard isEnabled else { return AppTheme.disabledActionBorder }
        switch appearance {
        case .primary:
            return AppTheme.brandBlueDeep.opacity(0.48)
        case .secondary:
            return .clear
        }
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
                .foregroundStyle(Color.primary)
                .frame(width: 28, height: 28)
                .background(isHovering ? AppTheme.selectedFill : Color.clear)
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

            Text(LocalizedStringKey(title))
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
    let language: SupportedAppLanguage
    let closeAction: () -> Void
    @State private var isCloseHovering = false

    var body: some View {
        HStack {
            Text(verbatim: AppLocalization.string(title, language: language))
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
            .accessibilityLabel(AppLocalization.string("Close", language: language))
            .help(AppLocalization.string("Close", language: language))
        }
    }
}

struct AppSheet<Content: View>: View {
    let title: String
    let language: SupportedAppLanguage
    let minWidth: CGFloat
    let minHeight: CGFloat
    let closeAction: () -> Void
    let content: Content
    private let actions: AppSheetActionConfiguration?

    init(
        title: String,
        language: SupportedAppLanguage,
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
        self.language = language
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
        language: SupportedAppLanguage,
        minWidth: CGFloat = 420,
        minHeight: CGFloat,
        closeAction: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.language = language
        self.minWidth = minWidth
        self.minHeight = minHeight
        self.closeAction = closeAction
        self.content = content()
        self.actions = nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: title, language: language, closeAction: closeAction)
                .padding(.horizontal, AppSpacing.large)
                .padding(.vertical, AppSpacing.medium)

            Divider()

            content
                .padding(.horizontal, AppSpacing.large)
                .padding(.top, AppSpacing.large)

            if let actions {
                Spacer(minLength: AppSpacing.xLarge)

                AppSheetActions(
                    language: language,
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
        .environment(\.locale, language.locale)
        .environment(\.appLanguage, language)
    }
}

private struct AppSheetActionConfiguration {
    let primaryActionTitle: String
    let isPrimaryActionEnabled: Bool
    let cancelAction: () -> Void
    let primaryAction: () -> Void
}

private struct AppSheetActions: View {
    let language: SupportedAppLanguage
    let primaryActionTitle: String
    let isPrimaryActionEnabled: Bool
    let cancelAction: () -> Void
    let primaryAction: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.small) {
            Spacer()

            Button(AppLocalization.string("Cancel", language: language), action: cancelAction)
                .appSecondaryButton()

            Button(AppLocalization.string(primaryActionTitle, language: language), action: primaryAction)
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
            matchForeground: AppTheme.searchHighlightForeground
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
                result[attributedRange].backgroundColor = AppTheme.searchHighlightFill
                result[attributedRange].foregroundColor = matchForeground
                    ?? AppTheme.searchHighlightForeground
            }

            guard match.upperBound < text.endIndex else { break }
            remainingRange = match.upperBound..<text.endIndex
        }

        return result
    }
}

struct NoteRenderedContent: View {
    let content: String
    let renderingMode: NoteRenderingMode
    let highlightQuery: String?
    let onToggleTodo: (Int) -> Void

    @ViewBuilder
    var body: some View {
        switch renderingMode {
        case .automatic:
            if let language = NoteCodeHeuristics.detectedLanguage(in: content) {
                CodeContentView(
                    code: content,
                    language: language,
                    highlightQuery: highlightQuery,
                    showsLanguage: true
                )
            } else {
                MarkdownContentView(
                    blocks: NoteContentParser.blocks(from: content),
                    highlightQuery: highlightQuery,
                    onToggleTodo: onToggleTodo
                )
            }
        case .plainText:
            HighlightedText(content, query: highlightQuery)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .markdown:
            MarkdownContentView(
                blocks: NoteContentParser.blocks(from: content),
                highlightQuery: highlightQuery,
                onToggleTodo: onToggleTodo
            )
        case .code(let language):
            CodeContentView(
                code: content,
                language: language,
                highlightQuery: highlightQuery,
                showsLanguage: true
            )
        }
    }
}

private struct CodeContentView: View {
    let code: String
    let language: NoteCodeLanguage
    let highlightQuery: String?
    let showsLanguage: Bool

    private var resolvedLanguage: NoteCodeLanguage? {
        guard language == .automatic else { return language }
        return NoteCodeHeuristics.detectedLanguage(in: code)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsLanguage {
                Text(LocalizedStringKey((resolvedLanguage ?? .automatic).title))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.secondary)
                    .textCase(.uppercase)
                    .padding(.horizontal, 9)
                    .padding(.top, 6)
                    .padding(.bottom, 3)
            }

            ScrollView(.horizontal) {
                SyntaxHighlightedCodeText(
                    code: code,
                    language: resolvedLanguage,
                    highlightQuery: highlightQuery
                )
                .padding(9)
            }
            .scrollIndicators(.hidden)
        }
        .background(AppTheme.quietFill)
        .clipShape(.rect(cornerRadius: 5))
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(AppTheme.border)
        }
    }
}

private struct SyntaxHighlightedCodeText: View {
    let code: String
    let language: NoteCodeLanguage?
    let highlightQuery: String?

    @ViewBuilder
    var body: some View {
        if highlightQuery?.isEmpty == false {
            HighlightedText(code, query: highlightQuery)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: true, vertical: true)
        } else if let highlightLanguage = language?.highlightLanguage {
            CodeText(code)
                .highlightLanguage(highlightLanguage)
                .codeTextColors(.theme(.github))
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: true, vertical: true)
        } else {
            CodeText(code)
                .highlightMode(.automatic)
                .codeTextColors(.theme(.github))
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: true, vertical: true)
        }
    }
}

private extension NoteCodeLanguage {
    var highlightLanguage: HighlightLanguage? {
        switch self {
        case .automatic: nil
        case .json: .json
        case .shell: .shell
        case .javascript: .javaScript
        case .typescript: .typeScript
        case .swift: .swift
        case .python: .python
        case .html: .html
        case .css: .css
        case .sql: .sql
        case .yaml: .yaml
        case .java: .java
        case .kotlin: .kotlin
        case .go: .go
        case .rust: .rust
        case .c: .c
        case .cpp: .cPlusPlus
        case .csharp: .cSharp
        }
    }
}

private struct MarkdownContentView: View {
    let blocks: [NoteContentBlock]
    let highlightQuery: String?
    let onToggleTodo: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .paragraph(let source):
                    Text(NoteContentStyler.markdown(source, highlightQuery: highlightQuery))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .heading(let level, let text):
                    heading(text, level: level)
                case .list(let list):
                    MarkdownListView(
                        list: list,
                        highlightQuery: highlightQuery
                    )
                case .blockQuote(let source):
                    blockQuote(source)
                case .codeBlock(let codeBlock):
                    MarkdownCodeBlockView(
                        codeBlock: codeBlock,
                        highlightQuery: highlightQuery
                    )
                case .thematicBreak:
                    Divider()
                        .padding(.vertical, 3)
                case .todo(let item):
                    todoRow(item)
                case .table(let table):
                    MarkdownTableView(
                        table: table,
                        highlightQuery: highlightQuery
                    )
                }
            }
        }
    }

    private func heading(_ source: String, level: Int) -> some View {
        let font = Font.system(
            size: headingFontSize(level),
            weight: level <= 2 ? .bold : .semibold
        )
        return Text(NoteContentStyler.markdown(
            source,
            highlightQuery: highlightQuery,
            baseFont: font
        ))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
            .padding(.top, level <= 2 ? 2 : 0)
    }

    private func blockQuote(_ source: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            RoundedRectangle(cornerRadius: 1)
                .fill(AppTheme.brandBlue.opacity(0.65))
                .frame(width: 3)

            Text(NoteContentStyler.markdown(
                source,
                highlightQuery: highlightQuery,
                baseFont: .system(size: 13).italic()
            ))
                .foregroundStyle(Color.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }

    private func headingFontSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: 22
        case 2: 19
        case 3: 17
        case 4: 15
        case 5: 14
        default: 13
        }
    }

    private func todoRow(_ item: NoteTodoItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Button {
                onToggleTodo(item.lineIndex)
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(item.isCompleted ? AppTheme.brandBlue : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                Text(LocalizedStringKey(item.isCompleted ? "Mark incomplete" : "Mark complete"))
            )

            Text(NoteContentStyler.markdown(item.text, highlightQuery: highlightQuery))
                .strikethrough(item.isCompleted, color: .secondary)
                .foregroundStyle(item.isCompleted ? Color.secondary : Color.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct MarkdownListView: View {
    let list: NoteMarkdownList
    let highlightQuery: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(list.items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(marker(for: index))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.brandBlue)
                        .frame(minWidth: 14, alignment: .trailing)

                    Text(NoteContentStyler.markdown(
                        item.text,
                        highlightQuery: highlightQuery
                    ))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.leading, CGFloat(item.indentationLevel) * 18)
            }
        }
    }

    private func marker(for index: Int) -> String {
        list.isOrdered ? "\(list.startingNumber + index)." : "•"
    }
}

private struct MarkdownCodeBlockView: View {
    let codeBlock: NoteMarkdownCodeBlock
    let highlightQuery: String?

    var body: some View {
        CodeContentView(
            code: codeBlock.code,
            language: codeBlock.language.flatMap(NoteCodeLanguage.init(markdownIdentifier:))
                ?? .automatic,
            highlightQuery: highlightQuery,
            showsLanguage: codeBlock.language != nil
        )
    }
}

private struct MarkdownTableView: View {
    let table: NoteMarkdownTable
    let highlightQuery: String?

    var body: some View {
        ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ForEach(table.headers.indices, id: \.self) { columnIndex in
                        cell(
                            table.headers[columnIndex],
                            columnIndex: columnIndex,
                            isHeader: true,
                            isAlternateRow: false
                        )
                    }
                }

                ForEach(table.rows.indices, id: \.self) { rowIndex in
                    GridRow {
                        ForEach(table.headers.indices, id: \.self) { columnIndex in
                            cell(
                                table.rows[rowIndex][columnIndex],
                                columnIndex: columnIndex,
                                isHeader: false,
                                isAlternateRow: rowIndex.isMultiple(of: 2)
                            )
                        }
                    }
                }
            }
            .clipShape(.rect(cornerRadius: 5))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(AppTheme.border)
            }
        }
        .scrollIndicators(.hidden)
    }

    private func cell(
        _ source: String,
        columnIndex: Int,
        isHeader: Bool,
        isAlternateRow: Bool
    ) -> some View {
        Text(NoteContentStyler.markdown(
            source,
            highlightQuery: highlightQuery,
            baseFont: .system(size: 12, weight: isHeader ? .semibold : .regular)
        ))
            .textSelection(.enabled)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .frame(
                minWidth: 96,
                maxWidth: 220,
                alignment: alignment(for: table.alignments[columnIndex])
            )
            .background(
                isHeader
                    ? AppTheme.selectedFill
                    : (isAlternateRow ? Color.primary.opacity(0.025) : Color.clear)
            )
            .overlay(alignment: .trailing) {
                if columnIndex < table.headers.count - 1 {
                    Rectangle()
                        .fill(AppTheme.border)
                        .frame(width: 1)
                }
            }
    }

    private func alignment(for alignment: MarkdownTableColumnAlignment) -> Alignment {
        switch alignment {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }
}

private struct JSONContentView: View {
    let formattedJSON: String
    let highlightQuery: String?

    var body: some View {
        ScrollView(.horizontal) {
            Text(NoteContentStyler.json(formattedJSON, highlightQuery: highlightQuery))
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: true, vertical: true)
                .padding(10)
        }
        .scrollIndicators(.hidden)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.7))
        .clipShape(.rect(cornerRadius: 5))
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(AppTheme.border)
        }
        .accessibilityLabel("Formatted JSON")
    }
}

private enum NoteContentStyler {
    static func markdown(
        _ source: String,
        highlightQuery: String?,
        baseFont: Font = .system(size: 13)
    ) -> AttributedString {
        var result = (try? AttributedString(
            markdown: source,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
        )) ?? AttributedString(source)
        materializeInlineStyles(in: &result, baseFont: baseFont)
        applyDetectedLinks(to: &result)
        applySearchHighlight(to: &result, query: highlightQuery)
        return result
    }

    private static func materializeInlineStyles(
        in result: inout AttributedString,
        baseFont: Font
    ) {
        result.font = baseFont
        let runs = result.runs.map {
            ($0.range, $0.inlinePresentationIntent, $0.link)
        }

        for (range, intent, link) in runs {
            if let intent {
                let isBold = intent.contains(.stronglyEmphasized)
                let isItalic = intent.contains(.emphasized)
                let isCode = intent.contains(.code)
                let isStrikethrough = intent.contains(.strikethrough)

                if isCode {
                    result[range].font = .system(size: 12, design: .monospaced)
                    result[range].backgroundColor = Color.primary.opacity(0.07)
                } else if isBold && isItalic {
                    result[range].font = baseFont.bold().italic()
                } else if isBold {
                    result[range].font = baseFont.bold()
                } else if isItalic {
                    result[range].font = baseFont.italic()
                }

                if isStrikethrough {
                    result[range].strikethroughStyle = .single
                }
            }

            if link != nil {
                result[range].foregroundColor = AppTheme.brandBlue
                result[range].underlineStyle = .single
            }
        }
    }

    static func json(_ source: String, highlightQuery: String?) -> AttributedString {
        var result = AttributedString(source)
        var index = source.startIndex

        while index < source.endIndex {
            let character = source[index]
            if character == "\"" {
                let range = jsonStringRange(in: source, startingAt: index)
                let isKey = nextNonWhitespaceCharacter(in: source, after: range.upperBound) == ":"
                setForeground(
                    isKey ? AppTheme.brandBlueDeep : Color(nsColor: .systemGreen),
                    in: range,
                    attributedString: &result
                )
                index = range.upperBound
            } else if character.isNumber || character == "-" {
                let range = source[index...].prefix {
                    $0.isNumber || "+-.eE".contains($0)
                }
                let upperBound = source.index(index, offsetBy: range.count)
                setForeground(
                    Color(nsColor: .systemOrange),
                    in: index..<upperBound,
                    attributedString: &result
                )
                index = upperBound
            } else if let literalRange = jsonLiteralRange(in: source, startingAt: index) {
                let literal = source[literalRange]
                let color = literal == "null"
                    ? Color.secondary
                    : Color(nsColor: .systemPurple)
                setForeground(color, in: literalRange, attributedString: &result)
                index = literalRange.upperBound
            } else {
                index = source.index(after: index)
            }
        }

        applyDetectedLinks(to: &result)
        applySearchHighlight(to: &result, query: highlightQuery)
        return result
    }

    private static func applyDetectedLinks(to result: inout AttributedString) {
        let visibleText = String(result.characters)
        for match in NoteContentLink.matches(in: visibleText) {
            guard let range = Range(match.range, in: result) else { continue }
            result[range].link = match.url
            result[range].foregroundColor = AppTheme.brandBlue
            result[range].underlineStyle = .single
        }
    }

    private static func applySearchHighlight(
        to result: inout AttributedString,
        query: String?
    ) {
        guard let query, !query.isEmpty else { return }
        let visibleText = String(result.characters)
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        var remainingRange = visibleText.startIndex..<visibleText.endIndex

        while let match = visibleText.range(
            of: query,
            options: options,
            range: remainingRange,
            locale: .current
        ) {
            if let attributedRange = Range(match, in: result) {
                result[attributedRange].backgroundColor = AppTheme.searchHighlightFill
                result[attributedRange].foregroundColor = AppTheme.searchHighlightForeground
            }
            guard match.upperBound < visibleText.endIndex else { break }
            remainingRange = match.upperBound..<visibleText.endIndex
        }
    }

    private static func jsonStringRange(
        in source: String,
        startingAt startIndex: String.Index
    ) -> Range<String.Index> {
        var index = source.index(after: startIndex)
        var isEscaped = false
        while index < source.endIndex {
            let character = source[index]
            let nextIndex = source.index(after: index)
            if character == "\"" && !isEscaped {
                return startIndex..<nextIndex
            }
            if character == "\\" && !isEscaped {
                isEscaped = true
            } else {
                isEscaped = false
            }
            index = nextIndex
        }
        return startIndex..<source.endIndex
    }

    private static func nextNonWhitespaceCharacter(
        in source: String,
        after startIndex: String.Index
    ) -> Character? {
        source[startIndex...].first(where: { !$0.isWhitespace })
    }

    private static func jsonLiteralRange(
        in source: String,
        startingAt startIndex: String.Index
    ) -> Range<String.Index>? {
        for literal in ["true", "false", "null"] where source[startIndex...].hasPrefix(literal) {
            return startIndex..<source.index(startIndex, offsetBy: literal.count)
        }
        return nil
    }

    private static func setForeground(
        _ color: Color,
        in sourceRange: Range<String.Index>,
        attributedString: inout AttributedString
    ) {
        guard let range = Range(sourceRange, in: attributedString) else { return }
        attributedString[range].foregroundColor = color
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
