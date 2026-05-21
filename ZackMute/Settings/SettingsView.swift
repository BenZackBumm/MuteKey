import SwiftUI
import KeyboardShortcuts
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var meetingState: MeetingState
    @EnvironmentObject var teamsConnector: TeamsConnector

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            settingsSection("Allgemein") {
                HStack {
                    Text("Beim Login automatisch starten")
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
                    Spacer()
                    if !TeamsMuteAction.isAccessibilityGranted {
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

                    Text("Hinweis: Sind mehrere Videocalls gleichzeitig aktiv, schaltet der Kurzbefehl alle gemeinsam. Dies kann zu Fehlern führen.")
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
        if !meetingState.isSlackRunning { return "Nicht gestartet" }
        return meetingState.isInSlackHuddle ? "Huddle aktiv" : "Verbunden"
    }

    private var zoomStatusColor: Color {
        if !meetingState.isZoomRunning { return .secondary }
        return .green
    }

    private var zoomStatusText: String {
        if !meetingState.isZoomRunning { return "Nicht gestartet" }
        return meetingState.isInZoomMeeting ? "In Meeting" : "Verbunden"
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
