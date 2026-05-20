import Foundation

@MainActor
final class TeamsConnector: ObservableObject {
    private let state: MeetingState
    private var webSocketTask: URLSessionWebSocketTask?
    private var requestIdCounter = 1
    private var reconnectDelay: TimeInterval = 1
    private var shouldReconnect = true

    private static let userDefaultsKey = "de.benkrammer.ZackMute.TeamsToken"

    init(state: MeetingState) {
        self.state = state
    }

    // MARK: - Public API

    func connect() {
        shouldReconnect = true
        openConnection()
    }

    func disconnect() {
        shouldReconnect = false
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        state.isConnectedToTeams = false
    }

    func toggleMute() {
        if state.canToggleMute {
            // Enterprise Teams: WebSocket command only, no keyboard injection
            send(TeamsCommand.toggleMute(requestId: nextRequestId()))
        } else {
            // Personal Teams / fallback: keyboard injection + optimistic state
            TeamsMuteAction.toggle()
            state.isMuted.toggle()
        }
    }

    func toggleCamera() {
        if state.canToggleVideo {
            // Enterprise Teams: WebSocket command only, no keyboard injection
            send(TeamsCommand(action: "toggle-video", parameters: [:], requestId: nextRequestId()))
        } else {
            // Personal Teams / fallback: keyboard injection + optimistic state
            TeamsMuteAction.toggleCamera()
            state.isCameraOn.toggle()
        }
    }

    func clearToken() {
        deleteToken()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        state.isConnectedToTeams = false
        state.isInMeeting = false
        state.isMuted = false
        state.canToggleMute = false
        state.canToggleVideo = false
        // Keep reconnecting so Teams can send a new token on next meeting start
        shouldReconnect = true
        openConnection()
    }

    var hasToken: Bool { loadToken() != nil }

    // MARK: - Connection

    private func openConnection() {
        let token = loadToken() ?? ""
        guard let url = buildURL(token: token) else { return }

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        receiveLoop()
    }

    private func buildURL(token: String) -> URL? {
        var components = URLComponents()
        components.scheme = "ws"
        components.host = "localhost"
        components.port = 8124
        components.queryItems = [
            URLQueryItem(name: "token", value: token),
            URLQueryItem(name: "protocol-version", value: "2.0.0"),
            URLQueryItem(name: "manufacturer", value: "ZackMute"),
            URLQueryItem(name: "device", value: "Mac"),
            URLQueryItem(name: "app", value: "ZackMute"),
            URLQueryItem(name: "app-version", value: "1.0.0"),
        ]
        return components.url
    }

    // MARK: - Receive Loop

    private func receiveLoop() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .success(let message):
                    self.reconnectDelay = 1
                    self.handleMessage(message)
                    self.receiveLoop()
                case .failure:
                    self.handleDisconnect()
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8) else { return }

        print("[ZackMute] Received: \(text)")

        do {
            let decoded = try JSONDecoder().decode(TeamsMessage.self, from: data)

            if let token = decoded.tokenRefresh, !token.isEmpty {
                print("[ZackMute] Token received and saved")
                saveToken(token)
            }

            if let update = decoded.meetingUpdate {
                state.isConnectedToTeams = true
                if let ms = update.meetingState {
                    if let inMeeting = ms.isInMeeting { state.isInMeeting = inMeeting }
                    if let muted = ms.isMuted { state.isMuted = muted }
                    if let videoOn = ms.isVideoOn { state.isCameraOn = videoOn }
                    print("[ZackMute] State: inMeeting=\(ms.isInMeeting as Any) isMuted=\(ms.isMuted as Any) videoOn=\(ms.isVideoOn as Any)")
                }
                if let perms = update.meetingPermissions {
                    if let canMute = perms.canToggleMute { state.canToggleMute = canMute }
                    if let canVideo = perms.canToggleVideo { state.canToggleVideo = canVideo }
                    print("[ZackMute] Permissions: canToggleMute=\(perms.canToggleMute as Any) canToggleVideo=\(perms.canToggleVideo as Any)")
                }
            }
        } catch {
            print("[ZackMute] Decode error: \(error) — raw: \(text)")
        }
    }

    // MARK: - Send

    private func send(_ command: TeamsCommand) {
        guard let data = try? JSONEncoder().encode(command),
              let text = String(data: data, encoding: .utf8) else { return }
        webSocketTask?.send(.string(text)) { _ in }
    }

    private func nextRequestId() -> Int {
        defer { requestIdCounter += 1 }
        return requestIdCounter
    }

    // MARK: - Reconnect

    private func handleDisconnect() {
        let wasConnected = state.isConnectedToTeams
        webSocketTask = nil
        state.isConnectedToTeams = false
        state.canToggleMute = false
        state.canToggleVideo = false
        // Only reset meeting state if we actually had a connection.
        // If we were never connected (e.g. Personal Teams), let CoreAudio manage isInMeeting.
        // Only clear meeting state on a deliberate disconnect (shouldReconnect == false).
        // On unexpected drops we're about to reconnect; keeping state avoids the brief
        // window where isInMeeting == false causes hotkey presses to silently no-op.
        // TeamsStatePoller + the next WebSocket reconnect both correct state within ~2 s.
        if wasConnected && !shouldReconnect {
            state.isInMeeting = false
            state.isMuted = false
            state.isCameraOn = false
        }

        guard shouldReconnect else { return }

        let delay = reconnectDelay
        reconnectDelay = min(reconnectDelay * 2, 30)

        Task {
            try? await Task.sleep(for: .seconds(delay))
            await MainActor.run { [weak self] in
                self?.openConnection()
            }
        }
    }

    // MARK: - Token (UserDefaults — local pairing token, not sensitive)

    private func saveToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: Self.userDefaultsKey)
    }

    private func loadToken() -> String? {
        UserDefaults.standard.string(forKey: Self.userDefaultsKey)
    }

    private func deleteToken() {
        UserDefaults.standard.removeObject(forKey: Self.userDefaultsKey)
    }
}
