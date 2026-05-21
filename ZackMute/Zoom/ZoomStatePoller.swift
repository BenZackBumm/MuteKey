import AppKit
import CoreAudio
import Darwin

// Polls whether any Zoom process is actively using the microphone input.
// Zoom uses "zoom.us" as its main process name.
@MainActor
final class ZoomStatePoller {
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
        let zoomRunning = ZoomMuteAction.isZoomRunning
        if state.isZoomRunning != zoomRunning {
            state.isZoomRunning = zoomRunning
        }
        let inMeeting = zoomIsUsingMicrophone()
        if state.isInZoomMeeting != inMeeting {
            state.isInZoomMeeting = inMeeting
        }
        if !inMeeting {
            state.isZoomMuted = false
            state.isZoomCameraOn = false
        }
    }

    private func zoomIsUsingMicrophone() -> Bool {
        guard ZoomMuteAction.isZoomRunning else { return false }

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
            guard AudioObjectGetPropertyData(objectID, &pidAddr, 0, nil, &pidSize, &pidValue) == noErr
            else { continue }

            guard isZoomProcess(pidValue) else { continue }

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

    // Check if a PID belongs to any Zoom process.
    private func isZoomProcess(_ pid: pid_t) -> Bool {
        var name = [CChar](repeating: 0, count: 256)
        proc_name(pid, &name, UInt32(name.count))
        return String(cString: name).lowercased().contains("zoom")
    }
}
