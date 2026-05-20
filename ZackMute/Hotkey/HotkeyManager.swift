import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleMute   = Self("toggleMute",   default: .init(.f19))
    static let toggleCamera = Self("toggleCamera", default: .init(.f16))
}

enum HotkeyManager {
    static func setup(teamsConnector: TeamsConnector, meetingState: MeetingState) {
        KeyboardShortcuts.onKeyDown(for: .toggleMute) {
            Task { @MainActor in
                let slack  = meetingState.isInSlackHuddle
                let teams  = meetingState.isInMeeting
                let allMuted = (!slack || meetingState.isSlackMuted)
                            && (!teams || meetingState.isMuted)
                let target = !allMuted  // unmute if all muted, otherwise mute all

                if slack && meetingState.isSlackMuted != target {
                    SlackMuteAction.toggle()
                    meetingState.isSlackMuted = target
                }
                if teams && meetingState.isMuted != target {
                    teamsConnector.toggleMute()
                }
            }
        }
        KeyboardShortcuts.onKeyDown(for: .toggleCamera) {
            Task { @MainActor in
                let slack  = meetingState.isInSlackHuddle
                let teams  = meetingState.isInMeeting
                let allOff = (!slack || !meetingState.isSlackCameraOn)
                          && (!teams || !meetingState.isCameraOn)
                let target = allOff  // turn on if all off, otherwise turn all off

                if slack && meetingState.isSlackCameraOn != target {
                    SlackMuteAction.toggleCamera()
                    meetingState.isSlackCameraOn = target
                }
                if teams && meetingState.isCameraOn != target {
                    teamsConnector.toggleCamera()
                }
            }
        }
    }
}
