import AppKit
import CoreAudio

// Polls whether Teams is actively using the microphone input.
// This works without WebSocket pairing and covers all meeting types.
@MainActor
final class TeamsStatePoller {
    private weak var state: MeetingState?
    private var timer: Timer?

    init(state: MeetingState) {
        self.state = state
    }

    func start() {
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.poll() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        guard let state else { return }
        let teamsRunning = TeamsMuteAction.isTeamsRunning
        if state.isTeamsRunning != teamsRunning {
            state.isTeamsRunning = teamsRunning
        }
        let inMeeting = teamsIsUsingMicrophone()
        // Only update meeting state if WebSocket isn't providing real state
        if !state.canToggleMute {
            if state.isInMeeting != inMeeting {
                state.isInMeeting = inMeeting
            }
        }
    }

    // Returns true if the Teams process currently has an active audio input stream.
    private func teamsIsUsingMicrophone() -> Bool {
        guard let teams = TeamsMuteAction.findTeamsApp() else { return false }
        let pid = teams.processIdentifier

        var size: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size
        ) == noErr, size > 0 else { return false }

        let count = Int(size) / MemoryLayout<AudioObjectID>.size
        var objectIDs = [AudioObjectID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &objectIDs
        ) == noErr else { return false }

        for objectID in objectIDs {
            var pidValue: pid_t = 0
            var pidSize = UInt32(MemoryLayout<pid_t>.size)
            var pidAddr = AudioObjectPropertyAddress(
                mSelector: kAudioProcessPropertyPID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            guard AudioObjectGetPropertyData(objectID, &pidAddr, 0, nil, &pidSize, &pidValue) == noErr,
                  pidValue == pid else { continue }

            // Check if this process has an active input stream
            var isRunning: UInt32 = 0
            var runningSize = UInt32(MemoryLayout<UInt32>.size)
            var runningAddr = AudioObjectPropertyAddress(
                mSelector: kAudioProcessPropertyIsRunning,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            if AudioObjectGetPropertyData(objectID, &runningAddr, 0, nil, &runningSize, &isRunning) == noErr,
               isRunning != 0 {
                return true
            }
        }
        return false
    }
}
