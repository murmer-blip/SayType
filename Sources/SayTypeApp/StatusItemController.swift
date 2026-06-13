import AppKit
import SayTypeCore

@MainActor
final class StatusItemController: NSObject {
    var onToggle: (() -> Void)?
    var onRequestPermissions: (() -> Void)?

    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let statusMenuItem = NSMenuItem(title: "SayType: Ready", action: nil, keyEquivalent: "")
    private let toggleMenuItem = NSMenuItem(title: "Toggle Dictation", action: #selector(toggle), keyEquivalent: "")
    private let permissionMenuItem = NSMenuItem(title: "Request Permissions", action: #selector(requestPermissions), keyEquivalent: "")
    private let iconConfiguration = NSImage.SymbolConfiguration(pointSize: 19, weight: .regular)
    private let iconSize = NSSize(width: 19, height: 19)

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureMenu()
        render(.idle)
    }

    func render(_ state: SayTypeState) {
        guard let button = statusItem.button else { return }
        button.image = icon(for: state)
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyUpOrDown
        button.contentTintColor = nil
        button.toolTip = "SayType: \(state.statusText)"
        statusMenuItem.title = "SayType: \(state.statusText)"
    }

    private func configureMenu() {
        statusMenuItem.isEnabled = false
        toggleMenuItem.target = self
        permissionMenuItem.target = self

        menu.addItem(statusMenuItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(toggleMenuItem)
        menu.addItem(NSMenuItem(title: SayTypeDefaults.hotKey.displayName, action: nil, keyEquivalent: ""))
        menu.addItem(permissionMenuItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit SayType", action: #selector(quit), keyEquivalent: "q"))
        menu.items.last?.target = self
        statusItem.menu = menu
    }

    private func icon(for state: SayTypeState) -> NSImage? {
        let symbolName: String
        switch state {
        case .idle:
            symbolName = "waveform.circle.fill"
        case .hotkeyReceived:
            symbolName = "bolt.circle.fill"
        case .preparing:
            symbolName = "arrow.triangle.2.circlepath.circle.fill"
        case .recording:
            symbolName = "mic.circle.fill"
        case .transcribing:
            symbolName = "waveform.circle.fill"
        case .pasting:
            symbolName = "paperplane.circle.fill"
        case .finished:
            symbolName = "checkmark.circle.fill"
        case .failed:
            symbolName = "exclamationmark.triangle.fill"
        }
        let baseImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: state.statusText)
        let image = baseImage?.withSymbolConfiguration(iconConfiguration) ?? baseImage
        image?.isTemplate = true
        image?.size = iconSize
        return image
    }

    @objc private func toggle() {
        onToggle?()
    }

    @objc private func requestPermissions() {
        onRequestPermissions?()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
