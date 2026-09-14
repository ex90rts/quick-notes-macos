import Foundation

enum QuickNotesAgentSkillInstaller {
    static let skillName = "quick-notes"

    static func installationURL(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        homeDirectory
            .appendingPathComponent(".agents", isDirectory: true)
            .appendingPathComponent("skills", isDirectory: true)
            .appendingPathComponent(skillName, isDirectory: true)
    }

    static func installFromMainBundle() throws -> URL {
        let sourceURL = try bundledSkillURL()
        return try install(from: sourceURL, to: installationURL())
    }

    static func bundledSkillMarkdown() throws -> String {
        try skillMarkdown(from: bundledSkillURL())
    }

    static func skillMarkdown(from sourceURL: URL) throws -> String {
        let skillManifestURL = sourceURL.appendingPathComponent("SKILL.md")
        guard FileManager.default.fileExists(atPath: skillManifestURL.path) else {
            throw QuickNotesAgentSkillInstallationError.invalidBundledSkill
        }
        return try String(contentsOf: skillManifestURL, encoding: .utf8)
    }

    private static func bundledSkillURL() throws -> URL {
        guard let resourceURL = Bundle.main.resourceURL else {
            throw QuickNotesAgentSkillInstallationError.bundledSkillMissing
        }
        let sourceURL = resourceURL
            .appendingPathComponent("AgentSkills", isDirectory: true)
            .appendingPathComponent(skillName, isDirectory: true)
        guard FileManager.default.fileExists(
            atPath: sourceURL.appendingPathComponent("SKILL.md").path
        ) else {
            throw QuickNotesAgentSkillInstallationError.bundledSkillMissing
        }
        return sourceURL
    }

    static func install(from sourceURL: URL, to destinationURL: URL) throws -> URL {
        let fileManager = FileManager.default
        let skillManifestURL = sourceURL.appendingPathComponent("SKILL.md")
        guard fileManager.fileExists(atPath: skillManifestURL.path) else {
            throw QuickNotesAgentSkillInstallationError.invalidBundledSkill
        }

        let destinationParentURL = destinationURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: destinationParentURL,
            withIntermediateDirectories: true
        )

        let stagingURL = destinationParentURL.appendingPathComponent(
            ".\(skillName)-staging-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.copyItem(at: sourceURL, to: stagingURL)
        defer { try? fileManager.removeItem(at: stagingURL) }

        guard fileManager.fileExists(atPath: destinationURL.path) else {
            try fileManager.moveItem(at: stagingURL, to: destinationURL)
            return destinationURL
        }

        let backupURL = destinationParentURL.appendingPathComponent(
            ".\(skillName)-backup-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.moveItem(at: destinationURL, to: backupURL)
        do {
            try fileManager.moveItem(at: stagingURL, to: destinationURL)
            try fileManager.removeItem(at: backupURL)
            return destinationURL
        } catch {
            try? fileManager.moveItem(at: backupURL, to: destinationURL)
            throw error
        }
    }
}

private enum QuickNotesAgentSkillInstallationError: LocalizedError {
    case bundledSkillMissing
    case invalidBundledSkill

    var errorDescription: String? {
        switch self {
        case .bundledSkillMissing:
            "The Quick Notes skill is missing from this application. Reinstall Quick Notes and try again."
        case .invalidBundledSkill:
            "The bundled Quick Notes skill is incomplete. Reinstall Quick Notes and try again."
        }
    }
}
