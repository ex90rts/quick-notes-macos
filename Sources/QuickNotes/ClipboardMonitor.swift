import AppKit
import Foundation

@MainActor
final class ClipboardMonitor {
    private let onTextChange: @MainActor (String) -> Void
    private var timer: Timer?
    private var lastChangeCount: Int

    init(onTextChange: @escaping @MainActor (String) -> Void) {
        self.onTextChange = onTextChange
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func startMonitoring() {
        guard timer == nil else { return }

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.checkClipboard()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func ignoreCurrentPasteboardChange() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        guard let text = pasteboard.string(forType: .string),
              isValidClipboardContent(text) else { return }
        onTextChange(text)
    }

    private func isValidClipboardContent(_ content: String) -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (3..<1_000).contains(trimmed.count) else { return false }

        let excludedPrefixes = ["http://", "https://", "file://", "/"]
        guard !excludedPrefixes.contains(where: trimmed.hasPrefix),
              !trimmed.contains("\0"),
              !trimmed.contains("\u{FFFC}") else { return false }
        return true
    }

    deinit {
        MainActor.assumeIsolated {
            timer?.invalidate()
        }
    }
}
