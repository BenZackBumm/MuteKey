import AppKit
import Combine
import KeyboardShortcuts

@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem
    private let meetingState: MeetingState
    private let teamsConnector: TeamsConnector
    private var cancellables = Set<AnyCancellable>()
    private var statusMenuItem: NSMenuItem?
    private var muteMenuItem: NSMenuItem?
    private var cameraMenuItem: NSMenuItem?
    private var accessibilityMenuItem: NSMenuItem?

    private let updateController: UpdateController

    init(meetingState: MeetingState, teamsConnector: TeamsConnector, updateController: UpdateController) {
        self.meetingState = meetingState
        self.teamsConnector = teamsConnector
        self.updateController = updateController
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupMenu()
        observeState()
        updateIcon()
        updateMenuItems()
    }

    private func setupMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        // Status line — clickable when multiple calls are active
        let statusItem = NSMenuItem(title: "–", action: #selector(showMultipleCallsInfo), keyEquivalent: "")
        statusItem.target = self
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        self.statusMenuItem = statusItem

        menu.addItem(.separator())

        let muteItem = NSMenuItem(
            title: String(localized: "menu.mute"),
            action: #selector(toggleMute),
            keyEquivalent: ""
        )
        muteItem.target = self
        muteItem.image = menuIcon("mic.slash.fill")
        menu.addItem(muteItem)
        self.muteMenuItem = muteItem

        let cameraItem = NSMenuItem(
            title: String(localized: "menu.camera.off"),
            action: #selector(toggleCamera),
            keyEquivalent: ""
        )
        cameraItem.target = self
        cameraItem.image = menuIcon("video.fill")
        menu.addItem(cameraItem)
        self.cameraMenuItem = cameraItem

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: String(localized: "menu.settings"),
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(
            title: String(localized: "menu.quit"),
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        // Accessibility warning — shown only when permission is missing
        let axItem = NSMenuItem(
            title: String(localized: "menu.accessibility.request"),
            action: #selector(requestAccessibility),
            keyEquivalent: ""
        )
        axItem.target = self
        menu.addItem(.separator())
        menu.addItem(axItem)
        self.accessibilityMenuItem = axItem

        self.statusItem.menu = menu
    }

    private func observeState() {
        meetingState.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.updateAll() }
            }
            .store(in: &cancellables)
    }

    private func updateAll() {
        updateIcon()
        updateMenuItems()
    }

    private func updateMenuItems() {
        let multipleCalls = meetingState.activeCallCount >= 2
        statusMenuItem?.title = multipleCalls
            ? String(localized: "menu.status.multiple_calls")
            : meetingState.statusDescription
        statusMenuItem?.isEnabled = multipleCalls

        // Show accessibility warning only when permission is missing
        accessibilityMenuItem?.isHidden = AXIsProcessTrusted()

        let teamsRunning = TeamsMuteAction.isTeamsRunning

        muteMenuItem?.isEnabled = teamsRunning
        if meetingState.isMuted {
            muteMenuItem?.title = String(localized: "menu.mic.unmute")
            muteMenuItem?.image = menuIcon("mic.fill")
        } else {
            muteMenuItem?.title = String(localized: "menu.mic.mute")
            muteMenuItem?.image = menuIcon("mic.slash.fill")
        }
        applyShortcut(.toggleMute, to: muteMenuItem)

        cameraMenuItem?.isEnabled = teamsRunning
        if meetingState.isCameraOn {
            cameraMenuItem?.title = String(localized: "menu.camera.off")
            cameraMenuItem?.image = menuIcon("video.slash.fill")
        } else {
            cameraMenuItem?.title = String(localized: "menu.camera.on")
            cameraMenuItem?.image = menuIcon("video.fill")
        }
        applyShortcut(.toggleCamera, to: cameraMenuItem)
    }

    private func applyShortcut(_ name: KeyboardShortcuts.Name, to item: NSMenuItem?) {
        guard let item else { return }
        guard let shortcut = KeyboardShortcuts.getShortcut(for: name) else {
            item.keyEquivalent = ""
            item.keyEquivalentModifierMask = []
            return
        }
        if let char = functionKeyChar(for: shortcut.key) {
            item.keyEquivalent = char
            item.keyEquivalentModifierMask = shortcut.modifiers
        } else {
            item.keyEquivalent = ""
            item.keyEquivalentModifierMask = []
        }
    }

    // Maps CGKeyCode of F-keys to the NSMenuItem unicode characters (NSFxxFunctionKey).
    private func functionKeyChar(for key: KeyboardShortcuts.Key?) -> String? {
        guard let key else { return nil }
        // CGKeyCodes for F1–F20 mapped to unicode private-use scalars 0xF704–0xF717
        let table: [CGKeyCode: UInt32] = [
            CGKeyCode(122): 0xF704, CGKeyCode(120): 0xF705, CGKeyCode(99): 0xF706, CGKeyCode(118): 0xF707,
            CGKeyCode(96):  0xF708, CGKeyCode(97):  0xF709, CGKeyCode(98): 0xF70A, CGKeyCode(100): 0xF70B,
            CGKeyCode(101): 0xF70C, CGKeyCode(109): 0xF70D, CGKeyCode(103): 0xF70E, CGKeyCode(111): 0xF70F,
            CGKeyCode(105): 0xF710, CGKeyCode(107): 0xF711, CGKeyCode(113): 0xF712, CGKeyCode(106): 0xF713,
            CGKeyCode(64):  0xF714, CGKeyCode(79):  0xF715, CGKeyCode(80):  0xF716, CGKeyCode(90):  0xF717,
        ]
        guard let scalar = table[CGKeyCode(key.rawValue)],
              let unicodeScalar = Unicode.Scalar(scalar) else { return nil }
        return String(unicodeScalar)
    }

    private func menuIcon(_ symbolName: String) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        return image
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        guard let apeBase = NSImage(named: "ape_menubar") else { return }

        let isInCall       = meetingState.isInMeeting || meetingState.isInSlackHuddle || meetingState.isInZoomMeeting
        let multipleActive = meetingState.isInSlackHuddle || meetingState.isInZoomMeeting
        // Colored pill pair: Enterprise Teams solo, or Zoom solo
        let hasTeamsStatus = meetingState.isInMeeting && meetingState.canToggleMute && !multipleActive
        let hasZoomStatus  = meetingState.isInZoomMeeting && !meetingState.isInMeeting && !meetingState.isInSlackHuddle

        if hasTeamsStatus {
            // Enterprise Teams: real mic/camera status via WebSocket
            let isMuted    = meetingState.isMuted
            let isCameraOn = meetingState.isCameraOn
            button.image = pillPair(
                leftSymbol:  isMuted    ? "mic.slash.fill" : "mic.fill",
                leftColor:   isMuted    ? .systemRed       : .systemGreen,
                rightSymbol: isCameraOn ? "video.fill"     : "video.slash.fill",
                rightColor:  isCameraOn ? .systemGreen     : .systemRed
            )
        } else if hasZoomStatus {
            // Zoom solo: real mic/camera status via AX-Tree
            let isMuted    = meetingState.isZoomMuted
            let isCameraOn = meetingState.isZoomCameraOn
            button.image = pillPair(
                leftSymbol:  isMuted    ? "mic.slash.fill" : "mic.fill",
                leftColor:   isMuted    ? .systemRed       : .systemGreen,
                rightSymbol: isCameraOn ? "video.fill"     : "video.slash.fill",
                rightColor:  isCameraOn ? .systemGreen     : .systemRed
            )
        } else if isInCall {
            // Multiple calls, Slack, or Personal Teams: status unknown → blue pill
            button.image = activeCallIcon(apeBase: apeBase)
        } else {
            // Idle: single template icon — auto-adapts to Dark/Light Mode
            let idle = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
                apeBase.draw(in: rect)
                return true
            }
            idle.isTemplate = true
            button.image = idle
        }

        button.toolTip = meetingState.statusDescription
    }

    /// Blue pill with the ape icon centered — used when in a call but real mic/camera status is unavailable.
    private func activeCallIcon(apeBase: NSImage) -> NSImage {
        let pillHeight: CGFloat  = 24
        let iconSize: CGFloat    = 15
        let hPad: CGFloat        = 11      // horizontal padding on each side
        let cornerRadius         = pillHeight / 2
        let totalW               = iconSize + hPad * 2

        let apeImg = tinted(apeBase, with: .white, size: NSSize(width: iconSize, height: iconSize))

        let result = NSImage(size: NSSize(width: totalW, height: pillHeight), flipped: false) { _ in
            NSColor.systemBlue.setFill()
            NSBezierPath(roundedRect: CGRect(x: 0, y: 0, width: totalW, height: pillHeight),
                         xRadius: cornerRadius, yRadius: cornerRadius).fill()

            let x = (totalW  - apeImg.size.width)  / 2
            let y = (pillHeight - apeImg.size.height) / 2
            apeImg.draw(in: CGRect(x: x, y: y, width: apeImg.size.width, height: apeImg.size.height))
            return true
        }
        result.isTemplate = false
        return result
    }

    private func tinted(_ image: NSImage, with color: NSColor, size: NSSize? = nil) -> NSImage {
        let targetSize = size ?? image.size
        let copy = NSImage(size: targetSize, flipped: false) { rect in
            image.draw(in: rect)
            color.setFill()
            rect.fill(using: .sourceAtop)
            return true
        }
        copy.isTemplate = false
        return copy
    }

    // MARK: - Pill icon rendering

    /// One connected shape, left half and right half each with a different color.
    /// Only the outer corners are rounded — inner edges are straight where the halves meet.
    private func pillPair(leftSymbol: String, leftColor: NSColor,
                          rightSymbol: String, rightColor: NSColor) -> NSImage {
        let pillHeight: CGFloat    = 24
        let outerPad: CGFloat      = 8      // container to outer edge
        let innerPad: CGFloat      = 5      // container to center → gap between containers = 10px
        let containerSize: CGFloat = 13     // fixed square bounding box for each icon
        let iconPt: CGFloat        = 13
        let cornerRadius           = pillHeight / 2

        // halfW = outerPad + container + innerPad = 8 + 13 + 5 = 26
        let halfW  = outerPad + containerSize + innerPad
        let totalW = halfW * 2

        let symConfig = NSImage.SymbolConfiguration(pointSize: iconPt, weight: .semibold)

        guard let leftSym  = NSImage(systemSymbolName: leftSymbol,  accessibilityDescription: nil)?.withSymbolConfiguration(symConfig),
              let rightSym = NSImage(systemSymbolName: rightSymbol, accessibilityDescription: nil)?.withSymbolConfiguration(symConfig)
        else { return NSImage() }

        let containerY = (pillHeight - containerSize) / 2

        let result = NSImage(size: NSSize(width: totalW, height: pillHeight), flipped: false) { _ in
            let fullRect = CGRect(x: 0, y: 0, width: totalW, height: pillHeight)
            let fullPath = NSBezierPath(roundedRect: fullRect, xRadius: cornerRadius, yRadius: cornerRadius)

            // Left half
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(rect: CGRect(x: 0, y: 0, width: halfW, height: pillHeight)).setClip()
            leftColor.setFill()
            fullPath.fill()
            NSGraphicsContext.restoreGraphicsState()

            // Right half
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(rect: CGRect(x: halfW, y: 0, width: halfW, height: pillHeight)).setClip()
            rightColor.setFill()
            fullPath.fill()
            NSGraphicsContext.restoreGraphicsState()

            // Left icon centered in its container (8px from outer left, 5px from center)
            let leftContainer  = CGRect(x: outerPad,             y: containerY, width: containerSize, height: containerSize)
            // Right icon centered in its container (5px from center, 8px from outer right)
            let rightContainer = CGRect(x: halfW + innerPad,     y: containerY, width: containerSize, height: containerSize)

            self.drawWhiteIcon(leftSym,  inContainer: leftContainer)
            self.drawWhiteIcon(rightSym, inContainer: rightContainer)

            return true
        }
        result.isTemplate = false
        return result
    }

    /// Draws a white-tinted symbol centered within the given container rect.
    private func drawWhiteIcon(_ symbol: NSImage, inContainer container: CGRect) {
        let iconRect = CGRect(
            x: container.midX - symbol.size.width  / 2,
            y: container.midY - symbol.size.height / 2,
            width:  symbol.size.width,
            height: symbol.size.height
        )
        let white = NSImage(size: symbol.size, flipped: false) { r in
            symbol.draw(in: r)
            NSColor.white.setFill()
            r.fill(using: .sourceAtop)
            return true
        }
        white.draw(in: iconRect)
    }

    @objc private func showMultipleCallsInfo() {
        let alert = NSAlert()
        alert.messageText = String(localized: "alert.multiple_calls.title")
        alert.informativeText = String(localized: "alert.multiple_calls.message")
        alert.addButton(withTitle: String(localized: "alert.button.ok"))
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc private func toggleMute() {
        teamsConnector.toggleMute()
    }

    @objc private func toggleCamera() {
        teamsConnector.toggleCamera()
    }

    @objc private func requestAccessibility() {
        TeamsMuteAction.requestAccessibility()
    }

    @objc private func openSettings() {
        SettingsWindowController.show(
            meetingState: meetingState,
            teamsConnector: teamsConnector,
            updateController: updateController
        )
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
