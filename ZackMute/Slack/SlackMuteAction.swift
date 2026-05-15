import AppKit
import CoreGraphics

enum SlackMuteAction {
    @MainActor
    static func toggle() {
        guard AXIsProcessTrusted() else { TeamsMuteAction.requestAccessibility(); return }
        guard let slack = findSlack() else { print("[ZackMute] Slack not running"); return }
        // M toggles mute in Slack Huddle (no modifiers)
        sendKey(0x2E, flags: [], to: slack.processIdentifier)
        print("[ZackMute] M sent to Slack pid \(slack.processIdentifier)")
    }

    @MainActor
    static func toggleCamera() {
        guard AXIsProcessTrusted() else { TeamsMuteAction.requestAccessibility(); return }
        guard let slack = findSlack() else { print("[ZackMute] Slack not running"); return }
        // V toggles camera in Slack Huddle (no modifiers)
        sendKey(0x09, flags: [], to: slack.processIdentifier)
        print("[ZackMute] V sent to Slack pid \(slack.processIdentifier)")
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

    private static func sendKey(_ keyCode: CGKeyCode, flags: CGEventFlags, to pid: pid_t) {
        let src = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true),
              let up   = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        else { return }
        down.flags = flags
        up.flags   = flags
        down.postToPid(pid)
        up.postToPid(pid)
    }
}
