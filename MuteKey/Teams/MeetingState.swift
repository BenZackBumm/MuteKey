import Foundation

@MainActor
final class MeetingState: ObservableObject {
    @Published var isConnectedToTeams = false
    @Published var isInMeeting = false
    @Published var isMuted = false
    @Published var isCameraOn = false
    @Published var isHandRaised = false
    @Published var canToggleMute = false
    @Published var canToggleVideo = false

    @Published var isInSlackHuddle = false
    @Published var isSlackMuted = false
    @Published var isSlackCameraOn = false

    @Published var isInZoomMeeting = false
    @Published var isZoomMuted = false
    @Published var isZoomCameraOn = false

    @Published var isTeamsRunning = false
    @Published var isSlackRunning = false
    @Published var isZoomRunning = false

    var activeCallCount: Int {
        (isInMeeting ? 1 : 0) + (isInSlackHuddle ? 1 : 0) + (isInZoomMeeting ? 1 : 0)
    }

    var statusDescription: String {
        switch activeCallCount {
        case 0: return String(localized: "status.no_meeting")
        case 1:
            if isInMeeting     { return String(localized: "status.active_meeting.teams") }
            if isInSlackHuddle { return String(localized: "status.active_meeting.slack") }
            if isInZoomMeeting { return String(localized: "status.active_meeting.zoom") }
            return String(localized: "status.no_meeting")
        default: return String(localized: "status.multiple_meetings")
        }
    }
}
