import AppKit
import SwiftUI

private struct InitiallyFocusedTextEditor: NSViewRepresentable {
    @Binding var text: String
    let onFocusChange: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> InitialFocusScrollView {
        let scrollView = InitialFocusScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let textView = NSTextView(frame: .zero)
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = .labelColor
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: .greatestFiniteMagnitude
        )

        scrollView.documentView = textView
        scrollView.preferredInitialFirstResponder = textView
        return scrollView
    }

    func updateNSView(_ scrollView: InitialFocusScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? NSTextView,
              textView.string != text else { return }

        textView.string = text
        textView.setSelectedRange(NSRange(location: text.utf16.count, length: 0))
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: InitiallyFocusedTextEditor

        init(parent: InitiallyFocusedTextEditor) {
            self.parent = parent
        }

        func textDidBeginEditing(_ notification: Notification) {
            parent.onFocusChange(true)
        }

        func textDidEndEditing(_ notification: Notification) {
            parent.onFocusChange(false)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

private final class InitialFocusScrollView: NSScrollView {
    weak var preferredInitialFirstResponder: NSView?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window, let preferredInitialFirstResponder else { return }
        window.initialFirstResponder = preferredInitialFirstResponder
    }
}

struct TagFlowLayout: View {
    let tags: [String]
    let selectedTags: Set<String>
    let onTagToggle: (String) -> Void
    @State private var hoveredTag: String?

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                let isSelected = selectedTags.contains(tag)
                Button {
                    onTagToggle(tag)
                } label: {
                    Text(tag)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 9)
                        .frame(height: 28)
                        .background(
                            isSelected
                                ? AppTheme.brandBlue
                                : (hoveredTag == tag
                                    ? AppTheme.brandBlue.opacity(0.07)
                                    : AppTheme.elevatedSurface)
                        )
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .clipShape(.capsule)
                        .overlay {
                            Capsule()
                                .stroke(isSelected ? AppTheme.brandBlue : AppTheme.border)
                        }
                }
                .buttonStyle(.plain)
                .onHover { hoveredTag = $0 ? tag : nil }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AddNoteView: View {
    private enum Field: Hashable {
        case title
        case content
    }

    @EnvironmentObject var vm: NotesViewModel
    @Environment(\.dismiss) private var dismiss
    let language: SupportedAppLanguage
    @FocusState private var focusedField: Field?
    @State private var title = ""
    @State private var content = ""
    @State private var selectedTags: Set<String> = []
    @State private var renderingMode: NoteRenderingMode = .automatic

    var body: some View {
        AppSheet(
            title: "New Note",
            language: language,
            primaryActionTitle: "Save",
            isPrimaryActionEnabled: NoteContentPolicy.canSave(content),
            minHeight: 440,
            closeAction: { dismiss() },
            cancelAction: cancel,
            primaryAction: save
        ) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Title (Optional)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("Give it a short title, or leave it blank", text: $title)
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
                        InitiallyFocusedTextEditor(
                            text: $content,
                            onFocusChange: { isFocused in
                                if isFocused {
                                    focusedField = .content
                                } else if focusedField == .content {
                                    focusedField = nil
                                }
                            }
                        )
                        .frame(minHeight: 120)
                        .padding(.vertical, AppControlMetrics.editorVerticalPadding)
                        .appInputSurface(isFocused: focusedField == .content)

                        HStack {
                            NoteRenderingModePicker(renderingMode: $renderingMode)

                            Spacer()

                            NoteContentLengthHint(content: content)
                        }
                    }
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

    private func save() {
        guard vm.addNote(
            title: title,
            content: content,
            tags: selectedTags,
            renderingMode: renderingMode
        ) else { return }
        dismiss()
    }

    private func cancel() {
        dismiss()
    }
}

struct NoteRenderingModePicker: View {
    @Environment(\.appLanguage) private var appLanguage
    @Binding var renderingMode: NoteRenderingMode

    var body: some View {
        HStack(spacing: 6) {
            Text("Render As")
                .font(.system(size: NoteRenderingMenuLayout.fontSize))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)

            HStack(spacing: 3) {
                Menu {
                    renderingModeButton(.automatic)
                    renderingModeButton(.plainText)
                    renderingModeButton(.markdown)

                    Menu {
                        ForEach(NoteCodeLanguage.selectableCases) { codeLanguage in
                            Button {
                                renderingMode = .code(codeLanguage)
                            } label: {
                                renderingModeMenuLabel(
                                    localized(codeLanguage.title),
                                    isSelected: renderingMode == .code(codeLanguage)
                                )
                            }
                        }
                    } label: {
                        renderingModeMenuLabel(
                            localized("Code"),
                            isSelected: false
                        )
                    }
                } label: {
                    Text(verbatim: selectedModeTitle)
                        .font(.system(size: NoteRenderingMenuLayout.fontSize))
                        .lineLimit(1)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .accessibilityLabel(Text("Render As"))
                .accessibilityValue(Text(verbatim: selectedModeTitle))

                Image(systemName: "chevron.down")
                    .font(.system(
                        size: NoteRenderingMenuLayout.indicatorFontSize,
                        weight: .semibold
                    ))
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                Spacer(minLength: 4)
            }
            .frame(
                width: NoteRenderingMenuLayout.selectionWidth,
                height: AppControlMetrics.formControlHeight
            )
            .contentShape(.rect)
        }
        .frame(height: AppControlMetrics.formControlHeight)
    }

    private func renderingModeButton(_ mode: NoteRenderingMode) -> some View {
        Button {
            renderingMode = mode
        } label: {
            renderingModeMenuLabel(
                localized(mode.kind.title),
                isSelected: renderingMode == mode
            )
        }
    }

    private func renderingModeMenuLabel(
        _ title: String,
        isSelected: Bool
    ) -> some View {
        HStack {
            Text(verbatim: title)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .font(.system(size: NoteRenderingMenuLayout.fontSize))
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .padding(.horizontal, 8)
        .frame(
            width: NoteRenderingMenuLayout.itemWidth,
            height: NoteRenderingMenuLayout.itemHeight
        )
        .background(isSelected ? AppTheme.brandBlue : Color.clear)
        .clipShape(.rect(cornerRadius: 5))
    }

    private var selectedModeTitle: String {
        switch renderingMode {
        case .automatic:
            AppLocalization.string("Automatic Rendering", language: appLanguage)
        case .plainText:
            AppLocalization.string("Plain Text", language: appLanguage)
        case .markdown:
            AppLocalization.string("Markdown", language: appLanguage)
        case .code(let language):
            AppLocalization.string("Code", language: appLanguage)
                + " · "
                + AppLocalization.string(language.title, language: appLanguage)
        }
    }

    private func localized(_ key: String) -> String {
        AppLocalization.string(key, language: appLanguage)
    }
}
