import AppKit
import Foundation

private struct GitHubReleaseAsset: Decodable {
    let name: String
    let browserDownloadURL: URL

    private enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: URL
    let assets: [GitHubReleaseAsset]

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case assets
    }

    var versionString: String {
        tagName.replacingOccurrences(of: "v", with: "", options: [.anchored, .caseInsensitive])
    }

    func preferredDownloadURL() -> URL? {
        let expectedPrefix = "\(AppMetadata.displayName)-\(versionString)"

        if let preferredDMG = assets.first(where: {
            $0.name == "\(expectedPrefix).dmg"
        }) {
            return preferredDMG.browserDownloadURL
        }

        if let firstDMG = assets.first(where: { $0.name.hasSuffix(".dmg") }) {
            return firstDMG.browserDownloadURL
        }

        if let preferredZip = assets.first(where: {
            $0.name == "\(expectedPrefix).zip"
        }) {
            return preferredZip.browserDownloadURL
        }

        return assets.first(where: { $0.name.hasSuffix(".zip") })?.browserDownloadURL
    }
}

@MainActor
final class UpdateService {
    private let settingsStore: AppSettingsStore
    private let session: URLSession
    private var scheduledCheckTask: Task<Void, Never>?

    init(
        settingsStore: AppSettingsStore,
        session: URLSession = .shared
    ) {
        self.settingsStore = settingsStore
        self.session = session
    }

    func scheduleAutomaticChecks() {
        scheduledCheckTask?.cancel()

        guard settingsStore.settings.automaticUpdateChecksEnabled else {
            return
        }

        let lastCheckDate = settingsStore.settings.lastUpdateCheckDate ?? .distantPast
        let dueDate = lastCheckDate.addingTimeInterval(AppMetadata.updateCheckInterval)
        let delay = max(1, dueDate.timeIntervalSinceNow)
        let delayNanoseconds = UInt64(delay * 1_000_000_000)

        scheduledCheckTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard Task.isCancelled == false else {
                return
            }

            self?.checkForUpdates(userInitiated: false)
        }
    }

    func checkForUpdates(userInitiated: Bool = true) {
        Task {
            await performCheck(userInitiated: userInitiated)
        }
    }

    private func performCheck(userInitiated: Bool) async {
        settingsStore.recordUpdateCheck(Date())

        do {
            let release = try await fetchLatestRelease()
            guard
                let currentVersion = AppVersion(AppMetadata.currentVersionString),
                let latestVersion = AppVersion(release.versionString)
            else {
                if userInitiated {
                    showInformationalAlert(
                        title: "Unable to Compare Versions",
                        message: "The update feed was reachable, but the app could not compare versions."
                    )
                }
                scheduleAutomaticChecks()
                return
            }

            if latestVersion > currentVersion {
                let shouldPrompt =
                    userInitiated || settingsStore.settings.dismissedUpdateVersion != latestVersion.description

                if shouldPrompt {
                    presentUpdateAlert(
                        release: release,
                        currentVersion: currentVersion.description,
                        latestVersion: latestVersion.description
                    )
                }
            } else if userInitiated {
                showInformationalAlert(
                    title: "You're Up to Date",
                    message: "\(AppMetadata.displayName) \(currentVersion.description) is the latest available version."
                )
            }
        } catch {
            if userInitiated {
                showInformationalAlert(
                    title: "Update Check Failed",
                    message: "The app could not reach GitHub Releases right now. Please try again later."
                )
            }
        }

        scheduleAutomaticChecks()
    }

    private func fetchLatestRelease() async throws -> GitHubRelease {
        var request = URLRequest(url: AppMetadata.latestReleaseAPIURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue(AppMetadata.displayName, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard
            let httpResponse = response as? HTTPURLResponse,
            (200 ..< 300).contains(httpResponse.statusCode)
        else {
            throw UpdateCheckError.badServerResponse
        }

        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }

    private func presentUpdateAlert(
        release: GitHubRelease,
        currentVersion: String,
        latestVersion: String
    ) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Update Available"
        alert.informativeText =
            "\(AppMetadata.displayName) \(latestVersion) is available. You're currently on \(currentVersion)."
        alert.addButton(withTitle: release.preferredDownloadURL() == nil ? "View Release" : "Download DMG")
        alert.addButton(withTitle: "Release Notes")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn:
            if let downloadURL = release.preferredDownloadURL() {
                NSWorkspace.shared.open(downloadURL)
            } else {
                NSWorkspace.shared.open(release.htmlURL)
            }
            settingsStore.dismissUpdateVersion(nil)

        case .alertSecondButtonReturn:
            NSWorkspace.shared.open(release.htmlURL)
            settingsStore.dismissUpdateVersion(nil)

        default:
            settingsStore.dismissUpdateVersion(latestVersion)
        }
    }

    private func showInformationalAlert(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

private enum UpdateCheckError: Error {
    case badServerResponse
}
