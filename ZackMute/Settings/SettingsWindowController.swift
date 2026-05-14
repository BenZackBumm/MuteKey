import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private static var shared: SettingsWindowController?

    static func show(meetingState: MeetingState, teamsConnector: TeamsConnector) {
        if shared == nil {
            shared = SettingsWindowController(meetingState: meetingState, teamsConnector: teamsConnector)
        }
        NSApp.activate(ignoringOtherApps: true)
        shared?.window?.makeKeyAndOrderFront(nil)
    }

    private init(meetingState: MeetingState, teamsConnector: TeamsConnector) {
        let rootView = SettingsView()
            .environmentObject(meetingState)
            .environmentObject(teamsConnector)

        // NSHostingView directly as contentView avoids the internal ScrollView
        // that NSHostingController wraps around its content.
        let hostingView = NSHostingView(rootView: rootView)
        let fittingSize = hostingView.fittingSize

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: fittingSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "ZackMute"
        window.contentView = hostingView
        window.center()

        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) { nil }

    func windowWillClose(_ notification: Notification) {
        Self.shared = nil
    }
}
