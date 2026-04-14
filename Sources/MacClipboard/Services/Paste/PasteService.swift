import AppKit
import ApplicationServices
import Carbon.HIToolbox

@MainActor
final class PasteService {
    private let toastService: ToastService
    private let loopProtector: ClipboardLoopProtector
    private let accessibilitySettingsURL =
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")

    init(
        toastService: ToastService = ToastService(),
        loopProtector: ClipboardLoopProtector
    ) {
        self.toastService = toastService
        self.loopProtector = loopProtector
    }

    var canAutoPaste: Bool {
        AXIsProcessTrusted()
    }

    func openAccessibilitySettings() {
        guard let accessibilitySettingsURL else {
            return
        }

        NSWorkspace.shared.open(accessibilitySettingsURL)
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
                  let image = NSImage(contentsOfFile: imagePath)
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

        triggerPasteShortcut()
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
}
