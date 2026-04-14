import Carbon.HIToolbox
import Combine
import Foundation

enum ShortcutPreset: String, CaseIterable, Codable, Identifiable {
    case commandShiftV
    case commandOptionV
    case commandShiftSpace
    case optionSpace

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .commandShiftV:
            "Cmd + Shift + V"
        case .commandOptionV:
            "Cmd + Option + V"
        case .commandShiftSpace:
            "Cmd + Shift + Space"
        case .optionSpace:
            "Option + Space"
        }
    }

    var keyCode: UInt32 {
        switch self {
        case .commandShiftV, .commandOptionV:
            UInt32(kVK_ANSI_V)
        case .commandShiftSpace, .optionSpace:
            UInt32(kVK_Space)
        }
    }

    var modifiers: UInt32 {
        switch self {
        case .commandShiftV, .commandShiftSpace:
            UInt32(cmdKey | shiftKey)
        case .commandOptionV:
            UInt32(cmdKey | optionKey)
        case .optionSpace:
            UInt32(optionKey)
        }
    }
}

enum AppearancePreference: String, CaseIterable, Codable, Identifiable {
    case system
    case light
    case dark

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .system:
            "System"
        case .light:
            "Light"
        case .dark:
            "Dark"
        }
    }
}

enum IgnoredAppPreset: String, CaseIterable, Identifiable {
    case onePassword
    case bitwarden
    case terminal
    case iTerm

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .onePassword:
            "1Password"
        case .bitwarden:
            "Bitwarden"
        case .terminal:
            "Terminal"
        case .iTerm:
            "iTerm"
        }
    }

    var detail: String {
        switch self {
        case .onePassword:
            "Ignore copies made while 1Password is frontmost."
        case .bitwarden:
            "Ignore copies made while Bitwarden is frontmost."
        case .terminal:
            "Ignore copies made while Terminal is frontmost."
        case .iTerm:
            "Ignore copies made while iTerm is frontmost."
        }
    }

    var bundleIDs: [String] {
        switch self {
        case .onePassword:
            [
                "com.1password.1password",
                "com.agilebits.onepassword7",
            ]
        case .bitwarden:
            [
                "com.bitwarden.desktop",
            ]
        case .terminal:
            [
                "com.apple.Terminal",
            ]
        case .iTerm:
            [
                "com.googlecode.iterm2",
            ]
        }
    }
}

struct AppSettings: Codable {
    var maxHistoryCount: Int = 200
    var autoPasteOnSelection: Bool = false
    var openWindowOnLaunch: Bool = true
    var launchAtLoginEnabled: Bool = false
    var appearancePreference: AppearancePreference = .system
    var automaticUpdateChecksEnabled: Bool = true
    var lastUpdateCheckDate: Date?
    var dismissedUpdateVersion: String?
    var privateModeEnabled: Bool = false
    var ignoredAppBundleIDs: [String] = []
    var shortcutPreset: ShortcutPreset = .commandShiftV
}

struct AppSettingsPersistence {
    func load() -> AppSettings {
        let fileURL = AppPaths.settingsFileURL()

        guard let data = try? Data(contentsOf: fileURL) else {
            return AppSettings()
        }

        return (try? JSONDecoder().decode(AppSettings.self, from: data)) ?? AppSettings()
    }

    func save(_ settings: AppSettings) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        try data.write(to: AppPaths.settingsFileURL(), options: .atomic)
    }
}

@MainActor
final class AppSettingsStore: ObservableObject {
    @Published var settings: AppSettings {
        didSet {
            try? persistence.save(settings)
        }
    }

    private let persistence: AppSettingsPersistence

    init(persistence: AppSettingsPersistence = AppSettingsPersistence()) {
        self.persistence = persistence
        settings = persistence.load()
    }

    func isIgnored(_ preset: IgnoredAppPreset) -> Bool {
        let ignored = Set(settings.ignoredAppBundleIDs)
        return preset.bundleIDs.allSatisfy(ignored.contains)
    }

    func setIgnored(_ preset: IgnoredAppPreset, enabled: Bool) {
        var ignored = Set(settings.ignoredAppBundleIDs)

        if enabled {
            for bundleID in preset.bundleIDs {
                ignored.insert(bundleID)
            }
        } else {
            for bundleID in preset.bundleIDs {
                ignored.remove(bundleID)
            }
        }

        settings.ignoredAppBundleIDs = ignored.sorted()
    }

    func shouldIgnore(bundleID: String?) -> Bool {
        guard let bundleID else {
            return false
        }

        return settings.ignoredAppBundleIDs.contains(bundleID)
    }

    func recordUpdateCheck(_ date: Date) {
        settings.lastUpdateCheckDate = date
    }

    func dismissUpdateVersion(_ version: String?) {
        settings.dismissedUpdateVersion = version
    }
}
