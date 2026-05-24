import SwiftUI
import KeyboardShortcuts
import ServiceManagement

private enum WizardStep {
    case welcome, accessibility, shortcuts, teamsSetup, launchAtLogin, done
}

struct WizardView: View {
    @State private var currentStep = 0

    private var isTeamsInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.teams2") != nil
            || NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.teams") != nil
    }

    private var steps: [WizardStep] {
        var s: [WizardStep] = [.welcome, .accessibility, .shortcuts]
        if isTeamsInstalled { s.append(.teamsSetup) }
        s.append(contentsOf: [.launchAtLogin, .done])
        return s
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch steps[currentStep] {
                case .welcome:       WelcomeStepView()
                case .accessibility: AccessibilityStepView()
                case .shortcuts:     ShortcutsStepView()
                case .teamsSetup:    TeamsSetupStepView()
                case .launchAtLogin: LaunchAtLoginStepView()
                case .done:          DoneStepView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack {
                if currentStep > 0 {
                    Button(String(localized: "wizard.back")) {
                        currentStep -= 1
                    }
                }
                Spacer()
                Button(currentStep < steps.count - 1
                       ? String(localized: "wizard.next")
                       : String(localized: "wizard.done")) {
                    if currentStep < steps.count - 1 {
                        currentStep += 1
                    } else {
                        WizardWindowController.markCompleted()
                        Task { @MainActor in NSApp.keyWindow?.close() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 480, height: 420)
    }
}

// MARK: - Welcome

private struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
                .resizable()
                .frame(width: 80, height: 80)
            Text("wizard.welcome.title")
                .font(.title2).bold()
            Text("wizard.welcome.subtitle")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(40)
    }
}

// MARK: - Accessibility

private struct AccessibilityStepView: View {
    @State private var isGranted = AXIsProcessTrusted()

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            Text("wizard.accessibility.title")
                .font(.title2).bold()
            Text("wizard.accessibility.description")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Circle()
                    .fill(isGranted ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(isGranted
                     ? String(localized: "wizard.accessibility.granted")
                     : String(localized: "wizard.accessibility.denied"))
            }

            if !isGranted {
                Button(String(localized: "settings.accessibility.grant_button")) {
                    TeamsMuteAction.requestAccessibility()
                }
            }
        }
        .padding(40)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            isGranted = AXIsProcessTrusted()
        }
    }
}

// MARK: - Shortcuts

private struct ShortcutsStepView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "keyboard")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            Text("wizard.shortcuts.title")
                .font(.title2).bold()
            Text("wizard.shortcuts.description")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "mic.slash.fill").frame(width: 20)
                    Text("settings.shortcut.mic")
                    Spacer()
                    KeyboardShortcuts.Recorder("", name: .toggleMute)
                }
                HStack {
                    Image(systemName: "video.fill").frame(width: 20)
                    Text("settings.shortcut.camera")
                    Spacer()
                    KeyboardShortcuts.Recorder("", name: .toggleCamera)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(40)
    }
}

// MARK: - Teams Setup

private struct TeamsSetupStepView: View {
    private var imageName: String {
        Locale.current.language.languageCode?.identifier == "de" ? "teams-api-de" : "teams-api-en"
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("wizard.teams.title")
                .font(.title2).bold()
            Text("wizard.teams.description")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Image(imageName)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
    }
}

// MARK: - Launch at Login

private struct LaunchAtLoginStepView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.up.right.square.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            Text("wizard.login.title")
                .font(.title2).bold()
            Text("wizard.login.description")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            HStack {
                Text("settings.launch_at_login")
                Spacer()
                Toggle("", isOn: Binding(
                    get: { SMAppService.mainApp.status == .enabled },
                    set: { setLaunchAtLogin($0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(40)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else        { try SMAppService.mainApp.unregister() }
        } catch {
            print("[MuteKey] Wizard launch-at-login error: \(error)")
        }
    }
}

// MARK: - Done

private struct DoneStepView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("wizard.done.title")
                .font(.title2).bold()
            Text("wizard.done.description")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(40)
    }
}
