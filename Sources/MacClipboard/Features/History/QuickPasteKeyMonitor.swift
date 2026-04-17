import AppKit
import SwiftUI

struct QuickPasteKeyMonitor: NSViewRepresentable {
    let onQuickPaste: (Int) -> Void

    func makeNSView(context: Context) -> MonitorView {
        let view = MonitorView()
        view.onQuickPaste = onQuickPaste
        return view
    }

    func updateNSView(_ nsView: MonitorView, context: Context) {
        nsView.onQuickPaste = onQuickPaste
    }

    final class MonitorView: NSView {
        var onQuickPaste: (Int) -> Void = { _ in }
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            removeMonitor()
            installMonitor()
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }

        private func installMonitor() {
            guard window != nil else {
                return
            }

            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else {
                    return event
                }

                return handle(event)
            }
        }

        private func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            guard
                let hostWindow = window,
                event.window === hostWindow,
                hostWindow.isKeyWindow,
                event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
                let characters = event.charactersIgnoringModifiers,
                characters.count == 1,
                let number = Int(characters),
                (1 ... 9).contains(number)
            else {
                return event
            }

            let callback = onQuickPaste
            DispatchQueue.main.async {
                callback(number)
            }

            return nil
        }
    }
}
