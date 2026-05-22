import Foundation

@MainActor
final class MeetingState: ObservableObject {
    @Published var isConnectedToTeams = false
    @Published var isInMeeting = false
    @Published var isMuted = false
    @Published var isCameraOn = false
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
        case 0: return "Kein aktives Meeting"
        case 1:
            if isInMeeting    { return "Aktives Meeting: Teams" }
            if isInSlackHuddle { return "Aktives Meeting: Slack" }
            if isInZoomMeeting { return "Aktives Meeting: Zoom" }
            return "Kein aktives Meeting"
        default: return "Mehrere aktive Meetings"
        }
    }
}
