import Foundation

enum AppMetadata {
    static let displayName = "yceffort Clipboard"
    static let supportDirectoryName = "yceffort Clipboard"
    static let repositoryOwner = "yceffort"
    static let repositoryName = "mac-clipboard"
    static let updateCheckInterval: TimeInterval = 60 * 60 * 24

    static var repositoryFullName: String {
        "\(repositoryOwner)/\(repositoryName)"
    }

    static var releasesPageURL: URL {
        URL(string: "https://github.com/\(repositoryFullName)/releases")!
    }

    static var latestReleaseAPIURL: URL {
        URL(string: "https://api.github.com/repos/\(repositoryFullName)/releases/latest")!
    }

    static var currentVersionString: String {
        if let bundleVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String, bundleVersion.isEmpty == false {
            return bundleVersion
        }

        let executableURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        let candidateDirectories = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true),
            executableURL.deletingLastPathComponent(),
            executableURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent(),
        ]

        for directory in candidateDirectories {
            let versionFileURL = directory.appendingPathComponent("version.txt")

            guard
                let versionString = try? String(contentsOf: versionFileURL, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines),
                versionString.isEmpty == false
            else {
                continue
            }

            return versionString
        }

        return "0.1.0"
    }
}
