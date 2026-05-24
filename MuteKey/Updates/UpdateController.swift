import Foundation
import Sparkle

/// Wraps SPUStandardUpdaterController and exposes update availability
/// as a published property for the About tab.
///
/// For scheduled (background) checks we act as the gentle-reminder handler:
/// the inline banner in the About tab IS the reminder. The full Sparkle update
/// sheet is only shown when the user taps "Install" or "Check for Updates".
@MainActor
final class UpdateController: NSObject, ObservableObject {
    private var updaterController: SPUStandardUpdaterController?

    /// Non-nil when Sparkle found a newer version. Cleared on "no update" response.
    @Published var availableVersion: String?

    /// True while a check is in progress (after button tap, before response).
    @Published var isChecking = false

    override init() {
        super.init()
        // Pass self as both delegates after super.init so the reference is valid.
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: self
        )
    }

    /// Shows the standard Sparkle update dialog (manual check from About tab).
    func checkForUpdates() {
        isChecking = true
        updaterController?.checkForUpdates(nil)
    }
}

// MARK: - SPUUpdaterDelegate

extension UpdateController: SPUUpdaterDelegate {
    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        Task { @MainActor in
            self.availableVersion = item.displayVersionString
            self.isChecking = false
        }
    }

    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        Task { @MainActor in
            self.availableVersion = nil
            self.isChecking = false
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        Task { @MainActor in
            self.isChecking = false
        }
    }
}

// MARK: - SPUStandardUserDriverDelegate

extension UpdateController: SPUStandardUserDriverDelegate {
    /// Signal to Sparkle that we handle gentle reminders ourselves (via the
    /// inline About-tab banner). This suppresses the "no gentle reminders"
    /// warning for LSUIElement / menu-bar apps.
    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    /// Called for scheduled background checks. We already set `availableVersion`
    /// via SPUUpdaterDelegate, so the About-tab banner is our reminder.
    /// Returning `true` tells Sparkle we handle the UI — it won't show its sheet.
    nonisolated func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediatelyPresentedUpdateImminent updateImminent: Bool
    ) -> Bool {
        true
    }
}
