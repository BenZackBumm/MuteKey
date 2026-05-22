import SwiftUI
import KeyboardShortcuts
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var meetingState: MeetingState
    @EnvironmentObject var teamsConnector: TeamsConnector

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            settingsSection(String(localized: "settings.section.general")) {
                HStack {
                    Text("settings.launch_at_login")
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { SMAppService.mainApp.status == .enabled },
                        set: { setLaunchAtLogin($0) }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
                }
            }

            settingsSection(String(localized: "settings.section.shortcuts")) {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "mic.slash.fill").frame(width: 16)
                        Text("settings.shortcut.mic")
                        Spacer()
                        KeyboardShortcuts.Recorder("", name: .toggleMute)
                    }
                    HStack {
                        Image(systemName: "video.fill").frame(width: 16)
                        Text("settings.shortcut.camera")
                        Spacer()
                        KeyboardShortcuts.Recorder("", name: .toggleCamera)
                    }
                }
            }

            settingsSection(String(localized: "settings.section.permissions")) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(TeamsMuteAction.isAccessibilityGranted ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(TeamsMuteAction.isAccessibilityGranted
                         ? String(localized: "settings.accessibility.granted")
                         : String(localized: "settings.accessibility.denied"))
                    Spacer()
                    if !TeamsMuteAction.isAccessibilityGranted {
                        Button(String(localized: "settings.accessibility.grant_button")) {
                            TeamsMuteAction.requestAccessibility()
                        }
                        .controlSize(.small)
                    }
                }
            }

            settingsSection(String(localized: "settings.section.connections")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(slackStatusColor)
                            .frame(width: 8, height: 8)
                        Text("Slack")
                            .fontWeight(.medium)
                        Spacer()
                        Text(slackStatusText)
                            .foregroundStyle(slackStatusColor == .secondary ? AnyShapeStyle(.secondary) : AnyShapeStyle(slackStatusColor))
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(teamsStatusColor)
                                .frame(width: 8, height: 8)
                            Text("Microsoft Teams")
                                .fontWeight(.medium)
                            Spacer()
                            Text(teamsStatusText)
                                .foregroundStyle(teamsStatusColor == .secondary ? AnyShapeStyle(.secondary) : AnyShapeStyle(teamsStatusColor))
                        }
                        if teamsConnector.hasToken {
                            Button(String(localized: "settings.teams.reset_button")) {
                                teamsConnector.clearToken()
                            }
                            .foregroundStyle(.red)
                            .controlSize(.small)
                        }
                        if !teamsConnector.hasToken {
                            Text("settings.teams.setup_hint")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Divider()

                    HStack(spacing: 8) {
                        Circle()
                            .fill(zoomStatusColor)
                            .frame(width: 8, height: 8)
                        Text("Zoom")
                            .fontWeight(.medium)
                        Spacer()
                        Text(zoomStatusText)
                            .foregroundStyle(zoomStatusColor == .secondary ? AnyShapeStyle(.secondary) : AnyShapeStyle(zoomStatusColor))
                    }

                    Divider()

                    Text("settings.connections.multiple_calls_hint")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(20)
        .frame(width: 400)
    }

    // MARK: - Launch at Login

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[ZackMute] Launch at login error: \(error)")
        }
    }

    // MARK: - Status helpers

    private var slackStatusColor: Color {
        if !meetingState.isSlackRunning { return .secondary }
        return .green
    }

    private var slackStatusText: String {
        if !meetingState.isSlackRunning { return String(localized: "status.not_running") }
        return meetingState.isInSlackHuddle ? String(localized: "status.slack.huddle_active") : String(localized: "status.connected")
    }

    private var zoomStatusColor: Color {
        if !meetingState.isZoomRunning { return .secondary }
        return .green
    }

    private var zoomStatusText: String {
        if !meetingState.isZoomRunning { return String(localized: "status.not_running") }
        return meetingState.isInZoomMeeting ? String(localized: "status.in_meeting") : String(localized: "status.connected")
    }

    private var teamsStatusColor: Color {
        if !meetingState.isTeamsRunning { return .secondary }
        if !meetingState.isConnectedToTeams { return .orange }
        return .green
    }

    private var teamsStatusText: String {
        if !meetingState.isTeamsRunning { return String(localized: "status.not_running") }
        if !meetingState.isConnectedToTeams { return String(localized: "status.not_connected") }
        return meetingState.isInMeeting ? String(localized: "status.in_meeting") : String(localized: "status.connected")
    }

    @ViewBuilder
    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
