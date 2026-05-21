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

    var statusDescription: String {
        let inTeams = isInMeeting
        let inSlack = isInSlackHuddle
        let inZoom  = isInZoomMeeting
        if inTeams && inSlack && inZoom { return "Teams, Slack & Zoom aktiv" }
        if inTeams && inZoom  { return "Teams & Zoom aktiv" }
        if inSlack && inZoom  { return "Slack Huddle & Zoom aktiv" }
        if inTeams && inSlack { return "In Meeting & Huddle" }
        if inZoom  { return isZoomMuted ? "Stummgeschaltet" : "Mikrofon aktiv" }
        if inSlack { return "In Huddle (Slack)" }
        if inTeams { return isMuted ? "Stummgeschaltet" : "Mikrofon aktiv" }
        return "Kein aktives Meeting"
    }
}
