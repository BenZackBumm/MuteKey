import AppKit
import Combine

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
        cameraItem.image = menuIcon("video")
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

        cameraMenuItem?.isEnabled = teamsRunning
        if meetingState.isCameraOn {
            cameraMenuItem?.title = "Webcam aus"
            cameraMenuItem?.image = menuIcon("video.slash")
        } else {
            cameraMenuItem?.title = "Webcam an"
            cameraMenuItem?.image = menuIcon("video")
        }
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

        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let inMeeting = meetingState.isInMeeting

        if inMeeting {
            let imageName = meetingState.isMuted ? "mic.slash.fill" : "mic.fill"
            let color: NSColor = meetingState.isMuted ? .systemRed : .systemGreen
            if let image = NSImage(systemSymbolName: imageName, accessibilityDescription: nil)?
                .withSymbolConfiguration(config) {
                button.image = tinted(image, with: color)
            }
        } else {
            // Template image: macOS renders it in the standard menu bar color automatically
            if let image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(config) {
                image.isTemplate = true
                button.image = image
            }
        }
        button.toolTip = meetingState.statusDescription
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
