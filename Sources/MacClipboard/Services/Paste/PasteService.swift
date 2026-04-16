import AppKit
@preconcurrency import ApplicationServices
import Carbon.HIToolbox
import Combine

@MainActor
final class PasteService: ObservableObject {
    @Published private(set) var canAutoPaste: Bool

    private let toastService: ToastService
    private let loopProtector: ClipboardLoopProtector
    private var targetApplication: NSRunningApplication?
    private var targetHasTextInput = false
    private let accessibilitySettingsURL =
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    private var notificationObservers: [NSObjectProtocol] = []
    private var permissionRefreshTask: Task<Void, Never>?

    init(
        toastService: ToastService = ToastService(),
        loopProtector: ClipboardLoopProtector
    ) {
        canAutoPaste = AXIsProcessTrusted()
        self.toastService = toastService
        self.loopProtector = loopProtector
        installPermissionObservers()
    }

    func openAccessibilitySettings() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary

        if AXIsProcessTrustedWithOptions(options) {
            refreshAccessibilityPermission()
            return
        }

        guard let accessibilitySettingsURL else {
            return
        }

        NSWorkspace.shared.open(accessibilitySettingsURL)
        startPollingAccessibilityPermission()
    }

    func refreshAccessibilityPermission() {
        let isTrusted = AXIsProcessTrusted()

        guard canAutoPaste != isTrusted else {
            return
        }

        canAutoPaste = isTrusted
    }

    func capturePotentialPasteTarget() {
        guard let frontmostApplication = NSWorkspace.shared.frontmostApplication else {
            targetHasTextInput = false
            return
        }

        guard frontmostApplication.bundleIdentifier != Bundle.main.bundleIdentifier else {
            targetHasTextInput = false
            return
        }

        targetApplication = frontmostApplication
        targetHasTextInput = canAutoPaste && focusedElementAcceptsPaste(in: frontmostApplication)
    }

    @discardableResult
    func restore(item: ClipboardItem, autoPaste: Bool, feedbackMessage: String? = nil) -> Bool {
        let pasteboard = NSPasteboard.general
        loopProtector.registerRestoredHash(item.contentHash)
        pasteboard.clearContents()

        switch item.kind {
        case .text:
            guard let textContent = item.textContent else {
                return false
            }
            pasteboard.setString(textContent, forType: .string)

        case .image:
            guard let imagePath = item.imagePath,
                  let image = ClipboardImageCache.shared.image(forPath: imagePath)
            else {
                return false
            }
            pasteboard.writeObjects([image])

        case .url:
            guard let urlString = item.urlString,
                  let url = URL(string: urlString)
            else {
                return false
            }
            pasteboard.writeObjects([url as NSURL])

        case .file:
            let fileURLs = item.filePaths.map { URL(fileURLWithPath: $0) as NSURL }
            guard fileURLs.isEmpty == false else {
                return false
            }
            pasteboard.writeObjects(fileURLs)

        case .html:
            guard let htmlContent = item.htmlContent else {
                return false
            }

            pasteboard.setString(htmlContent, forType: .html)

            if let textContent = item.textContent {
                pasteboard.setString(textContent, forType: .string)
            }

        case .richText:
            guard let richTextPath = item.richTextPath,
                  let richTextData = try? Data(contentsOf: URL(fileURLWithPath: richTextPath))
            else {
                return false
            }

            pasteboard.setData(richTextData, forType: .rtf)

            if let textContent = item.textContent {
                pasteboard.setString(textContent, forType: .string)
            }
        }

        if let feedbackMessage {
            toastService.show(message: feedbackMessage)
        }

        guard autoPaste, canAutoPaste else {
            return true
        }

        scheduleAutoPaste()
        return true
    }

    private func triggerPasteShortcut() {
        guard let eventSource = CGEventSource(stateID: .hidSystemState) else {
            return
        }

        let keyDown = CGEvent(
            keyboardEventSource: eventSource,
            virtualKey: CGKeyCode(kVK_ANSI_V),
            keyDown: true
        )
        let keyUp = CGEvent(
            keyboardEventSource: eventSource,
            virtualKey: CGKeyCode(kVK_ANSI_V),
            keyDown: false
        )

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func installPermissionObservers() {
        let center = NotificationCenter.default

        notificationObservers.append(
            center.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshAccessibilityPermission()
                }
            }
        )
    }

    private func startPollingAccessibilityPermission() {
        permissionRefreshTask?.cancel()

        permissionRefreshTask = Task { @MainActor in
            for _ in 0 ..< 20 {
                refreshAccessibilityPermission()

                if canAutoPaste {
                    return
                }

                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    private func scheduleAutoPaste() {
        let applicationToActivate = resolvedTargetApplication()

        guard targetHasTextInput else {
            return
        }

        Task { @MainActor in
            if let applicationToActivate {
                applicationToActivate.activate(options: [.activateIgnoringOtherApps])
            }

            try? await Task.sleep(for: .milliseconds(180))
            refreshAccessibilityPermission()

            guard canAutoPaste else {
                return
            }

            triggerPasteShortcut()
        }
    }

    private func focusedElementAcceptsPaste(in application: NSRunningApplication) -> Bool {
        let appElement = AXUIElementCreateApplication(application.processIdentifier)

        var focusedValue: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )

        guard focusedResult == .success, let focusedValue else {
            return false
        }

        // AXUIElement is a CoreFoundation type — conditional downcast always succeeds,
        // and force cast is the canonical pattern for CFTypeRef → AXUIElement.
        // swiftlint:disable:next force_cast
        let focusedElement = focusedValue as! AXUIElement

        var roleValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(
            focusedElement,
            kAXRoleAttribute as CFString,
            &roleValue
        ) == .success,
            let role = roleValue as? String,
            Self.textInputRoles.contains(role)
        {
            return true
        }

        var isSettable: DarwinBoolean = false
        guard AXUIElementIsAttributeSettable(
            focusedElement,
            kAXValueAttribute as CFString,
            &isSettable
        ) == .success else {
            return false
        }

        return isSettable.boolValue
    }

    private static let textInputRoles: Set<String> = [
        NSAccessibility.Role.textField.rawValue,
        NSAccessibility.Role.textArea.rawValue,
        NSAccessibility.Role.comboBox.rawValue,
    ]

    private func resolvedTargetApplication() -> NSRunningApplication? {
        if let targetApplication,
           targetApplication.isTerminated == false,
           targetApplication.bundleIdentifier != Bundle.main.bundleIdentifier
        {
            return targetApplication
        }

        guard let frontmostApplication = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        guard frontmostApplication.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return nil
        }

        return frontmostApplication
    }
}
