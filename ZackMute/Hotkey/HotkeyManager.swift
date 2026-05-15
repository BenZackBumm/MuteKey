import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleMute   = Self("toggleMute",   default: .init(.f19))
    static let toggleCamera = Self("toggleCamera", default: .init(.f16))
}

enum HotkeyManager {
    static func setup(teamsConnector: TeamsConnector, meetingState: MeetingState) {
        KeyboardShortcuts.onKeyDown(for: .toggleMute) {
            Task { @MainActor in
                if meetingState.isInSlackHuddle {
                    SlackMuteAction.toggle()
                    meetingState.isSlackMuted.toggle()
                }
                if meetingState.isInMeeting {
                    teamsConnector.toggleMute()
                }
            }
        }
        KeyboardShortcuts.onKeyDown(for: .toggleCamera) {
            Task { @MainActor in
                if meetingState.isInSlackHuddle {
                    SlackMuteAction.toggleCamera()
                    meetingState.isSlackCameraOn.toggle()
                }
                if meetingState.isInMeeting {
                    teamsConnector.toggleCamera()
                }
            }
        }
    }
}
