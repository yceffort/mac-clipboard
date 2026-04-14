import AppKit
import SwiftUI

@MainActor
final class ToastService {
    private var panel: ToastPanel?
    private var hostingController: NSHostingController<ToastView>?
    private var dismissWorkItem: DispatchWorkItem?

    func show(message: String) {
        let panel = makePanel(message: message)
        position(panel)
        dismissWorkItem?.cancel()

        if panel.isVisible == false {
            panel.alphaValue = 0
            panel.orderFrontRegardless()

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                panel.animator().alphaValue = 1
            }
        } else {
            panel.orderFrontRegardless()
        }

        let dismissWorkItem = DispatchWorkItem { [weak self] in
            self?.dismiss(panel)
        }
        self.dismissWorkItem = dismissWorkItem

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: dismissWorkItem)
    }

    private func makePanel(message: String) -> ToastPanel {
        let rootView = ToastView(message: message)

        if let hostingController, let panel {
            hostingController.rootView = rootView
            hostingController.view.layoutSubtreeIfNeeded()
            let fittingSize = hostingController.view.fittingSize
            panel.setContentSize(fittingSize)
            return panel
        }

        let hostingController = NSHostingController(rootView: rootView)
        hostingController.view.wantsLayer = true

        let fittingSize = hostingController.view.fittingSize
        let panel = ToastPanel(
            contentRect: NSRect(origin: .zero, size: fittingSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.contentViewController = hostingController

        self.hostingController = hostingController
        self.panel = panel
        return panel
    }

    private func position(_ panel: NSPanel) {
        let screen = targetScreen()
        let visibleFrame = screen.visibleFrame
        let x = visibleFrame.midX - (panel.frame.width / 2)
        let y = visibleFrame.minY + 28

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func targetScreen() -> NSScreen {
        let mouseLocation = NSEvent.mouseLocation

        return NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
            ?? NSScreen.screens[0]
    }

    private func dismiss(_ panel: NSPanel) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel.animator().alphaValue = 0
        } completionHandler: {
            Task { @MainActor in
                panel.orderOut(nil)
            }
        }
    }
}

private final class ToastPanel: NSPanel {
    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}

private struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.regularMaterial)
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
            .fixedSize()
    }
}
