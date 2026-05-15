import AppKit
import KeyboardShortcuts

// Entry point is main.swift — no @main / SwiftUI App protocol.
// This avoids SwiftUI scene management conflicts in LSUIElement menu bar apps.

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    let meetingState = MeetingState()
    let teamsConnector: TeamsConnector
    private var menuBarController: MenuBarController?
    private var statePoller: TeamsStatePoller?
    private var slackPoller: SlackStatePoller?

    override init() {
        teamsConnector = TeamsConnector(state: meetingState)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController(
            meetingState: meetingState,
            teamsConnector: teamsConnector
        )
        HotkeyManager.setup(teamsConnector: teamsConnector, meetingState: meetingState)
        teamsConnector.connect()
        statePoller = TeamsStatePoller(state: meetingState)
        statePoller?.start()
        slackPoller = SlackStatePoller(state: meetingState)
        slackPoller?.start()
    }
}
