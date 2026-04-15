import AppKit

@MainActor
final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    private let openAbout: () -> Void
    private let openSettings: () -> Void
    private let openHistory: () -> Void
    private let checkForUpdates: () -> Void
    private let toggleMonitoring: () -> Void
    private let clearHistory: () -> Void
    private let selectRecentItem: (ClipboardItem) -> Void
    private let quit: () -> Void

    private let menu = NSMenu()
    private let monitoringMenuItem = NSMenuItem()
    private let clearHistoryMenuItem = NSMenuItem()
    private var recentItems: [ClipboardItem] = []
    private var shortcutTitle: String
    private var isMonitoringEnabled: Bool

    init(
        initialMonitoringEnabled: Bool,
        shortcutTitle: String,
        openAbout: @escaping () -> Void,
        openSettings: @escaping () -> Void,
        openHistory: @escaping () -> Void,
        checkForUpdates: @escaping () -> Void,
        toggleMonitoring: @escaping () -> Void,
        clearHistory: @escaping () -> Void,
        selectRecentItem: @escaping (ClipboardItem) -> Void,
        quit: @escaping () -> Void
    ) {
        self.openAbout = openAbout
        self.openSettings = openSettings
        self.openHistory = openHistory
        self.checkForUpdates = checkForUpdates
        self.toggleMonitoring = toggleMonitoring
        self.clearHistory = clearHistory
        self.selectRecentItem = selectRecentItem
        self.quit = quit
        self.shortcutTitle = shortcutTitle
        isMonitoringEnabled = initialMonitoringEnabled
        super.init()

        statusItem.menu = menu
        rebuildMenu()
    }

    func updateMonitoringState(isEnabled: Bool) {
        isMonitoringEnabled = isEnabled
        rebuildMenu()
    }

    func updateRecentItems(_ items: [ClipboardItem]) {
        recentItems = Array(items.prefix(5))
        rebuildMenu()
    }

    func updateShortcutTitle(_ title: String) {
        shortcutTitle = title
        rebuildMenu()
    }

    @objc
    private func openHistoryAction() {
        openHistory()
    }

    @objc
    private func openAboutAction() {
        openAbout()
    }

    @objc
    private func toggleMonitoringAction() {
        toggleMonitoring()
    }

    @objc
    private func openSettingsAction() {
        openSettings()
    }

    @objc
    private func checkForUpdatesAction() {
        checkForUpdates()
    }

    @objc
    private func clearHistoryAction() {
        clearHistory()
    }

    @objc
    private func selectRecentItemAction(_ sender: NSMenuItem) {
        let index = sender.tag

        guard recentItems.indices.contains(index) else {
            return
        }

        selectRecentItem(recentItems[index])
    }

    @objc
    private func quitAction() {
        quit()
    }

    private func rebuildMenu() {
        updateStatusAppearance()
        menu.removeAllItems()

        let openHistoryItem = NSMenuItem(
            title: "Open \(AppMetadata.displayName)",
            action: #selector(openHistoryAction),
            keyEquivalent: ""
        )
        openHistoryItem.target = self
        menu.addItem(openHistoryItem)

        let aboutItem = NSMenuItem(
            title: "About \(AppMetadata.displayName)",
            action: #selector(openAboutAction),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        let settingsItem = NSMenuItem(
            title: "Settings",
            action: #selector(openSettingsAction),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let checkForUpdatesItem = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdatesAction),
            keyEquivalent: ""
        )
        checkForUpdatesItem.target = self
        menu.addItem(checkForUpdatesItem)

        clearHistoryMenuItem.title = "Clear History"
        clearHistoryMenuItem.target = self
        clearHistoryMenuItem.action = #selector(clearHistoryAction)
        clearHistoryMenuItem.isEnabled = recentItems.isEmpty == false
        menu.addItem(clearHistoryMenuItem)

        menu.addItem(.separator())

        if recentItems.isEmpty == false {
            let header = NSMenuItem(title: "Recent Copies", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)

            for (index, item) in recentItems.enumerated() {
                let itemMenuItem = NSMenuItem(
                    title: item.displayTitle,
                    action: #selector(selectRecentItemAction(_:)),
                    keyEquivalent: ""
                )
                itemMenuItem.target = self
                itemMenuItem.tag = index
                itemMenuItem.toolTip = item.displaySubtitle
                itemMenuItem.image = NSImage(
                    systemSymbolName: item.symbolName,
                    accessibilityDescription: item.displayTitle
                )
                menu.addItem(itemMenuItem)
            }

            menu.addItem(.separator())
        }

        monitoringMenuItem.title = isMonitoringEnabled ? "Pause Monitoring" : "Resume Monitoring"
        monitoringMenuItem.state = .off
        monitoringMenuItem.target = self
        monitoringMenuItem.action = #selector(toggleMonitoringAction)
        menu.addItem(monitoringMenuItem)

        let shortcutHint = NSMenuItem(title: "Shortcut: \(shortcutTitle)", action: nil, keyEquivalent: "")
        shortcutHint.isEnabled = false
        menu.addItem(shortcutHint)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quitAction),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func updateStatusAppearance() {
        guard let button = statusItem.button else {
            return
        }

        let symbolName = isMonitoringEnabled ? "doc.on.clipboard" : "pause.circle"
        button.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: AppMetadata.displayName
        )
        button.image?.isTemplate = true
        button.toolTip = isMonitoringEnabled ? AppMetadata.displayName : "\(AppMetadata.displayName) (Paused)"
    }
}
