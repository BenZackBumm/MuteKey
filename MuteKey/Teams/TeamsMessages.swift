import Foundation

// MARK: - Incoming from Teams

struct TeamsMessage: Decodable {
    let tokenRefresh: String?
    let meetingUpdate: MeetingUpdate?
    let errorMsg: String?
}

struct MeetingUpdate: Decodable {
    let meetingState: MeetingStatePayload?
    let meetingPermissions: MeetingPermissions?
}

struct MeetingStatePayload: Decodable {
    let isMuted: Bool?
    let isVideoOn: Bool?
    let isInMeeting: Bool?
    let isHandRaised: Bool?
    let isRecordingOn: Bool?
    let isBackgroundBlurred: Bool?
    let isSharing: Bool?
}

struct MeetingPermissions: Decodable {
    let canToggleMute: Bool?
    let canToggleVideo: Bool?
}

// MARK: - Outgoing to Teams

struct TeamsCommand: Encodable {
    let action: String
    let parameters: [String: String]
    let requestId: Int
}

extension TeamsCommand {
    static func toggleMute(requestId: Int) -> TeamsCommand {
        TeamsCommand(action: "toggle-mute", parameters: [:], requestId: requestId)
    }
    static func toggleHand(requestId: Int) -> TeamsCommand {
        TeamsCommand(action: "toggle-hand", parameters: [:], requestId: requestId)
    }
}
