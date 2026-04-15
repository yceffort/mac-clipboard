import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let historyStore = HistoryStore()
    private let settingsStore = AppSettingsStore()
    private let loopProtector = ClipboardLoopProtector()
    private let launchAtLoginManager = LaunchAtLoginManager()

    private lazy var pasteService = PasteService(loopProtector: loopProtector)

    private var clipboardMonitor: ClipboardMonitor?
    private var menuBarController: MenuBarController?
    private var historyWindowController: HistoryWindowController?
    private var settingsWindowController: SettingsWindowController?
    private var hotkeyManager: HotkeyManager?
    private var updateService: UpdateService?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()

        historyStore.loadPersistedItems()
        historyStore.configure(maxItems: settingsStore.settings.maxHistoryCount)
        settingsStore.settings.launchAtLoginEnabled = launchAtLoginManager.isEnabled
        applyAppearancePreference(settingsStore.settings.appearancePreference)

        let windowController = HistoryWindowController(
            historyStore: historyStore,
            settingsStore: settingsStore,
            pasteService: pasteService
        )
        historyWindowController = windowController

        let settingsWindowController = SettingsWindowController(settingsStore: settingsStore)
        self.settingsWindowController = settingsWindowController
        let updateService = UpdateService(settingsStore: settingsStore)
        self.updateService = updateService

        let monitor = ClipboardMonitor(historyStore: historyStore, settingsStore: settingsStore)
        monitor.loopProtector = loopProtector
        monitor.start()
        clipboardMonitor = monitor

        let menuBarController = MenuBarController(
            initialMonitoringEnabled: monitor.isRunning,
            shortcutTitle: settingsStore.settings.shortcutPreset.title,
            openAbout: { [weak self] in
                Task { @MainActor in
                    self?.showAboutPanel()
                }
            },
            openSettings: { [weak self] in
                Task { @MainActor in
                    self?.showSettingsWindow()
                }
            },
            openHistory: { [weak self] in
                Task { @MainActor in
                    self?.showHistoryWindow()
                }
            },
            checkForUpdates: { [weak self] in
                Task { @MainActor in
                    self?.updateService?.checkForUpdates()
                }
            },
            toggleMonitoring: { [weak self] in
                Task { @MainActor in
                    self?.toggleMonitoring()
                }
            },
            clearHistory: { [weak self] in
                Task { @MainActor in
                    self?.clearHistory()
                }
            },
            selectRecentItem: { [weak self] item in
                Task { @MainActor in
                    self?.copyRecentItem(item)
                }
            },
            quit: {
                NSApp.terminate(nil)
            }
        )
        self.menuBarController = menuBarController

        let hotkeyManager = HotkeyManager { [weak self] in
            Task { @MainActor in
                self?.historyWindowController?.toggleWindowVisibility()
            }
        }
        hotkeyManager.register(shortcut: settingsStore.settings.shortcutPreset)
        self.hotkeyManager = hotkeyManager

        observeState()
        updateService.scheduleAutomaticChecks()

        if settingsStore.settings.openWindowOnLaunch {
            showHistoryWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        historyStore.persistNow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showHistoryWindow()
        return true
    }

    @objc
    private func showAboutPanelAction(_ sender: Any?) {
        showAboutPanel()
    }

    @objc
    private func openSettingsAction(_ sender: Any?) {
        showSettingsWindow()
    }

    @objc
    private func checkForUpdatesAction(_ sender: Any?) {
        updateService?.checkForUpdates()
    }

    @objc
    private func terminateApplicationAction(_ sender: Any?) {
        NSApp.terminate(sender)
    }

    private func showHistoryWindow() {
        historyWindowController?.showWindow(nil)
    }

    private func showSettingsWindow() {
        settingsWindowController?.showWindow(nil)
    }

    private func showAboutPanel() {
        var options: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: AppMetadata.displayName,
            .applicationVersion: AppMetadata.currentVersionString,
            .version: AppMetadata.currentVersionString,
            .credits: NSAttributedString(
                string: "Contact\n\(AppMetadata.supportEmail)",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12),
                    .foregroundColor: NSColor.secondaryLabelColor,
                ]
            ),
        ]

        if let applicationIcon = NSApp.applicationIconImage {
            options[.applicationIcon] = applicationIcon
        }

        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: options)
    }

    private func toggleMonitoring() {
        guard let clipboardMonitor else {
            return
        }

        if clipboardMonitor.isRunning {
            clipboardMonitor.stop()
        } else {
            clipboardMonitor.start()
        }

        menuBarController?.updateMonitoringState(isEnabled: clipboardMonitor.isRunning)
    }

    private func clearHistory() {
        historyStore.clearAll()
    }

    private func copyRecentItem(_ item: ClipboardItem) {
        guard
            pasteService.restore(
                item: item,
                autoPaste: false,
                feedbackMessage: "복사되었습니다"
            )
        else {
            return
        }

        historyStore.markItemAsUsed(item)
    }

    private func observeState() {
        settingsStore.$settings
            .sink { [weak self] settings in
                guard let self else {
                    return
                }

                historyStore.configure(maxItems: settings.maxHistoryCount)
                hotkeyManager?.register(shortcut: settings.shortcutPreset)
                menuBarController?.updateShortcutTitle(settings.shortcutPreset.title)
                updateService?.scheduleAutomaticChecks()
                launchAtLoginManager.setEnabled(settings.launchAtLoginEnabled)
                applyAppearancePreference(settings.appearancePreference)
            }
            .store(in: &cancellables)

        historyStore.$items
            .sink { [weak self] items in
                self?.menuBarController?.updateRecentItems(items)
            }
            .store(in: &cancellables)
    }

    private func applyAppearancePreference(_ preference: AppearancePreference) {
        let appearance: NSAppearance? = switch preference {
        case .system:
            nil
        case .light:
            NSAppearance(named: .aqua)
        case .dark:
            NSAppearance(named: .darkAqua)
        }

        NSApp.appearance = appearance
        historyWindowController?.window?.appearance = appearance
        settingsWindowController?.window?.appearance = appearance
    }

    private func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu(title: "Main Menu")

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: AppMetadata.displayName)
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let aboutItem = NSMenuItem(
            title: "About \(AppMetadata.displayName)",
            action: #selector(showAboutPanelAction(_:)),
            keyEquivalent: ""
        )
        aboutItem.target = self
        appMenu.addItem(aboutItem)

        appMenu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettingsAction(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        appMenu.addItem(settingsItem)

        let updatesItem = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdatesAction(_:)),
            keyEquivalent: ""
        )
        updatesItem.target = self
        appMenu.addItem(updatesItem)

        appMenu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit \(AppMetadata.displayName)",
            action: #selector(terminateApplicationAction(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        quitItem.keyEquivalentModifierMask = [.command]
        appMenu.addItem(quitItem)

        return mainMenu
    }
}
