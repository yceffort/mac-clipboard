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

struct AppSettings: Codable {
    var maxHistoryCount: Int = 200
    var autoPasteOnSelection: Bool = true
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

    func shouldIgnore(bundleID: String?) -> Bool {
        guard let bundleID else {
            return false
        }

        return settings.ignoredAppBundleIDs.contains(bundleID)
    }

    func addIgnoredApp(bundleID: String) {
        let trimmed = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.isEmpty == false else {
            return
        }

        var ignored = Set(settings.ignoredAppBundleIDs)
        ignored.insert(trimmed)
        settings.ignoredAppBundleIDs = ignored.sorted()
    }

    func removeIgnoredApp(bundleID: String) {
        settings.ignoredAppBundleIDs.removeAll { $0 == bundleID }
    }

    func recordUpdateCheck(_ date: Date) {
        settings.lastUpdateCheckDate = date
    }

    func dismissUpdateVersion(_ version: String?) {
        settings.dismissedUpdateVersion = version
    }
}
