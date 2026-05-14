import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleMute   = Self("toggleMute",   default: .init(.f19))
    static let toggleCamera = Self("toggleCamera", default: .init(.f16))
}

enum HotkeyManager {
    static func setup(teamsConnector: TeamsConnector) {
        KeyboardShortcuts.onKeyDown(for: .toggleMute) {
            Task { @MainActor in teamsConnector.toggleMute() }
        }
        KeyboardShortcuts.onKeyDown(for: .toggleCamera) {
            Task { @MainActor in teamsConnector.toggleCamera() }
        }
    }
}
