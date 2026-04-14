import Darwin
import Foundation

struct LaunchAtLoginManager {
    private let label = "com.yceffort.clipboard.launch-at-login"

    var isEnabled: Bool {
        FileManager.default.fileExists(atPath: launchAgentURL.path)
    }

    func setEnabled(_ enabled: Bool) {
        if enabled {
            try? installLaunchAgent()
        } else {
            removeLaunchAgent()
        }
    }

    private var launchAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(label).plist")
    }

    private func installLaunchAgent() throws {
        guard let appPath = resolveAppPath() else {
            return
        }

        let directoryURL = launchAgentURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [
                "/usr/bin/open",
                appPath,
            ],
            "RunAtLoad": true,
            "KeepAlive": false,
            "LimitLoadToSessionType": [
                "Aqua",
            ],
        ]

        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: launchAgentURL, options: .atomic)
        reloadLaunchAgent()
    }

    private func removeLaunchAgent() {
        unloadLaunchAgent()
        try? FileManager.default.removeItem(at: launchAgentURL)
    }

    private func resolveAppPath() -> String? {
        let currentBundleURL = Bundle.main.bundleURL.standardizedFileURL

        if currentBundleURL.pathExtension == "app" {
            return currentBundleURL.path
        }

        let fileManager = FileManager.default
        let candidateURLs = [
            URL(fileURLWithPath: "/Applications/yceffort Clipboard.app"),
            fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications", isDirectory: true)
                .appendingPathComponent("yceffort Clipboard.app"),
        ]

        return candidateURLs.first(where: { fileManager.fileExists(atPath: $0.path) })?.path
    }

    private func reloadLaunchAgent() {
        unloadLaunchAgent()
        runLaunchctl(arguments: ["bootstrap", "gui/\(getuid())", launchAgentURL.path])
    }

    private func unloadLaunchAgent() {
        runLaunchctl(arguments: ["bootout", "gui/\(getuid())", launchAgentURL.path])
    }

    private func runLaunchctl(arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return
        }
    }
}
