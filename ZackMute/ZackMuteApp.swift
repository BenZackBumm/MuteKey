import AppKit
import KeyboardShortcuts
import UserNotifications

// Entry point is main.swift — no @main / SwiftUI App protocol.
// This avoids SwiftUI scene management conflicts in LSUIElement menu bar apps.

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    let meetingState = MeetingState()
    let teamsConnector: TeamsConnector
    private var menuBarController: MenuBarController?
    private var statePoller: TeamsStatePoller?
    private var slackPoller: SlackStatePoller?
    private var zoomPoller: ZoomStatePoller?

    override init() {
        teamsConnector = TeamsConnector(state: meetingState)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }

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
        zoomPoller = ZoomStatePoller(state: meetingState)
        zoomPoller?.start()

        // Delay ensures the run loop is fully active before showing a window
        // — required for LSUIElement apps that have no window context at launch.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            WizardWindowController.showIfNeeded()
        }
    }
}
