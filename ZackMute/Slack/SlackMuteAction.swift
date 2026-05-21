import AppKit

// Slack Huddle keyboard shortcut (visible in button tooltip):
//   Mic toggle: Cmd+Shift+Space  — works even when Slack is in the background
//
// Camera toggle: Slack Huddle has no keyboard shortcut for this.
// ZackMute shows a notification instead of silently doing nothing.

enum SlackMuteAction {
    @MainActor
    static func toggle() {
        guard let slack = findSlack() else { print("[ZackMute] Slack not running"); return }
        // Cmd+Shift+Space  (kVK_Space = 0x31)
        sendGlobal(key: 0x31, flags: [.maskCommand, .maskShift], to: slack.processIdentifier)
        print("[ZackMute] Slack mute: sent Cmd+Shift+Space")
    }

@MainActor
    static var isSlackRunning: Bool { findSlack() != nil }

    @MainActor
    static func findSlackApp() -> NSRunningApplication? { findSlack() }

    // MARK: - Private

    @MainActor
    private static func findSlack() -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first {
            $0.bundleIdentifier == "com.tinyspeck.slackmacgap" ||
            ($0.localizedName?.lowercased().contains("slack") == true)
        }
    }

    // Posts a keyboard event directly to the Slack process.
    // postToPid bypasses the frontmost-app check — Slack receives the event
    // even when another app is in the foreground.
    private static func sendGlobal(key: CGKeyCode, flags: CGEventFlags, to pid: pid_t) {
        let src = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: true),
              let up   = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: false)
        else { return }
        down.flags = flags
        up.flags   = flags
        down.postToPid(pid)
        up.postToPid(pid)
    }
}
