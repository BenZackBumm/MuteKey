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

    init(meetingState: MeetingState, teamsConnector: TeamsConnector) {
        self.meetingState = meetingState
        self.teamsConnector = teamsConnector
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupMenu()
        observeState()
        updateIcon()
        updateMenuItems()
    }

    private func setupMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        // Status line (plain NSMenuItem, non-selectable)
        let statusItem = NSMenuItem(title: "–", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        self.statusMenuItem = statusItem

        menu.addItem(.separator())

        let muteItem = NSMenuItem(
            title: "Stummschalten",
            action: #selector(toggleMute),
            keyEquivalent: ""
        )
        muteItem.target = self
        muteItem.image = menuIcon("mic.slash.fill")
        menu.addItem(muteItem)
        self.muteMenuItem = muteItem

        let cameraItem = NSMenuItem(
            title: "Webcam aus",
            action: #selector(toggleCamera),
            keyEquivalent: ""
        )
        cameraItem.target = self
        cameraItem.image = menuIcon("video.fill")
        menu.addItem(cameraItem)
        self.cameraMenuItem = cameraItem

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Einstellungen…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(
            title: "ZackMute beenden",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        // Accessibility warning — shown only when permission is missing
        let axItem = NSMenuItem(
            title: "⚠️ Bedienungshilfen erlauben…",
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
        statusMenuItem?.title = meetingState.statusDescription

        // Show accessibility warning only when permission is missing
        accessibilityMenuItem?.isHidden = AXIsProcessTrusted()

        let teamsRunning = TeamsMuteAction.isTeamsRunning

        muteMenuItem?.isEnabled = teamsRunning
        if meetingState.isMuted {
            muteMenuItem?.title = "Mikrofon einschalten"
            muteMenuItem?.image = menuIcon("mic.fill")
        } else {
            muteMenuItem?.title = "Mikrofon stumm"
            muteMenuItem?.image = menuIcon("mic.slash.fill")
        }
        applyShortcut(.toggleMute, to: muteMenuItem)

        cameraMenuItem?.isEnabled = teamsRunning
        if meetingState.isCameraOn {
            cameraMenuItem?.title = "Webcam aus"
            cameraMenuItem?.image = menuIcon("video.slash.fill")
        } else {
            cameraMenuItem?.title = "Webcam an"
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

        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)

        let isInCall = meetingState.isInMeeting || meetingState.isInSlackHuddle
        let isMuted  = (meetingState.isInMeeting && meetingState.isMuted)
                    || (meetingState.isInSlackHuddle && meetingState.isSlackMuted)
        let isCameraOn = (meetingState.isInMeeting && meetingState.isCameraOn)
                      || (meetingState.isInSlackHuddle && meetingState.isSlackCameraOn)

        let micName = isMuted    ? "mic.slash.fill" : "mic.fill"
        let camName = isCameraOn ? "video.fill"      : "video.slash.fill"

        guard let micBase = NSImage(systemSymbolName: micName, accessibilityDescription: nil)?
                  .withSymbolConfiguration(config),
              let camBase = NSImage(systemSymbolName: camName, accessibilityDescription: nil)?
                  .withSymbolConfiguration(config)
        else { return }

        if isInCall {
            let micImg = tinted(micBase, with: isMuted    ? .systemRed   : .systemGreen)
            let camImg = tinted(camBase, with: isCameraOn ? .systemGreen : .systemRed)
            button.image = composed(micImg, camImg, isTemplate: false)
        } else {
            button.image = composed(micBase, camBase, isTemplate: true)
        }

        button.toolTip = meetingState.statusDescription
    }

    private func composed(_ left: NSImage, _ right: NSImage, isTemplate: Bool) -> NSImage {
        let spacing: CGFloat = 4
        let width  = left.size.width + spacing + right.size.width
        let height = max(left.size.height, right.size.height)
        let result = NSImage(size: CGSize(width: width, height: height), flipped: false) { _ in
            left.draw(in: CGRect(x: 0,
                                 y: (height - left.size.height) / 2,
                                 width: left.size.width,
                                 height: left.size.height))
            right.draw(in: CGRect(x: left.size.width + spacing,
                                  y: (height - right.size.height) / 2,
                                  width: right.size.width,
                                  height: right.size.height))
            return true
        }
        result.isTemplate = isTemplate
        return result
    }

    private func tinted(_ image: NSImage, with color: NSColor) -> NSImage {
        let copy = NSImage(size: image.size, flipped: false) { rect in
            image.draw(in: rect)
            color.setFill()
            rect.fill(using: .sourceAtop)
            return true
        }
        copy.isTemplate = false
        return copy
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
            teamsConnector: teamsConnector
        )
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
