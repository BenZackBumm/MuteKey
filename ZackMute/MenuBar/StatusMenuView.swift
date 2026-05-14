import SwiftUI

// Read-only status display embedded in the NSMenuItem custom view.
// All interactive actions are native NSMenuItems (mouse tracking works reliably there).
struct StatusMenuView: View {
    @ObservedObject var meetingState: MeetingState

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(meetingState.statusDescription)
                .font(.system(size: 13, weight: .medium))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 220)
    }

    private var statusColor: Color {
        guard meetingState.isConnectedToTeams else { return .secondary }
        guard meetingState.isInMeeting else { return .secondary }
        return meetingState.isMuted ? .red : .green
    }
}
