import Foundation
import SwiftData

/// Delivers change notices between the MCP subprocess and the running app without
/// exposing note data on a network connection.
enum QuickNotesLibraryChange {
    static let notification = Notification.Name("com.webber.QuickNotes.libraryDidChange")

    static func post() {
        DistributedNotificationCenter.default().post(name: notification, object: nil)
    }
}

enum QuickNotesMCPStdioConfiguration {
    static let launchArgument = "--mcp"

    static var configuration: String {
        configuration(
            executablePath: Bundle.main.executablePath
                ?? CommandLine.arguments.first
                ?? "QuickNotes"
        )
    }

    static func configuration(executablePath: String) -> String {
        let object: [String: Any] = [
            "mcpServers": [
                "quick-notes": [
                    "command": executablePath,
                    "args": [launchArgument]
                ]
            ]
        ]
        guard let data = try? JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys]
        ) else {
            return "{}"
        }
        return String(decoding: data, as: UTF8.self)
    }
}

@MainActor
enum QuickNotesMCPStdioServer {
    static func run() {
        do {
            let modelContainer = try AppPersistence.makeModelContainer()
            let repository = SwiftDataNotesRepository(modelContainer: modelContainer)
            try repository.seedDefaultTagsIfNeeded()
            let service = QuickNotesMCPService(repository: repository)

            while let line = readLine(strippingNewline: true) {
                guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    continue
                }
                guard let data = line.data(using: .utf8),
                      let request = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    write([
                        "jsonrpc": "2.0",
                        "id": NSNull(),
                        "error": [
                            "code": -32700,
                            "message": "Request line must be a JSON-RPC object."
                        ]
                    ])
                    continue
                }
                guard let response = QuickNotesMCPProtocol.response(for: request, service: service) else {
                    continue
                }
                write(response)
            }
        } catch {
            let message = "Quick Notes MCP could not start: \(error.localizedDescription)\n"
            FileHandle.standardError.write(Data(message.utf8))
        }
    }

    private static func write(_ response: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: response) else { return }
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data([10]))
    }
}

@MainActor
enum QuickNotesMCPProtocol {
    static let protocolVersion = "2025-06-18"

    static func response(
        for request: [String: Any],
        service: QuickNotesMCPService
    ) -> [String: Any]? {
        let id = request["id"]
        let method = request["method"] as? String
        let parameters = request["params"] as? [String: Any] ?? [:]

        switch method {
        case "initialize":
            guard AppPreferences.isMCPServerEnabled() else {
                return errorResponse(
                    id: id,
                    code: -32000,
                    message: "Quick Notes MCP is disabled. Enable it in Quick Notes settings before connecting an Agent."
                )
            }
            return successResponse(id: id, result: [
                "protocolVersion": protocolVersion,
                "capabilities": ["tools": ["listChanged": false]],
                "serverInfo": [
                    "name": "quick-notes-mcp-server",
                    "title": "Quick Notes",
                    "version": appVersion
                ]
            ])

        case "notifications/initialized":
            return nil

        case "tools/list":
            guard AppPreferences.isMCPServerEnabled() else {
                return errorResponse(id: id, code: -32000, message: "Quick Notes MCP is disabled in settings.")
            }
            return successResponse(id: id, result: ["tools": service.toolDefinitions])

        case "tools/call":
            guard AppPreferences.isMCPServerEnabled() else {
                return successResponse(id: id, result: toolError("Quick Notes MCP is disabled. Enable it in Quick Notes settings and reconnect the Agent."))
            }
            guard let toolName = parameters["name"] as? String else {
                return errorResponse(id: id, code: -32602, message: "tools/call requires a tool name.")
            }
            let arguments = parameters["arguments"] as? [String: Any] ?? [:]
            return successResponse(id: id, result: service.call(toolName, arguments: arguments))

        case nil:
            return nil

        default:
            return errorResponse(id: id, code: -32601, message: "Unsupported MCP method: \(method ?? "unknown").")
        }
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    private static func successResponse(id: Any?, result: [String: Any]) -> [String: Any] {
        ["jsonrpc": "2.0", "id": id ?? NSNull(), "result": result]
    }

    private static func errorResponse(id: Any?, code: Int, message: String) -> [String: Any] {
        [
            "jsonrpc": "2.0",
            "id": id ?? NSNull(),
            "error": ["code": code, "message": message]
        ]
    }

    private static func toolError(_ message: String) -> [String: Any] {
        ["content": [["type": "text", "text": message]], "isError": true]
    }
}

@MainActor
final class QuickNotesMCPService {
    private let repository: any NotesRepository
    private let deletionPermission: () -> Bool
    private let iso8601Formatter = ISO8601DateFormatter()

    init(
        repository: any NotesRepository,
        deletionPermission: @escaping () -> Bool = { AppPreferences.isMCPDeletionEnabled() }
    ) {
        self.repository = repository
        self.deletionPermission = deletionPermission
    }

    var toolDefinitions: [[String: Any]] {
        var definitions: [[String: Any]] = [
            tool(
                name: "quick_notes_list_notes",
                title: "List Quick Notes",
                description: "Read notes from the local Quick Notes library. Omit tags to read all notes; provide one or more tags to return notes carrying any of those tags.",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "tags": stringArraySchema(description: "Optional tags to filter by. A note matches when it has any supplied tag."),
                        "limit": integerSchema(description: "Maximum notes to return, from 1 to 1,000. Defaults to 100.", minimum: 1, maximum: 1_000),
                        "offset": integerSchema(description: "Number of matching notes to skip. Defaults to 0.", minimum: 0, maximum: Int.max)
                    ],
                    "additionalProperties": false
                ],
                readOnly: true,
                idempotent: true
            ),
            tool(
                name: "quick_notes_list_tags",
                title: "List Quick Notes Tags",
                description: "Read every tag in the local Quick Notes library. Use these exact values when creating or updating a note.",
                inputSchema: [
                    "type": "object",
                    "properties": [:],
                    "additionalProperties": false
                ],
                readOnly: true,
                idempotent: true
            ),
            tool(
                name: "quick_notes_create_note",
                title: "Create Quick Note",
                description: "Create a note in the local Quick Notes library. Tags must already exist; use quick_notes_add_tag first when needed.",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "title": stringSchema(description: "Optional note title.", minimum: 0, maximum: 500),
                        "content": stringSchema(description: "Required Markdown or plain-text note content, up to 5,000 characters after cleanup.", minimum: 1, maximum: NoteContentPolicy.maximumCharacterCount),
                        "tags": stringArraySchema(description: "Existing tags to apply to the new note."),
                        "rendering_mode": renderingModeSchema,
                        "code_language": stringSchema(description: "Code language when rendering_mode is code, such as swift or python.", minimum: 1, maximum: 30),
                        "is_pinned": ["type": "boolean", "description": "Whether the note is pinned. Defaults to false."]
                    ],
                    "required": ["content"],
                    "additionalProperties": false
                ],
                readOnly: false,
                idempotent: false
            ),
            tool(
                name: "quick_notes_update_note",
                title: "Update Quick Note",
                description: "Replace the required content of an existing note, and optionally replace its title, tags, or rendering mode. This tool cannot delete notes.",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "id": stringSchema(description: "UUID of the note to update.", minimum: 36, maximum: 36),
                        "title": ["type": ["string", "null"], "description": "Replacement title, or null to clear it."],
                        "content": stringSchema(description: "Replacement content, up to 5,000 characters after cleanup.", minimum: 1, maximum: NoteContentPolicy.maximumCharacterCount),
                        "tags": stringArraySchema(description: "Replacement list of existing tags."),
                        "rendering_mode": renderingModeSchema,
                        "code_language": stringSchema(description: "Code language when rendering_mode is code.", minimum: 1, maximum: 30)
                    ],
                    "required": ["id", "content"],
                    "additionalProperties": false
                ],
                readOnly: false,
                idempotent: true
            ),
            tool(
                name: "quick_notes_add_tag",
                title: "Add Quick Notes Tag",
                description: "Add a tag to the local Quick Notes library.",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "name": stringSchema(description: "New tag name: up to 10 letters, numbers, spaces, hyphens, or underscores.", minimum: 1, maximum: TagNamePolicy.maximumCharacterCount)
                    ],
                    "required": ["name"],
                    "additionalProperties": false
                ],
                readOnly: false,
                idempotent: false
            )
        ]

        if deletionPermission() {
            definitions.append(contentsOf: [
                tool(
                    name: "quick_notes_delete_note",
                    title: "Delete Quick Note",
                    description: "Permanently delete one note. Only call after the user explicitly identifies the note as #<UUID>; pass that UUID without the # as id.",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "id": stringSchema(description: "The UUID from the user-specified #<UUID> note identifier.", minimum: 36, maximum: 36)
                        ],
                        "required": ["id"],
                        "additionalProperties": false
                    ],
                    readOnly: false,
                    idempotent: true
                ),
                tool(
                    name: "quick_notes_delete_tag",
                    title: "Delete Unused Quick Notes Tag",
                    description: "Permanently delete an unused tag. The tag value must exactly match an existing tag and cannot be attached to any note.",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "tag": stringSchema(description: "The exact existing tag value to delete; matching is case-sensitive and is not normalized.", minimum: 1, maximum: TagNamePolicy.maximumCharacterCount)
                        ],
                        "required": ["tag"],
                        "additionalProperties": false
                    ],
                    readOnly: false,
                    idempotent: true
                )
            ])
        }

        return definitions
    }

    func call(_ name: String, arguments: [String: Any]) -> [String: Any] {
        do {
            let result: [String: Any]
            switch name {
            case "quick_notes_list_notes":
                try validateArguments(arguments, allowed: ["tags", "limit", "offset"])
                result = try listNotes(arguments)
            case "quick_notes_list_tags":
                try validateArguments(arguments, allowed: [])
                result = try listTags()
            case "quick_notes_create_note":
                try validateArguments(arguments, allowed: ["title", "content", "tags", "rendering_mode", "code_language", "is_pinned"])
                result = try createNote(arguments)
            case "quick_notes_update_note":
                try validateArguments(arguments, allowed: ["id", "title", "content", "tags", "rendering_mode", "code_language"])
                result = try updateNote(arguments)
            case "quick_notes_add_tag":
                try validateArguments(arguments, allowed: ["name"])
                result = try addTag(arguments)
            case "quick_notes_delete_note":
                try requireDeletionPermission()
                try validateArguments(arguments, allowed: ["id"])
                result = try deleteNote(arguments)
            case "quick_notes_delete_tag":
                try requireDeletionPermission()
                try validateArguments(arguments, allowed: ["tag"])
                result = try deleteTag(arguments)
            default: return toolError("Unknown tool: \(name).")
            }
            let text = try prettyJSON(result)
            return [
                "content": [["type": "text", "text": text]],
                "structuredContent": result,
                "isError": false
            ]
        } catch {
            return toolError(error.localizedDescription)
        }
    }

    private func listNotes(_ arguments: [String: Any]) throws -> [String: Any] {
        let tags = try optionalStringArray(arguments, key: "tags")
        let limit = try boundedInteger(arguments, key: "limit", defaultValue: 100, range: 1...1_000)
        let offset = try boundedInteger(arguments, key: "offset", defaultValue: 0, range: 0...Int.max)
        let allNotes = try repository.fetchNotes()
        let matchingNotes = tags.isEmpty ? allNotes : allNotes.filter { note in
            !Set(note.tags).isDisjoint(with: tags)
        }
        let page = Array(matchingNotes.dropFirst(offset).prefix(limit))
        return [
            "total": matchingNotes.count,
            "count": page.count,
            "offset": offset,
            "notes": page.map(notePayload),
            "has_more": offset + page.count < matchingNotes.count,
            "next_offset": offset + page.count < matchingNotes.count ? offset + page.count : NSNull()
        ]
    }

    private func listTags() throws -> [String: Any] {
        let tags = try repository.fetchTags()
        return ["count": tags.count, "tags": tags]
    }

    private func createNote(_ arguments: [String: Any]) throws -> [String: Any] {
        let content = try requiredString(arguments, key: "content")
        guard NoteContentPolicy.canSave(content) else {
            throw MCPToolError("Note content must contain text and be no more than \(NoteContentPolicy.maximumCharacterCount) characters.")
        }
        let tags = try optionalStringArray(arguments, key: "tags")
        try validateExistingTags(tags)
        let cleanContent = ContentSanitizer.sanitize(content)
        let note = Note(
            id: UUID(),
            title: TitleSanitizer.sanitize(try optionalString(arguments, key: "title") ?? ""),
            content: cleanContent,
            tags: ordered(tags),
            timestamp: Date(),
            isPinned: try optionalBoolean(arguments, key: "is_pinned") ?? false,
            renderingMode: try renderingMode(arguments, content: cleanContent, fallback: .automatic),
            expanded: false
        )
        try repository.insertNote(note)
        QuickNotesLibraryChange.post()
        return ["note": notePayload(note)]
    }

    private func updateNote(_ arguments: [String: Any]) throws -> [String: Any] {
        let id = try requiredUUID(arguments, key: "id")
        let content = try requiredString(arguments, key: "content")
        guard NoteContentPolicy.canSave(content) else {
            throw MCPToolError("Note content must contain text and be no more than \(NoteContentPolicy.maximumCharacterCount) characters.")
        }
        guard var note = try repository.fetchNotes().first(where: { $0.id == id }) else {
            throw MCPToolError("No note exists with ID \(id.uuidString). Read notes first to obtain a valid note ID.")
        }
        note.content = ContentSanitizer.sanitize(content)

        if arguments.keys.contains("title") {
            note.title = arguments["title"] is NSNull ? nil : TitleSanitizer.sanitize(try requiredString(arguments, key: "title"))
        }
        if arguments.keys.contains("tags") {
            let tags = try optionalStringArray(arguments, key: "tags")
            try validateExistingTags(tags)
            note.tags = ordered(tags)
        }
        if arguments.keys.contains("rendering_mode") || arguments.keys.contains("code_language") {
            note.renderingMode = try renderingMode(arguments, content: note.content, fallback: note.renderingMode)
        }

        try repository.updateNote(note)
        QuickNotesLibraryChange.post()
        return ["note": notePayload(note)]
    }

    private func addTag(_ arguments: [String: Any]) throws -> [String: Any] {
        let rawName = try requiredString(arguments, key: "name")
        let existingTags = try repository.fetchTags()
        if let message = TagNamePolicy.validationError(for: rawName, existingTags: existingTags) {
            throw MCPToolError(message)
        }
        let name = TagNamePolicy.sanitized(rawName)
        try repository.insertTag(name)
        QuickNotesLibraryChange.post()
        return ["tag": name]
    }

    private func deleteNote(_ arguments: [String: Any]) throws -> [String: Any] {
        let id = try requiredUUID(arguments, key: "id")
        guard try repository.fetchNotes().contains(where: { $0.id == id }) else {
            throw MCPToolError("No note exists with ID \(id.uuidString). Read notes first to obtain a valid note ID.")
        }
        try repository.deleteNote(id: id)
        QuickNotesLibraryChange.post()
        return ["deleted_note_id": id.uuidString.lowercased()]
    }

    private func deleteTag(_ arguments: [String: Any]) throws -> [String: Any] {
        let tag = try requiredString(arguments, key: "tag")
        guard try repository.fetchTags().contains(tag) else {
            throw MCPToolError("No tag exactly matching '\(tag)' exists.")
        }
        guard !(try repository.fetchNotes()).contains(where: { $0.tags.contains(tag) }) else {
            throw MCPToolError("Tag '\(tag)' is still assigned to one or more notes and cannot be deleted.")
        }
        try repository.deleteTag(tag)
        QuickNotesLibraryChange.post()
        return ["deleted_tag": tag]
    }

    private func requireDeletionPermission() throws {
        guard deletionPermission() else {
            throw MCPToolError("MCP deletion is disabled in Quick Notes settings. Enable Allow MCP Delete before deleting notes or tags.")
        }
    }

    private func validateExistingTags(_ tags: [String]) throws {
        let knownTags = Set(try repository.fetchTags())
        let unknownTags = Set(tags).subtracting(knownTags).sorted()
        guard unknownTags.isEmpty else {
            throw MCPToolError("Unknown tag(s): \(unknownTags.joined(separator: ", ")). Create them first with quick_notes_add_tag.")
        }
    }

    private func validateArguments(_ arguments: [String: Any], allowed: Set<String>) throws {
        let unsupported = Set(arguments.keys).subtracting(allowed).sorted()
        guard unsupported.isEmpty else {
            throw MCPToolError("Unsupported argument(s): \(unsupported.joined(separator: ", ")).")
        }
    }

    private func ordered(_ tags: [String]) -> [String] {
        Array(Set(tags)).sorted()
    }

    private func notePayload(_ note: Note) -> [String: Any] {
        [
            "id": note.id.uuidString.lowercased(),
            "title": note.title ?? NSNull(),
            "content": note.content,
            "tags": note.tags,
            "created_at": iso8601Formatter.string(from: note.timestamp),
            "is_pinned": note.isPinned,
            "rendering_mode": renderingModeName(note.renderingMode),
            "code_language": note.renderingMode.codeLanguage?.rawValue ?? NSNull()
        ]
    }

    private func renderingModeName(_ renderingMode: NoteRenderingMode) -> String {
        switch renderingMode {
        case .automatic: "automatic"
        case .plainText: "plain_text"
        case .markdown: "markdown"
        case .code: "code"
        }
    }

    private func renderingMode(
        _ arguments: [String: Any],
        content: String,
        fallback: NoteRenderingMode
    ) throws -> NoteRenderingMode {
        let modeName = try optionalString(arguments, key: "rendering_mode")
        let codeLanguageName = try optionalString(arguments, key: "code_language")
        let mode: NoteRenderingMode
        switch modeName ?? renderingModeName(fallback) {
        case "automatic": mode = .automatic
        case "plain_text": mode = .plainText
        case "markdown": mode = .markdown
        case "code":
            guard let codeLanguageName,
                  let language = NoteCodeLanguage(markdownIdentifier: codeLanguageName),
                  language != .automatic else {
                throw MCPToolError("code_language is required for rendering_mode 'code' and must be a supported language, such as swift or python.")
            }
            mode = .code(language)
        default:
            throw MCPToolError("rendering_mode must be automatic, plain_text, markdown, or code.")
        }
        return mode.resolvedForSaving(content: content)
    }

    private func tool(
        name: String,
        title: String,
        description: String,
        inputSchema: [String: Any],
        readOnly: Bool,
        idempotent: Bool
    ) -> [String: Any] {
        [
            "name": name,
            "title": title,
            "description": description,
            "inputSchema": inputSchema,
            "annotations": [
                "readOnlyHint": readOnly,
                "destructiveHint": false,
                "idempotentHint": idempotent,
                "openWorldHint": false
            ]
        ]
    }

    private var renderingModeSchema: [String: Any] {
        ["type": "string", "enum": ["automatic", "plain_text", "markdown", "code"], "description": "Rendering mode. Defaults to automatic for creation; omitted updates preserve the current mode."]
    }

    private func stringSchema(description: String, minimum: Int, maximum: Int) -> [String: Any] {
        ["type": "string", "description": description, "minLength": minimum, "maxLength": maximum]
    }

    private func stringArraySchema(description: String) -> [String: Any] {
        ["type": "array", "description": description, "items": ["type": "string"], "maxItems": 100, "uniqueItems": true]
    }

    private func integerSchema(description: String, minimum: Int, maximum: Int) -> [String: Any] {
        ["type": "integer", "description": description, "minimum": minimum, "maximum": maximum]
    }

    private func requiredString(_ arguments: [String: Any], key: String) throws -> String {
        guard let value = arguments[key] as? String else {
            throw MCPToolError("\(key) must be a string.")
        }
        return value
    }

    private func optionalString(_ arguments: [String: Any], key: String) throws -> String? {
        guard let value = arguments[key] else { return nil }
        guard let string = value as? String else {
            throw MCPToolError("\(key) must be a string.")
        }
        return string
    }

    private func optionalStringArray(_ arguments: [String: Any], key: String) throws -> [String] {
        guard let value = arguments[key] else { return [] }
        guard let strings = value as? [String] else {
            throw MCPToolError("\(key) must be an array of strings.")
        }
        return strings
    }

    private func requiredBoolean(_ arguments: [String: Any], key: String) throws -> Bool {
        guard let value = arguments[key] as? Bool else {
            throw MCPToolError("\(key) must be true or false.")
        }
        return value
    }

    private func optionalBoolean(_ arguments: [String: Any], key: String) throws -> Bool? {
        guard arguments.keys.contains(key) else { return nil }
        return try requiredBoolean(arguments, key: key)
    }

    private func requiredUUID(_ arguments: [String: Any], key: String) throws -> UUID {
        guard let value = UUID(uuidString: try requiredString(arguments, key: key)) else {
            throw MCPToolError("\(key) must be a valid UUID.")
        }
        return value
    }

    private func boundedInteger(
        _ arguments: [String: Any],
        key: String,
        defaultValue: Int,
        range: ClosedRange<Int>
    ) throws -> Int {
        guard let value = arguments[key] else { return defaultValue }
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID() else {
            throw MCPToolError("\(key) must be an integer.")
        }
        let integer = number.intValue
        guard number.doubleValue == Double(integer), range.contains(integer) else {
            throw MCPToolError("\(key) must be an integer between \(range.lowerBound) and \(range.upperBound).")
        }
        return integer
    }

    private func prettyJSON(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        guard let text = String(data: data, encoding: .utf8) else {
            throw MCPToolError("Could not encode the tool result.")
        }
        return text
    }

    private func toolError(_ message: String) -> [String: Any] {
        ["content": [["type": "text", "text": message]], "isError": true]
    }
}

private struct MCPToolError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
