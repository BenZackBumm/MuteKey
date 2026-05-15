import AppKit

enum SlackMuteAction {
    @MainActor
    static func toggle() {
        guard AXIsProcessTrusted() else { TeamsMuteAction.requestAccessibility(); return }
        guard let slack = findSlack() else { print("[ZackMute] Slack not running"); return }
        if !clickHuddleButton(matching: ["stumm", "mute", "mikrofon"], in: slack.processIdentifier) {
            print("[ZackMute] Slack mute button not found via AX")
        }
    }

    @MainActor
    static func toggleCamera() {
        guard AXIsProcessTrusted() else { TeamsMuteAction.requestAccessibility(); return }
        guard let slack = findSlack() else { print("[ZackMute] Slack not running"); return }
        if !clickHuddleButton(matching: ["kamera"], in: slack.processIdentifier) {
            print("[ZackMute] Slack camera button not found via AX")
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

    // The mute button is labeled "Mikrofon auf stumm stellen" and lives ~12 levels deep
    // in the Electron/BrowserAccessibility tree inside the "Huddle:…" window.
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
                if clickElement(button) {
                    return true
                }
            }
        }
        return false
    }

    // Read the AX position/size of the element and simulate a real mouse click.
    // kAXPressAction is ignored by Electron BrowserAccessibilityCocoa elements.
    private static func clickElement(_ element: AXUIElement) -> Bool {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posVal = posRef, let sizeVal = sizeRef,
              CFGetTypeID(posVal) == AXValueGetTypeID(),
              CFGetTypeID(sizeVal) == AXValueGetTypeID()
        else { return false }

        var origin = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posVal as! AXValue, .cgPoint, &origin)
        AXValueGetValue(sizeVal as! AXValue, .cgSize, &size)

        let center = CGPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2)

        guard let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: center, mouseButton: .left),
              let up   = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,   mouseCursorPosition: center, mouseButton: .left)
        else { return false }

        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
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
