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
    static func url(from content: String) -> URL? {
        let candidate = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty,
              candidate.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              let components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              components.host?.isEmpty == false,
              let url = components.url else {
            return nil
        }
        return url
    }
}

enum MarkdownExporter {
    static func document(notes: [Note], exportedAt: Date = Date()) -> String {
        var sections = [
            "# Quick Notes",
            "",
            "Exported: \(iso8601String(from: exportedAt))"
        ]

        for (index, note) in notes.enumerated() {
            let heading = note.title.flatMap(TitleSanitizer.sanitize) ?? "Note \(index + 1)"
            let tags = note.tags.isEmpty
                ? "None"
                : note.tags.map(escapeInlineMarkdown).joined(separator: ", ")

            sections.append(contentsOf: [
                "",
                "---",
                "",
                "## \(escapeInlineMarkdown(heading))",
                "",
                "- Created: \(iso8601String(from: note.timestamp))",
                "- Tags: \(tags)",
                "",
                ContentSanitizer.sanitize(note.content)
            ])
        }

        return sections.joined(separator: "\n") + "\n"
    }

    private static func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private static func escapeInlineMarkdown(_ text: String) -> String {
        text.replacingOccurrences(
            of: #"([\\`*_{}\[\]()<>#+\-.!|])"#,
            with: #"\\$1"#,
            options: .regularExpression
        )
    }
}
