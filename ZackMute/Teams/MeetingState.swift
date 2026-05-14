import Foundation

@MainActor
final class MeetingState: ObservableObject {
    @Published var isConnectedToTeams = false
    @Published var isInMeeting = false
    @Published var isMuted = false
    @Published var isCameraOn = false
    @Published var canToggleMute = false
    @Published var canToggleVideo = false

    var statusDescription: String {
        guard isConnectedToTeams else { return "Teams nicht verbunden" }
        guard isInMeeting else { return "Kein aktives Meeting" }
        return isMuted ? "Stummgeschaltet" : "Mikrofon aktiv"
    }
}
