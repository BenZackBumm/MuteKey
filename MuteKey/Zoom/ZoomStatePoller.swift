import AppKit
import CoreAudio
import Darwin

// Polls Zoom meeting state via two mechanisms:
//   1. CoreAudio  — detects whether a Zoom process is actively using the microphone
//                   (= "in a meeting")
//   2. AX-Tree    — reads the true mic and camera state from Zoom's toolbar buttons
//                   (Option C: keyboard injection for toggle, AX for real status)
//
// AX button labels scanned (Zoom is a native macOS app → AX is reliable):
//   Mic  muted   : "Unmute" / "Stummschaltung aufheben"
//   Mic  unmuted : "Mute"   / "Stummschalten"
//   Cam  on      : "Stop Video"   / "Video anhalten"
//   Cam  off     : "Start Video"  / "Video starten"
//
// If AX scanning fails (window minimised, permission missing, etc.)
// the last known state is preserved — no spurious resets.
@MainActor
final class ZoomStatePoller {
    private weak var state: MeetingState?
    private var timer: Timer?
    private var isAxScanning = false

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

        if inMeeting {
            guard !isAxScanning else { return }
            isAxScanning = true
            let pid = ZoomMuteAction.findZoomApp()?.processIdentifier
            Task.detached { [weak self] in
                guard let self, let pid else {
                    await MainActor.run { [weak self] in self?.isAxScanning = false }
                    return
                }
                let (micMuted, camOn) = self.scanButtons(pid: pid)
                await MainActor.run { [weak self] in
                    guard let self, let state = self.state else { return }
                    self.isAxScanning = false
                    if let micMuted { if state.isZoomMuted    != micMuted { state.isZoomMuted    = micMuted } }
                    if let camOn    { if state.isZoomCameraOn != camOn    { state.isZoomCameraOn = camOn    } }
                }
            }
        } else {
            state.isZoomMuted    = false
            state.isZoomCameraOn = false
        }
    }

    // MARK: - AX-Tree Status Reading (nonisolated — called from background thread)

    /// Single traversal that finds both mic and camera button labels.
    nonisolated private func scanButtons(pid: pid_t) -> (micMuted: Bool?, cameraOn: Bool?) {
        let axApp = AXUIElementCreateApplication(pid)
        // Short timeout per element — prevents blocking when a Zoom helper process is unresponsive.
        AXUIElementSetMessagingTimeout(axApp, 1.0)

        var micLabel: String?
        var camLabel: String?
        collectButtons(in: axApp, depth: 0, micLabel: &micLabel, camLabel: &camLabel)

        let micMuted = micLabel.map { label in
            unmuteLabels.contains { label.localizedCaseInsensitiveContains($0) }
        }
        let cameraOn = camLabel.map { label in
            stopVideoLabels.contains { label.localizedCaseInsensitiveContains($0) }
        }

        return (micMuted, cameraOn)
    }

    // MARK: - AX Traversal

    nonisolated private static let maxAXDepth = 8

    /// Single depth-limited traversal collecting the first matching mic and camera button labels.
    nonisolated private func collectButtons(
        in element: AXUIElement,
        depth: Int,
        micLabel: inout String?,
        camLabel: inout String?
    ) {
        guard depth <= Self.maxAXDepth else { return }
        guard micLabel == nil || camLabel == nil else { return } // both found → stop

        if let label = axButtonLabel(of: element) {
            if micLabel == nil, micLabels.contains(where: { label.localizedCaseInsensitiveContains($0) }) {
                micLabel = label
            }
            if camLabel == nil, cameraLabels.contains(where: { label.localizedCaseInsensitiveContains($0) }) {
                camLabel = label
            }
        }

        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement]
        else { return }

        for child in children {
            guard micLabel == nil || camLabel == nil else { return }
            collectButtons(in: child, depth: depth + 1, micLabel: &micLabel, camLabel: &camLabel)
        }
    }

    /// Returns the accessible label of a button element, nil for non-buttons.
    nonisolated private func axButtonLabel(of element: AXUIElement) -> String? {
        var roleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
              let role = roleRef as? String, role == kAXButtonRole as String
        else { return nil }

        for attr in [kAXTitleAttribute, kAXDescriptionAttribute, kAXHelpAttribute] {
            var valRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, attr as CFString, &valRef) == .success,
               let val = valRef as? String, !val.isEmpty {
                return val
            }
        }
        return nil
    }

    // MARK: - Label Keyword Tables

    // Keywords to identify the mic button (any state)
    private let micLabels = ["Mute", "Unmute", "Stummschalten", "Stummschaltung"]

    // Labels shown when mic IS muted (button action = "unmute")
    // "aufheben" matches "Stummschaltung aufheben" and "Stummschaltung für Audio aufheben"
    private let unmuteLabels = ["Unmute", "aufheben"]

    // Keywords to identify the camera button (any state)
    private let cameraLabels = ["Start Video", "Stop Video", "Video starten", "Video anhalten", "Video stoppen", "Video beenden"]

    // Labels shown when camera IS on (button action = "stop/end video")
    // "Video beenden" = German Zoom label when camera is active
    private let stopVideoLabels = ["Stop Video", "Video anhalten", "Video stoppen", "Video beenden"]

    // MARK: - CoreAudio Meeting Detection

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

    private func isZoomProcess(_ pid: pid_t) -> Bool {
        var name = [UInt8](repeating: 0, count: 256)
        proc_name(pid, &name, UInt32(name.count))
        return String(decoding: name.prefix(while: { $0 != 0 }), as: UTF8.self).lowercased().contains("zoom")
    }
}
