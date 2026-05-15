import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @EnvironmentObject var meetingState: MeetingState
    @EnvironmentObject var teamsConnector: TeamsConnector

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            settingsSection("Tastaturkürzel") {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "mic.slash.fill").frame(width: 16)
                        Text("Mikrofon")
                        Spacer()
                        KeyboardShortcuts.Recorder("", name: .toggleMute)
                    }
                    HStack {
                        Image(systemName: "video.fill").frame(width: 16)
                        Text("Webcam")
                        Spacer()
                        KeyboardShortcuts.Recorder("", name: .toggleCamera)
                    }
                }
            }

            settingsSection("Berechtigungen") {
                HStack(spacing: 8) {
                    Circle()
                        .fill(TeamsMuteAction.isAccessibilityGranted ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(TeamsMuteAction.isAccessibilityGranted
                         ? "Bedienungshilfen: Erlaubt"
                         : "Bedienungshilfen: Nicht erlaubt")
                    if !TeamsMuteAction.isAccessibilityGranted {
                        Spacer()
                        Button("Erlauben") {
                            TeamsMuteAction.requestAccessibility()
                        }
                        .controlSize(.small)
                    }
                }
            }

            settingsSection("Verbindungen") {
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
                            Button("Zurücksetzen") {
                                teamsConnector.clearToken()
                            }
                            .foregroundStyle(.red)
                            .controlSize(.small)
                        }
                        if !teamsConnector.hasToken {
                            Text("Einmaliges Setup: Teams → Einstellungen → Datenschutz → \"Third-party app API\" aktivieren. Beim nächsten Meeting-Start verbindet ZackMute automatisch.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Divider()

                    Text("Hinweis: Sind Slack-Huddle und Teams-Meeting gleichzeitig aktiv, können Shortcuts unerwartet reagieren.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(20)
        .frame(width: 400)
    }

    // MARK: - Status helpers

    private var slackStatusColor: Color {
        if !meetingState.isSlackRunning { return .secondary }
        return .green
    }

    private var slackStatusText: String {
        if !meetingState.isSlackRunning { return "Nicht gestartet" }
        return meetingState.isInSlackHuddle ? "Huddle aktiv" : "Verbunden"
    }

    private var teamsStatusColor: Color {
        if !meetingState.isTeamsRunning { return .secondary }
        if !meetingState.isConnectedToTeams { return .orange }
        return .green
    }

    private var teamsStatusText: String {
        if !meetingState.isTeamsRunning { return "Nicht gestartet" }
        if !meetingState.isConnectedToTeams { return "Nicht verbunden" }
        return meetingState.isInMeeting ? "In Meeting" : "Verbunden"
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
