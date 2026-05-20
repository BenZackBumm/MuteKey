import AppKit

enum SlackMuteAction {
    @MainActor
    static func toggle() {
        guard AXIsProcessTrusted() else { TeamsMuteAction.requestAccessibility(); return }
        guard let slack = findSlack() else { print("[ZackMute] Slack not running"); return }
        let pid = slack.processIdentifier
        if !clickHuddleButton(matching: ["stumm", "mute", "mikrofon"], in: pid) {
            // Fallback: M key posted directly to Slack's PID
            print("[ZackMute] Slack mute: AX failed — trying M key injection")
            sendKey(0x2E, flags: [], to: pid)
        }
    }

    @MainActor
    static func toggleCamera() {
        guard AXIsProcessTrusted() else { TeamsMuteAction.requestAccessibility(); return }
        guard let slack = findSlack() else { print("[ZackMute] Slack not running"); return }
        let pid = slack.processIdentifier
        if !clickHuddleButton(matching: ["kamera", "video", "webcam"], in: pid) {
            // Fallback: V key posted directly to Slack's PID
            print("[ZackMute] Slack camera: AX failed — trying V key injection")
            sendKey(0x09, flags: [], to: pid)
        }
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

    // The mute/camera buttons live deep in the Electron/BrowserAccessibility tree
    // inside the "Huddle:…" window.
    private static func clickHuddleButton(matching keywords: [String], in pid: pid_t) -> Bool {
        let axApp = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else { return false }

        // Prefer the window whose title starts with "Huddle:"
        let huddleWindows = windows.filter { windowTitle($0).lowercased().contains("huddle") }
        let searchTargets = huddleWindows.isEmpty ? windows : huddleWindows

        for window in searchTargets {
            if let button = findButton(matching: keywords, in: window, depth: 0) {
                // 1. Try AX press action first — no cursor movement, no focus change
                if AXUIElementPerformAction(button, kAXPressAction as CFString) == .success {
                    print("[ZackMute] Slack button clicked via AXPress")
                    return true
                }
                // 2. Fall back to mouse click, but only if the coordinates are
                //    actually inside a Slack window (guards against clicking Teams)
                if clickElement(button, validateWithin: pid) {
                    return true
                }
            }
        }
        return false
    }

    // Reads the AX position/size of the element and simulates a mouse click.
    // Includes a bounds check: aborts if the center is not within the app's own windows,
    // which prevents accidentally clicking another app that overlaps Slack's UI.
    private static func clickElement(_ element: AXUIElement, validateWithin pid: pid_t) -> Bool {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posVal = posRef, let sizeVal = sizeRef,
              CFGetTypeID(posVal) == AXValueGetTypeID(),
              CFGetTypeID(sizeVal) == AXValueGetTypeID()
        else { return false }

        var origin = CGPoint.zero
        var size   = CGSize.zero
        AXValueGetValue(posVal as! AXValue, .cgPoint, &origin)
        AXValueGetValue(sizeVal as! AXValue, .cgSize, &size)

        let center = CGPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2)

        // Safety check: the button must be within one of the app's own windows.
        // If it's not (e.g. wrong AX position, or element from a hidden layer),
        // skip the mouse click to avoid accidentally activating another app.
        guard isPoint(center, withinWindowsOf: pid) else {
            print("[ZackMute] Slack button center \(center) is outside Slack windows — skipping mouse click")
            return false
        }

        guard let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,    mouseCursorPosition: center, mouseButton: .left),
              let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: center, mouseButton: .left),
              let up   = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,   mouseCursorPosition: center, mouseButton: .left)
        else { return false }

        // mouseMoved triggers Electron's hover/focus state before the actual click
        move.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.05)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }

    // Returns true if `point` (in AX/screen coordinates) lies inside any window of the given app.
    private static func isPoint(_ point: CGPoint, withinWindowsOf pid: pid_t) -> Bool {
        let axApp = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else { return false }

        for window in windows {
            var wPosRef: CFTypeRef?, wSizeRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &wPosRef) == .success,
                  AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &wSizeRef) == .success,
                  let wp = wPosRef, let ws = wSizeRef,
                  CFGetTypeID(wp) == AXValueGetTypeID(),
                  CFGetTypeID(ws) == AXValueGetTypeID()
            else { continue }

            var wOrigin = CGPoint.zero, wSize = CGSize.zero
            AXValueGetValue(wp as! AXValue, .cgPoint, &wOrigin)
            AXValueGetValue(ws as! AXValue, .cgSize, &wSize)
            if CGRect(origin: wOrigin, size: wSize).contains(point) {
                return true
            }
        }
        return false
    }

    // Posts a keyboard event directly to the app's PID (no focus change needed).
    private static func sendKey(_ keyCode: CGKeyCode, flags: CGEventFlags = [], to pid: pid_t) {
        let src = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true),
              let up   = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        else { return }
        down.flags = flags
        up.flags   = flags
        down.postToPid(pid)
        up.postToPid(pid)
    }

    private static func windowTitle(_ window: AXUIElement) -> String {
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &ref)
        return ref as? String ?? ""
    }

    private static func findButton(matching keywords: [String], in element: AXUIElement, depth: Int) -> AXUIElement? {
        guard depth < 25 else { return nil }

        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        if let role = roleRef as? String, role == kAXButtonRole as String {
            for attr in [kAXDescriptionAttribute, kAXTitleAttribute, kAXHelpAttribute] {
                var valueRef: CFTypeRef?
                AXUIElementCopyAttributeValue(element, attr as CFString, &valueRef)
                if let text = valueRef as? String {
                    let lower = text.lowercased()
                    if keywords.contains(where: { lower.contains($0) }) {
                        return element
                    }
                }
            }
        }

        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else { return nil }
        for child in children {
            if let found = findButton(matching: keywords, in: child, depth: depth + 1) {
                return found
            }
        }
        return nil
    }
}
