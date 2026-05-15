import AppKit
import CoreAudio

// Polls whether Slack is actively using microphone input to detect Huddle activity.
@MainActor
final class SlackStatePoller {
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
        let inHuddle = slackIsUsingMicrophone()
        if state.isInSlackHuddle != inHuddle {
            state.isInSlackHuddle = inHuddle
        }
        if !inHuddle {
            state.isSlackMuted = false
            state.isSlackCameraOn = false
        }
    }

    private func slackIsUsingMicrophone() -> Bool {
        guard let slack = SlackMuteAction.findSlackApp() else { return false }
        let pid = slack.processIdentifier

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
