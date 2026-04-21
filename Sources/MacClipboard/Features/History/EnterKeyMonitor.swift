import AppKit
import Carbon.HIToolbox
import SwiftUI

struct EnterKeyMonitor: NSViewRepresentable {
    let onEnter: () -> Void

    func makeNSView(context: Context) -> MonitorView {
        let view = MonitorView()
        view.onEnter = onEnter
        return view
    }

    func updateNSView(_ nsView: MonitorView, context: Context) {
        nsView.onEnter = onEnter
    }

    final class MonitorView: NSView {
        var onEnter: () -> Void = {}
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
                event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty,
                event.keyCode == UInt16(kVK_Return) || event.keyCode == UInt16(kVK_ANSI_KeypadEnter)
            else {
                return event
            }

            let callback = onEnter
            DispatchQueue.main.async {
                callback()
            }

            return nil
        }
    }
}
