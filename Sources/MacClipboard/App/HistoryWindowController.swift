import AppKit
import SwiftUI

@MainActor
final class HistoryWindowController: NSWindowController {
    private var escapeKeyMonitor: Any?

    init(historyStore: HistoryStore, settingsStore: AppSettingsStore, pasteService: PasteService) {
        let rootView = HistoryWindowView(
            historyStore: historyStore,
            settingsStore: settingsStore,
            pasteService: pasteService
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = AppMetadata.displayName
        window.center()
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]
        window.contentViewController = NSHostingController(rootView: rootView)

        super.init(window: window)
        installEscapeKeyMonitor()
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

    func toggleWindowVisibility() {
        if window?.isVisible == true {
            window?.orderOut(nil)
        } else {
            showWindow(nil)
        }
    }

    private func installEscapeKeyMonitor() {
        guard escapeKeyMonitor == nil else {
            return
        }

        escapeKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard
                let self,
                event.keyCode == 53,
                event.window === window,
                window?.isVisible == true
            else {
                return event
            }

            window?.orderOut(nil)
            return nil
        }
    }
}
