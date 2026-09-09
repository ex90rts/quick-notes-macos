import Foundation

struct Note: Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String? = nil
    var content: String
    var tags: [String]
    var timestamp: Date
    var isPinned: Bool = false
    var expanded: Bool
}

enum NoteOrdering {
    static func pinnedFirst(_ notes: [Note]) -> [Note] {
        notes.filter(\.isPinned) + notes.filter { !$0.isPinned }
    }

    static func inserting(_ note: Note, into notes: [Note]) -> [Note] {
        var orderedNotes = notes
        let insertionIndex = orderedNotes.firstIndex { existingNote in
            if note.isPinned != existingNote.isPinned {
                return note.isPinned
            }
            return note.timestamp > existingNote.timestamp
        } ?? orderedNotes.endIndex
        orderedNotes.insert(note, at: insertionIndex)
        return orderedNotes
    }

    static func replacingAndReordering(_ note: Note, in notes: [Note]) -> [Note] {
        inserting(note, into: notes.filter { $0.id != note.id })
    }
}

struct ClipboardItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let content: String
    let timestamp: Date

    init(id: UUID = UUID(), content: String, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
    }
}

enum NoteContentPolicy {
    static let maximumCharacterCount = 2_000

    static func isWithinLimit(_ content: String) -> Bool {
        content.count <= maximumCharacterCount
    }

    static func canSave(_ content: String) -> Bool {
        !ContentSanitizer.sanitize(content).isEmpty && isWithinLimit(content)
    }
}

enum ContentSanitizer {
    static func sanitize(_ content: String) -> String {
        let normalizedLineEndings = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let trimmedLines = normalizedLineEndings
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                line.replacingOccurrences(
                    of: "[ \\t]+$",
                    with: "",
                    options: .regularExpression
                )
            }
            .joined(separator: "\n")

        return trimmedLines
            .replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
    }
}

enum TitleSanitizer {
    static func sanitize(_ title: String) -> String? {
        let sanitized = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? nil : sanitized
    }
}

enum NoteContentLink {
    static func matches(in content: String) -> [NoteContentLinkMatch] {
        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.link.rawValue
        ) else { return [] }

        let fullRange = NSRange(content.startIndex..<content.endIndex, in: content)
        return detector.matches(in: content, options: [], range: fullRange).compactMap { result in
            guard let url = result.url,
                  let range = Range(result.range, in: content),
                  hasExplicitWebScheme(String(content[range])),
                  isSupportedWebURL(url) else {
                return nil
            }
            return NoteContentLinkMatch(url: url, range: range)
        }
    }

    static func url(from content: String) -> URL? {
        matches(in: content).first?.url
    }

    static func containsURL(_ content: String) -> Bool {
        url(from: content) != nil
    }

    private static func hasExplicitWebScheme(_ source: String) -> Bool {
        let lowercasedSource = source.lowercased()
        return lowercasedSource.hasPrefix("http://")
            || lowercasedSource.hasPrefix("https://")
    }

    private static func isSupportedWebURL(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              components.host?.isEmpty == false else {
            return false
        }
        return true
    }
}

struct NoteContentLinkMatch {
    let url: URL
    let range: Range<String.Index>
}

struct NoteTodoItem: Equatable {
    let lineIndex: Int
    let text: String
    let isCompleted: Bool
}

enum NoteTodo {
    static func item(from line: String, lineIndex: Int) -> NoteTodoItem? {
        guard let markerStart = line.firstIndex(where: { !$0.isWhitespace }) else {
            return nil
        }
        let remainder = line[markerStart...]
        let markerLength: Int
        let isCompleted: Bool

        if remainder.hasPrefix("[-]") {
            markerLength = 3
            isCompleted = true
        } else if remainder.hasPrefix("[]") {
            markerLength = 2
            isCompleted = false
        } else {
            return nil
        }

        let markerEnd = remainder.index(remainder.startIndex, offsetBy: markerLength)
        let suffix = remainder[markerEnd...]
        guard suffix.isEmpty || suffix.first?.isWhitespace == true else { return nil }

        return NoteTodoItem(
            lineIndex: lineIndex,
            text: String(suffix.drop(while: \.isWhitespace)),
            isCompleted: isCompleted
        )
    }

    static func togglingItem(in content: String, at lineIndex: Int) -> String? {
        var lines = content.components(separatedBy: "\n")
        guard lines.indices.contains(lineIndex),
              let item = item(from: lines[lineIndex], lineIndex: lineIndex),
              let markerStart = lines[lineIndex].firstIndex(where: { !$0.isWhitespace }) else {
            return nil
        }

        let markerLength = item.isCompleted ? 3 : 2
        let markerEnd = lines[lineIndex].index(markerStart, offsetBy: markerLength)
        let replacement = item.isCompleted ? "[]" : "[-]"
        lines[lineIndex] = String(lines[lineIndex][..<markerStart])
            + replacement
            + String(lines[lineIndex][markerEnd...])
        return lines.joined(separator: "\n")
    }
}

enum MarkdownTableColumnAlignment: Equatable {
    case leading
    case center
    case trailing
}

struct NoteMarkdownTable: Equatable {
    let headers: [String]
    let alignments: [MarkdownTableColumnAlignment]
    let rows: [[String]]
}

struct NoteMarkdownListItem: Equatable {
    let text: String
    let indentationLevel: Int
}

struct NoteMarkdownList: Equatable {
    let isOrdered: Bool
    let startingNumber: Int
    let items: [NoteMarkdownListItem]
}

struct NoteMarkdownCodeBlock: Equatable {
    let language: String?
    let code: String
}

enum NoteContentBlock: Equatable {
    case paragraph(String)
    case heading(level: Int, text: String)
    case list(NoteMarkdownList)
    case blockQuote(String)
    case codeBlock(NoteMarkdownCodeBlock)
    case thematicBreak
    case todo(NoteTodoItem)
    case table(NoteMarkdownTable)
}

enum NoteContentParser {
    static func blocks(from content: String) -> [NoteContentBlock] {
        let lines = content.components(separatedBy: "\n")
        var blocks: [NoteContentBlock] = []
        var paragraphLines: [String] = []
        var lineIndex = 0

        func flushParagraph() {
            guard !paragraphLines.isEmpty else { return }
            let paragraph = paragraphLines.joined(separator: "\n")
            if !paragraph.isEmpty {
                blocks.append(.paragraph(paragraph))
            }
            paragraphLines.removeAll(keepingCapacity: true)
        }

        while lineIndex < lines.count {
            if lines[lineIndex].trimmingCharacters(in: .whitespaces).isEmpty {
                flushParagraph()
                lineIndex += 1
                continue
            }

            if let codeFence = codeFence(from: lines[lineIndex]) {
                flushParagraph()
                let codeBlock = fencedCodeBlock(
                    startingAt: lineIndex,
                    fence: codeFence,
                    in: lines
                )
                blocks.append(.codeBlock(codeBlock.value))
                lineIndex = codeBlock.nextLineIndex
                continue
            }

            if let todo = NoteTodo.item(from: lines[lineIndex], lineIndex: lineIndex) {
                flushParagraph()
                blocks.append(.todo(todo))
                lineIndex += 1
                continue
            }

            if let table = table(startingAt: lineIndex, in: lines) {
                flushParagraph()
                blocks.append(.table(table.value))
                lineIndex = table.nextLineIndex
                continue
            }

            if lines.indices.contains(lineIndex + 1),
               let level = setextHeadingLevel(from: lines[lineIndex + 1]) {
                flushParagraph()
                blocks.append(.heading(
                    level: level,
                    text: lines[lineIndex].trimmingCharacters(in: .whitespaces)
                ))
                lineIndex += 2
                continue
            }

            if isThematicBreak(lines[lineIndex]) {
                flushParagraph()
                blocks.append(.thematicBreak)
                lineIndex += 1
                continue
            }

            if let heading = heading(from: lines[lineIndex]) {
                flushParagraph()
                blocks.append(.heading(level: heading.level, text: heading.text))
                lineIndex += 1
                continue
            }

            if blockQuoteText(from: lines[lineIndex]) != nil {
                flushParagraph()
                let quote = blockQuote(startingAt: lineIndex, in: lines)
                blocks.append(.blockQuote(quote.text))
                lineIndex = quote.nextLineIndex
                continue
            }

            if let firstListItem = listItem(from: lines[lineIndex]) {
                flushParagraph()
                let list = markdownList(
                    startingAt: lineIndex,
                    firstItem: firstListItem,
                    in: lines
                )
                blocks.append(.list(list.value))
                lineIndex = list.nextLineIndex
                continue
            }

            paragraphLines.append(lines[lineIndex])
            lineIndex += 1
        }

        flushParagraph()
        return blocks
    }

    private struct CodeFence {
        let character: Character
        let length: Int
        let language: String?
    }

    private struct ParsedListItem {
        let isOrdered: Bool
        let number: Int
        let text: String
        let indentationLevel: Int
    }

    private static func heading(from line: String) -> (level: Int, text: String)? {
        let candidate = line.trimmingCharacters(in: .whitespaces)
        let level = candidate.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(level) else { return nil }

        let markerEnd = candidate.index(candidate.startIndex, offsetBy: level)
        let suffix = candidate[markerEnd...]
        guard suffix.isEmpty || suffix.first?.isWhitespace == true else { return nil }

        var text = String(suffix.drop(while: \.isWhitespace))
        if let closingHashes = text.range(
            of: #"\s+#+\s*$"#,
            options: .regularExpression
        ) {
            text.removeSubrange(closingHashes)
        }
        return (level, text)
    }

    private static func isThematicBreak(_ line: String) -> Bool {
        let marker = line.filter { !$0.isWhitespace }
        guard marker.count >= 3, let first = marker.first,
              first == "-" || first == "*" || first == "_" else {
            return false
        }
        return marker.allSatisfy { $0 == first }
    }

    private static func setextHeadingLevel(from line: String) -> Int? {
        let marker = line.filter { !$0.isWhitespace }
        guard marker.count >= 3, let first = marker.first,
              (first == "=" || first == "-"),
              marker.allSatisfy({ $0 == first }) else {
            return nil
        }
        return first == "=" ? 1 : 2
    }

    private static func codeFence(from line: String) -> CodeFence? {
        let candidate = line.trimmingCharacters(in: .whitespaces)
        guard let character = candidate.first,
              character == "`" || character == "~" else {
            return nil
        }
        let length = candidate.prefix(while: { $0 == character }).count
        guard length >= 3 else { return nil }
        let languageStart = candidate.index(candidate.startIndex, offsetBy: length)
        let language = candidate[languageStart...]
            .trimmingCharacters(in: .whitespaces)
        return CodeFence(
            character: character,
            length: length,
            language: language.isEmpty ? nil : language
        )
    }

    private static func fencedCodeBlock(
        startingAt lineIndex: Int,
        fence: CodeFence,
        in lines: [String]
    ) -> (value: NoteMarkdownCodeBlock, nextLineIndex: Int) {
        var codeLines: [String] = []
        var nextLineIndex = lineIndex + 1

        while lines.indices.contains(nextLineIndex) {
            if isClosingFence(lines[nextLineIndex], matching: fence) {
                nextLineIndex += 1
                break
            }
            codeLines.append(lines[nextLineIndex])
            nextLineIndex += 1
        }

        return (
            NoteMarkdownCodeBlock(
                language: fence.language,
                code: codeLines.joined(separator: "\n")
            ),
            nextLineIndex
        )
    }

    private static func isClosingFence(_ line: String, matching fence: CodeFence) -> Bool {
        let candidate = line.trimmingCharacters(in: .whitespaces)
        let markerLength = candidate.prefix(while: { $0 == fence.character }).count
        guard markerLength >= fence.length else { return false }
        let markerEnd = candidate.index(candidate.startIndex, offsetBy: markerLength)
        return candidate[markerEnd...].allSatisfy(\.isWhitespace)
    }

    private static func blockQuoteText(from line: String) -> String? {
        let candidate = line.drop(while: \.isWhitespace)
        guard candidate.first == ">" else { return nil }
        let contentStart = candidate.index(after: candidate.startIndex)
        return String(candidate[contentStart...].drop(while: \.isWhitespace))
    }

    private static func blockQuote(
        startingAt lineIndex: Int,
        in lines: [String]
    ) -> (text: String, nextLineIndex: Int) {
        var quoteLines: [String] = []
        var nextLineIndex = lineIndex
        while lines.indices.contains(nextLineIndex),
              let quoteText = blockQuoteText(from: lines[nextLineIndex]) {
            quoteLines.append(quoteText)
            nextLineIndex += 1
        }
        return (quoteLines.joined(separator: "\n"), nextLineIndex)
    }

    private static func listItem(from line: String) -> ParsedListItem? {
        let indentationCount = line.prefix(while: \.isWhitespace).count
        let candidate = line.drop(while: \.isWhitespace)

        if let marker = candidate.first,
           marker == "-" || marker == "*" || marker == "+" {
            let textStart = candidate.index(after: candidate.startIndex)
            let suffix = candidate[textStart...]
            guard suffix.first?.isWhitespace == true else { return nil }
            return ParsedListItem(
                isOrdered: false,
                number: 1,
                text: String(suffix.drop(while: \.isWhitespace)),
                indentationLevel: indentationCount / 2
            )
        }

        let digits = candidate.prefix(while: \.isNumber)
        guard !digits.isEmpty,
              let number = Int(digits) else { return nil }
        let delimiterIndex = candidate.index(candidate.startIndex, offsetBy: digits.count)
        guard delimiterIndex < candidate.endIndex,
              candidate[delimiterIndex] == "." || candidate[delimiterIndex] == ")" else {
            return nil
        }
        let textStart = candidate.index(after: delimiterIndex)
        let suffix = candidate[textStart...]
        guard suffix.first?.isWhitespace == true else { return nil }
        return ParsedListItem(
            isOrdered: true,
            number: number,
            text: String(suffix.drop(while: \.isWhitespace)),
            indentationLevel: indentationCount / 2
        )
    }

    private static func markdownList(
        startingAt lineIndex: Int,
        firstItem: ParsedListItem,
        in lines: [String]
    ) -> (value: NoteMarkdownList, nextLineIndex: Int) {
        var items: [NoteMarkdownListItem] = []
        var nextLineIndex = lineIndex
        while lines.indices.contains(nextLineIndex),
              let item = listItem(from: lines[nextLineIndex]),
              item.isOrdered == firstItem.isOrdered {
            items.append(NoteMarkdownListItem(
                text: item.text,
                indentationLevel: item.indentationLevel
            ))
            nextLineIndex += 1
        }
        return (
            NoteMarkdownList(
                isOrdered: firstItem.isOrdered,
                startingNumber: firstItem.number,
                items: items
            ),
            nextLineIndex
        )
    }

    private static func table(
        startingAt lineIndex: Int,
        in lines: [String]
    ) -> (value: NoteMarkdownTable, nextLineIndex: Int)? {
        guard lines.indices.contains(lineIndex + 1),
              let headers = tableCells(from: lines[lineIndex]),
              headers.count >= 2,
              let separatorCells = tableCells(from: lines[lineIndex + 1]),
              separatorCells.count == headers.count else {
            return nil
        }

        let alignments = separatorCells.compactMap(tableAlignment(from:))
        guard alignments.count == headers.count else { return nil }

        var rows: [[String]] = []
        var nextLineIndex = lineIndex + 2
        while lines.indices.contains(nextLineIndex),
              !lines[nextLineIndex].trimmingCharacters(in: .whitespaces).isEmpty,
              let cells = tableCells(from: lines[nextLineIndex]) {
            rows.append(normalized(cells: cells, columnCount: headers.count))
            nextLineIndex += 1
        }

        return (
            NoteMarkdownTable(
                headers: headers,
                alignments: alignments,
                rows: rows
            ),
            nextLineIndex
        )
    }

    private static func tableCells(from line: String) -> [String]? {
        var source = line.trimmingCharacters(in: .whitespaces)
        guard source.contains("|") else { return nil }
        if source.first == "|" { source.removeFirst() }
        if source.last == "|" { source.removeLast() }

        var cells: [String] = []
        var current = ""
        var isEscaped = false
        for character in source {
            if character == "|" && !isEscaped {
                cells.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(character)
            }

            if character == "\\" && !isEscaped {
                isEscaped = true
            } else {
                isEscaped = false
            }
        }
        cells.append(current.trimmingCharacters(in: .whitespaces))
        return cells
    }

    private static func tableAlignment(from separator: String) -> MarkdownTableColumnAlignment? {
        var marker = separator.trimmingCharacters(in: .whitespaces)
        let hasLeadingColon = marker.first == ":"
        let hasTrailingColon = marker.last == ":"
        if hasLeadingColon { marker.removeFirst() }
        if hasTrailingColon, !marker.isEmpty { marker.removeLast() }
        guard marker.count >= 3, marker.allSatisfy({ $0 == "-" }) else { return nil }

        if hasLeadingColon && hasTrailingColon { return .center }
        if hasTrailingColon { return .trailing }
        return .leading
    }

    private static func normalized(cells: [String], columnCount: Int) -> [String] {
        if cells.count == columnCount { return cells }
        if cells.count < columnCount {
            return cells + Array(repeating: "", count: columnCount - cells.count)
        }
        return Array(cells.prefix(columnCount))
    }
}

enum NoteJSON {
    static func formattedString(from content: String) -> String? {
        let candidate = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = candidate.first,
              let last = candidate.last,
              (first == "{" && last == "}") || (first == "[" && last == "]"),
              let sourceData = candidate.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: sourceData),
              object is [String: Any] || object is [Any],
              let formattedData = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
              ) else {
            return nil
        }
        return String(data: formattedData, encoding: .utf8)
    }
}

enum MarkdownExporter {
    static func document(notes: [Note], exportedAt: Date = Date()) -> String {
        var sections = [
            MarkdownTransferFormat.documentTitle,
            "",
            "Exported: \(MarkdownTransferFormat.iso8601String(from: exportedAt))"
        ]

        for (index, note) in notes.enumerated() {
            let heading = note.title.flatMap(TitleSanitizer.sanitize) ?? "Note \(index + 1)"
            let tags = note.tags.isEmpty
                ? "None"
                : note.tags.map(MarkdownTransferFormat.escapeInlineMarkdown).joined(separator: ", ")

            sections.append(contentsOf: [
                "",
                "---",
                "",
                "## \(MarkdownTransferFormat.escapeInlineMarkdown(heading))"
            ])
            if note.title.flatMap(TitleSanitizer.sanitize) == nil {
                sections.append(MarkdownTransferFormat.untitledNoteMarker)
            }
            sections.append(contentsOf: [
                "",
                "- Created: \(MarkdownTransferFormat.iso8601String(from: note.timestamp))",
                "- Tags: \(tags)",
                "",
                MarkdownTransferFormat.contentStartMarker,
                ContentSanitizer.sanitize(note.content),
                MarkdownTransferFormat.contentEndMarker
            ])
        }

        return sections.joined(separator: "\n") + "\n"
    }
}

struct NoteImportResult: Equatable {
    let importedCount: Int
    let skippedCount: Int
}

enum MarkdownImporter {
    static func notes(from document: String) throws -> [Note] {
        let normalizedDocument = document
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalizedDocument.components(separatedBy: "\n")
        var lineIndex = 0

        guard lines.first == MarkdownTransferFormat.documentTitle else {
            throw MarkdownImportError.invalidFormat("The file is not a Quick Notes export.")
        }
        lineIndex += 1
        skipBlankLines(in: lines, lineIndex: &lineIndex)

        guard lines.indices.contains(lineIndex),
              lines[lineIndex].hasPrefix("Exported: "),
              MarkdownTransferFormat.date(
                from: String(lines[lineIndex].dropFirst("Exported: ".count))
              ) != nil else {
            throw MarkdownImportError.invalidFormat("The export date is missing or invalid.")
        }
        lineIndex += 1
        skipBlankLines(in: lines, lineIndex: &lineIndex)

        var importedNotes: [Note] = []
        while lineIndex < lines.count {
            guard lines[lineIndex] == MarkdownTransferFormat.noteSeparator else {
                throw MarkdownImportError.invalidFormat(
                    "Unexpected text before note \(importedNotes.count + 1)."
                )
            }
            lineIndex += 1
            skipBlankLines(in: lines, lineIndex: &lineIndex)

            guard lines.indices.contains(lineIndex), lines[lineIndex].hasPrefix("## ") else {
                throw MarkdownImportError.invalidFormat(
                    "Note \(importedNotes.count + 1) is missing its title heading."
                )
            }
            let heading = MarkdownTransferFormat.unescapeInlineMarkdown(
                String(lines[lineIndex].dropFirst(3))
            )
            lineIndex += 1

            let isUntitled = lines.indices.contains(lineIndex)
                && lines[lineIndex] == MarkdownTransferFormat.untitledNoteMarker
            if isUntitled {
                lineIndex += 1
            }
            skipBlankLines(in: lines, lineIndex: &lineIndex)

            let noteNumber = importedNotes.count + 1
            let created = try parseCreatedDate(
                from: lines,
                lineIndex: &lineIndex,
                noteNumber: noteNumber
            )
            let tags = try parseTags(
                from: lines,
                lineIndex: &lineIndex,
                noteNumber: noteNumber
            )
            skipBlankLines(in: lines, lineIndex: &lineIndex)

            guard lines.indices.contains(lineIndex),
                  lines[lineIndex] == MarkdownTransferFormat.contentStartMarker else {
                throw MarkdownImportError.invalidFormat(
                    "Note \(noteNumber) is missing the content start marker."
                )
            }
            lineIndex += 1

            let contentStartIndex = lineIndex
            guard let contentEndIndex = contentEndIndex(
                in: lines,
                startingAt: contentStartIndex
            ) else {
                throw MarkdownImportError.invalidFormat(
                    "Note \(noteNumber) is missing the content end marker."
                )
            }
            let content = ContentSanitizer.sanitize(
                lines[contentStartIndex..<contentEndIndex].joined(separator: "\n")
            )
            guard NoteContentPolicy.canSave(content) else {
                throw MarkdownImportError.invalidFormat(
                    "Note \(noteNumber) has empty content or exceeds \(NoteContentPolicy.maximumCharacterCount) characters."
                )
            }

            importedNotes.append(Note(
                id: UUID(),
                title: isUntitled ? nil : TitleSanitizer.sanitize(heading),
                content: content,
                tags: tags,
                timestamp: created,
                expanded: false
            ))

            lineIndex = contentEndIndex + 1
            skipBlankLines(in: lines, lineIndex: &lineIndex)
        }

        return importedNotes
    }

    private static func parseCreatedDate(
        from lines: [String],
        lineIndex: inout Int,
        noteNumber: Int
    ) throws -> Date {
        let prefix = "- Created: "
        guard lines.indices.contains(lineIndex), lines[lineIndex].hasPrefix(prefix),
              let date = MarkdownTransferFormat.date(
                from: String(lines[lineIndex].dropFirst(prefix.count))
              ) else {
            throw MarkdownImportError.invalidFormat(
                "Note \(noteNumber) has a missing or invalid Created value."
            )
        }
        lineIndex += 1
        return date
    }

    private static func parseTags(
        from lines: [String],
        lineIndex: inout Int,
        noteNumber: Int
    ) throws -> [String] {
        let prefix = "- Tags: "
        guard lines.indices.contains(lineIndex), lines[lineIndex].hasPrefix(prefix) else {
            throw MarkdownImportError.invalidFormat(
                "Note \(noteNumber) is missing its Tags value."
            )
        }

        let source = String(lines[lineIndex].dropFirst(prefix.count))
        lineIndex += 1
        guard source != "None" else { return [] }

        var seenTags: Set<String> = []
        return source
            .components(separatedBy: ", ")
            .map(MarkdownTransferFormat.unescapeInlineMarkdown)
            .filter { !$0.isEmpty && seenTags.insert($0).inserted }
    }

    private static func contentEndIndex(
        in lines: [String],
        startingAt startIndex: Int
    ) -> Int? {
        for candidateIndex in startIndex..<lines.count
            where lines[candidateIndex] == MarkdownTransferFormat.contentEndMarker {
            var nextIndex = candidateIndex + 1
            skipBlankLines(in: lines, lineIndex: &nextIndex)
            if nextIndex == lines.count
                || lines[nextIndex] == MarkdownTransferFormat.noteSeparator {
                return candidateIndex
            }
        }
        return nil
    }

    private static func skipBlankLines(in lines: [String], lineIndex: inout Int) {
        while lines.indices.contains(lineIndex), lines[lineIndex].isEmpty {
            lineIndex += 1
        }
    }
}

enum MarkdownImportError: LocalizedError {
    case invalidFormat(String)

    var errorDescription: String? {
        switch self {
        case .invalidFormat(let reason):
            "Import failed: \(reason)"
        }
    }
}

private enum MarkdownTransferFormat {
    static let documentTitle = "# Quick Notes"
    static let noteSeparator = "---"
    static let untitledNoteMarker = "<!-- note-title:untitled -->"
    static let contentStartMarker = "<!-- note-content:start -->"
    static let contentEndMarker = "<!-- note-content:end -->"

    static func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    static func date(from source: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: source)
    }

    static func escapeInlineMarkdown(_ text: String) -> String {
        text.replacingOccurrences(
            of: #"([\\`*_{}\[\]()<>#+\-.!|])"#,
            with: #"\\$1"#,
            options: .regularExpression
        )
    }

    static func unescapeInlineMarkdown(_ text: String) -> String {
        text.replacingOccurrences(
            of: #"\\([\\`*_{}\[\]()<>#+\-.!|])"#,
            with: "$1",
            options: .regularExpression
        )
    }
}
