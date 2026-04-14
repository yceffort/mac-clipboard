import Foundation

enum AppPaths {
    static func appSupportDirectory() -> URL {
        if let overrideDirectory = ProcessInfo.processInfo.environment["YCEFFORT_CLIPBOARD_APP_SUPPORT_DIR"] {
            let overrideURL = URL(fileURLWithPath: overrideDirectory, isDirectory: true)

            try? FileManager.default.createDirectory(
                at: overrideURL,
                withIntermediateDirectories: true,
                attributes: nil
            )

            return overrideURL
        }

        let baseDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        let appDirectory = baseDirectory.appendingPathComponent(AppMetadata.supportDirectoryName, isDirectory: true)

        try? FileManager.default.createDirectory(
            at: appDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        return appDirectory
    }

    static func historyFileURL() -> URL {
        appSupportDirectory().appendingPathComponent("history.json")
    }

    static func historyDatabaseURL() -> URL {
        appSupportDirectory().appendingPathComponent("history.sqlite")
    }

    static func settingsFileURL() -> URL {
        appSupportDirectory().appendingPathComponent("settings.json")
    }

    static func imagesDirectory() -> URL {
        let directory = appSupportDirectory().appendingPathComponent("Images", isDirectory: true)

        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        return directory
    }

    static func richTextDirectory() -> URL {
        let directory = appSupportDirectory().appendingPathComponent("RichText", isDirectory: true)

        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        return directory
    }
}
