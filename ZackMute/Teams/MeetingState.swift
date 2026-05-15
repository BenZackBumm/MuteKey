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

    @Published var isTeamsRunning = false
    @Published var isSlackRunning = false

    var statusDescription: String {
        let inTeams = isInMeeting
        let inSlack = isInSlackHuddle
        if inTeams && inSlack { return "In Meeting & Huddle" }
        if inSlack { return "In Huddle (Slack)" }
        if inTeams { return isMuted ? "Stummgeschaltet" : "Mikrofon aktiv" }
        return "Kein aktives Meeting"
    }
}
