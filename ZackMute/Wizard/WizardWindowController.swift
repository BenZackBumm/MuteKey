import AppKit
import SwiftUI

@MainActor
final class WizardWindowController: NSWindowController, NSWindowDelegate {
    private static var shared: WizardWindowController?

    static func showIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: "wizardCompleted") else { return }
        if shared == nil {
            shared = WizardWindowController()
        }
        NSApp.activate(ignoringOtherApps: true)
        shared?.window?.orderFrontRegardless()
    }

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "ZackMute"
        window.contentView = NSHostingView(rootView: WizardView())
        window.center()

        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) { nil }

    static func markCompleted() {
        UserDefaults.standard.set(true, forKey: "wizardCompleted")
    }

    func windowWillClose(_ notification: Notification) {
        Self.shared = nil
    }
}
