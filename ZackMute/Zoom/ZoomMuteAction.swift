import AppKit

// Zoom keyboard shortcuts (global — work even when Zoom is in the background):
//   Mic toggle:    Cmd+Shift+A  (kVK_ANSI_A = 0x00)
//   Camera toggle: Cmd+Shift+V  (kVK_ANSI_V = 0x09)
//
// Both shortcuts work via postToPid without needing Zoom in the foreground.

enum ZoomMuteAction {
    @MainActor
    static func toggleMic() {
        guard let zoom = findZoom() else { print("[ZackMute] Zoom not running"); return }
        // Cmd+Shift+A
        sendGlobal(key: 0x00, flags: [.maskCommand, .maskShift], to: zoom.processIdentifier)
        print("[ZackMute] Zoom mic: sent Cmd+Shift+A")
    }

    @MainActor
    static func toggleCamera() {
        guard let zoom = findZoom() else { print("[ZackMute] Zoom not running"); return }
        // Cmd+Shift+V
        sendGlobal(key: 0x09, flags: [.maskCommand, .maskShift], to: zoom.processIdentifier)
        print("[ZackMute] Zoom camera: sent Cmd+Shift+V")
    }

    @MainActor
    static var isZoomRunning: Bool { findZoom() != nil }

    // MARK: - Internal (used by ZoomStatePoller for AX access)

    @MainActor
    static func findZoomApp() -> NSRunningApplication? { findZoom() }

    // MARK: - Private

    @MainActor
    private static func findZoom() -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first {
            $0.bundleIdentifier == "us.zoom.xos" ||
            ($0.localizedName?.lowercased().contains("zoom") == true)
        }
    }

    // Posts a keyboard event directly to the Zoom process.
    // postToPid bypasses the frontmost-app check — Zoom receives the event
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
