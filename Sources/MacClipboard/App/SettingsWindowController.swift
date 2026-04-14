import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    init(settingsStore: AppSettingsStore) {
        let rootView = SettingsWindowView(settingsStore: settingsStore)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 560),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "\(AppMetadata.displayName) Settings"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: rootView)

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }
}
