import AppKit
import SayTypeCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private var hotKeyRegistrar: HotKeyRegistrar?
    private var coordinator: DictationCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLog.write("app launched")
        let statusItemController = StatusItemController()
        let coordinator = DictationCoordinator(
            stateChanged: { [weak statusItemController] state in
                statusItemController?.render(state)
            }
        )

        statusItemController.onToggle = { [weak coordinator] in
            coordinator?.toggle()
        }
        statusItemController.onRequestPermissions = {
            PermissionPrompter.promptForAccessibility()
            Task {
                try? await PermissionPrompter.requestSpeechAuthorization()
                try? await PermissionPrompter.requestMicrophoneAccess()
            }
        }

        do {
            hotKeyRegistrar = try HotKeyRegistrar(spec: SayTypeDefaults.hotKey) { [weak coordinator] in
                coordinator?.toggleFromHotKey()
            }
            AppLog.write("registered hotkey \(SayTypeDefaults.hotKey.displayName)")
        } catch {
            AppLog.write("hotkey registration failed: \(error.localizedDescription)")
            coordinator.setFailure("Hotkey unavailable: \(error.localizedDescription)")
        }

        self.statusItemController = statusItemController
        self.coordinator = coordinator

        PermissionPrompter.promptForAccessibility()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppLog.write("app terminating")
    }
}
