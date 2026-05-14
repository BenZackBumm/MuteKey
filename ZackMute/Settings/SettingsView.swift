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
                        Image(systemName: "video.slash").frame(width: 16)
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

            settingsSection("Microsoft Teams") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(meetingState.isConnectedToTeams ? Color.green : Color.secondary)
                            .frame(width: 8, height: 8)
                        Text(meetingState.isConnectedToTeams ? "Verbunden" : "Nicht verbunden")
                    }

                    if !teamsConnector.hasToken {
                        Text("Einmaliges Setup: Teams → Einstellungen → Datenschutz → \"Third-party app API\" aktivieren. Beim nächsten Meeting-Start verbindet ZackMute automatisch.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if teamsConnector.hasToken {
                        Button("Verbindung zurücksetzen") {
                            teamsConnector.clearToken()
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 400)
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
