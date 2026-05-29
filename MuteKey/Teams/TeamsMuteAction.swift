import AppKit
import CoreGraphics

enum TeamsMuteAction {
    @MainActor
    static func toggleHand() {
        guard AXIsProcessTrusted() else { requestAccessibility(); return }
        guard let teams = findTeams() else { return }
        // Cmd+Shift+K toggles raised hand in Teams
        sendKey(0x28, flags: [.maskCommand, .maskShift], to: teams.processIdentifier)
        #if DEBUG
        print("[MuteKey] Cmd+Shift+K sent to Teams pid \(teams.processIdentifier)")
        #endif
    }

    @MainActor
    static func toggleCamera() {
        guard AXIsProcessTrusted() else { requestAccessibility(); return }
        guard let teams = findTeams() else {
            #if DEBUG
            print("[MuteKey] Teams not running")
            #endif
            return
        }
        // Cmd+Shift+O toggles camera in Teams
        sendKey(0x1F, flags: [.maskCommand, .maskShift], to: teams.processIdentifier)
        #if DEBUG
        print("[MuteKey] Cmd+Shift+O sent to Teams pid \(teams.processIdentifier)")
        #endif
    }

    @MainActor
    static func toggle() {
        guard AXIsProcessTrusted() else {
            requestAccessibility()
            return
        }

        guard let teams = findTeams() else {
            #if DEBUG
            print("[MuteKey] Teams not running")
            #endif
            return
        }

        sendCmdShiftM(to: teams.processIdentifier)
    }

    @MainActor
    static var isAccessibilityGranted: Bool { AXIsProcessTrusted() }

    @MainActor
    static var isTeamsRunning: Bool { findTeams() != nil }

    @MainActor
    static func requestAccessibility() {
        // "AXTrustedCheckOptionPrompt" is the string value of kAXTrustedCheckOptionPrompt
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Internal

    @MainActor
    static func findTeamsApp() -> NSRunningApplication? { findTeams() }

    // MARK: - Private

    @MainActor
    private static func findTeams() -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first {
            $0.bundleIdentifier == "com.microsoft.teams2" ||
            $0.bundleIdentifier == "com.microsoft.teams"
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

    private static func sendCmdShiftM(to pid: pid_t) {
        sendKey(0x2E, flags: [.maskCommand, .maskShift], to: pid)
        #if DEBUG
        print("[MuteKey] Cmd+Shift+M sent to Teams pid \(pid)")
        #endif
    }
}
