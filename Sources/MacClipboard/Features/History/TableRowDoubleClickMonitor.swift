import AppKit
import SwiftUI

struct TableRowDoubleClickMonitor: NSViewRepresentable {
    let onDoubleClick: (Int) -> Void

    func makeNSView(context: Context) -> MonitorView {
        let view = MonitorView()
        view.onDoubleClick = onDoubleClick
        return view
    }

    func updateNSView(_ nsView: MonitorView, context: Context) {
        nsView.onDoubleClick = onDoubleClick
    }

    final class MonitorView: NSView {
        var onDoubleClick: (Int) -> Void = { _ in }
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

            monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                self?.handle(event)
                return event
            }
        }

        private func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        private func handle(_ event: NSEvent) {
            guard
                event.clickCount == 2,
                let hostWindow = window,
                event.window === hostWindow,
                let rowIndex = Self.rowIndex(in: hostWindow, at: event.locationInWindow)
            else {
                return
            }

            let callback = onDoubleClick
            DispatchQueue.main.async {
                callback(rowIndex)
            }
        }

        private static func rowIndex(in window: NSWindow, at windowPoint: NSPoint) -> Int? {
            guard let hit = window.contentView?.hitTest(windowPoint) else {
                return nil
            }

            var current: NSView? = hit
            while let view = current {
                if let tableView = view as? NSTableView {
                    let tablePoint = tableView.convert(windowPoint, from: nil)
                    let row = tableView.row(at: tablePoint)
                    return row >= 0 ? row : nil
                }
                current = view.superview
            }

            return nil
        }
    }
}
