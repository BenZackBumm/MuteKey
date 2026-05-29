import KeyboardShortcuts
import UserNotifications

extension KeyboardShortcuts.Name {
    static let toggleMute   = Self("toggleMute",   default: .init(.f19))
    static let toggleCamera = Self("toggleCamera", default: .init(.f16))
    static let raiseHand    = Self("raiseHand",    default: .init(.f18))
}

enum HotkeyManager {
    static func setup(teamsConnector: TeamsConnector, meetingState: MeetingState) {
        KeyboardShortcuts.onKeyDown(for: .toggleMute) {
            Task { @MainActor in
                performToggleMute(teamsConnector: teamsConnector, meetingState: meetingState)
            }
        }
        KeyboardShortcuts.onKeyDown(for: .toggleCamera) {
            Task { @MainActor in
                performToggleCamera(teamsConnector: teamsConnector, meetingState: meetingState)
            }
        }
        KeyboardShortcuts.onKeyDown(for: .raiseHand) {
            Task { @MainActor in
                performRaiseHand(teamsConnector: teamsConnector, meetingState: meetingState)
            }
        }
    }

    // MARK: - Shared toggle actions (used by hotkey and menu items)

    @MainActor
    static func performToggleMute(teamsConnector: TeamsConnector, meetingState: MeetingState) {
        let slack  = meetingState.isInSlackHuddle
        let teams  = meetingState.isInMeeting
        let zoom   = meetingState.isInZoomMeeting
        let allMuted = (!slack || meetingState.isSlackMuted)
                    && (!teams || meetingState.isMuted)
                    && (!zoom  || meetingState.isZoomMuted)
        let target = !allMuted  // unmute if all muted, otherwise mute all

        if slack && meetingState.isSlackMuted != target {
            SlackMuteAction.toggle()
            meetingState.isSlackMuted = target
        }
        if teams && meetingState.isMuted != target {
            teamsConnector.toggleMute()
        }
        if zoom && meetingState.isZoomMuted != target {
            ZoomMuteAction.toggleMic()
            meetingState.isZoomMuted = target  // Optimistic — AX overrides when toolbar visible
        }
    }

    @MainActor
    static func performToggleCamera(teamsConnector: TeamsConnector, meetingState: MeetingState) {
        let slack  = meetingState.isInSlackHuddle
        let teams  = meetingState.isInMeeting
        let zoom   = meetingState.isInZoomMeeting
        let allOff = (!slack || !meetingState.isSlackCameraOn)
                  && (!teams || !meetingState.isCameraOn)
                  && (!zoom  || !meetingState.isZoomCameraOn)
        let target = allOff  // turn on if all off, otherwise turn all off

        // Slack Huddle has no camera shortcut — notify the user (only if Slack is the sole active app)
        if slack && !teams && !zoom {
            notifySlackCameraUnsupported()
            return
        }
        if teams && meetingState.isCameraOn != target {
            teamsConnector.toggleCamera()
        }
        if zoom && meetingState.isZoomCameraOn != target {
            ZoomMuteAction.toggleCamera()
            meetingState.isZoomCameraOn = target  // Optimistic — AX overrides when toolbar visible
        }
    }

    @MainActor
    static func performRaiseHand(teamsConnector: TeamsConnector, meetingState: MeetingState) {
        guard meetingState.isInMeeting else { return }
        teamsConnector.raiseHand()
    }

    private static func notifySlackCameraUnsupported() {
        Task {
            let center = UNUserNotificationCenter.current()
            guard (try? await center.requestAuthorization(options: [.alert])) == true else { return }
            let content = UNMutableNotificationContent()
            content.title = "MuteKey"
            content.body = String(localized: "notification.slack_camera_unsupported")
            let request = UNNotificationRequest(
                identifier: "slack-camera-unsupported",
                content: content,
                trigger: nil
            )
            try? await center.add(request)
        }
    }
}
