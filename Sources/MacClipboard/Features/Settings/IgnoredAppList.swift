import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct IgnoredAppList: View {
    @ObservedObject var settingsStore: AppSettingsStore

    private var ignoredBundleIDs: [String] {
        settingsStore.settings.ignoredAppBundleIDs
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Ignored apps")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Button("Add app…") {
                    presentAppPicker()
                }
                .controlSize(.small)
            }

            if ignoredBundleIDs.isEmpty {
                Text("Pick any .app to stop capturing its copies. Bundle identifier is resolved automatically.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(ignoredBundleIDs, id: \.self) { bundleID in
                        IgnoredAppRow(
                            bundleID: bundleID,
                            onRemove: {
                                settingsStore.removeIgnoredApp(bundleID: bundleID)
                            }
                        )

                        if bundleID != ignoredBundleIDs.last {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func presentAppPicker() {
        let panel = NSOpenPanel()
        panel.title = "Choose an app to exclude"
        panel.prompt = "Exclude"
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        guard panel.runModal() == .OK,
              let url = panel.url,
              let bundleID = Bundle(url: url)?.bundleIdentifier,
              bundleID.isEmpty == false
        else {
            return
        }

        settingsStore.addIgnoredApp(bundleID: bundleID)
    }
}

private struct IgnoredAppRow: View {
    let bundleID: String
    let onRemove: () -> Void

    private var resolved: ResolvedApp {
        ResolvedApp.resolve(bundleID: bundleID)
    }

    var body: some View {
        HStack(spacing: 10) {
            if let icon = resolved.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 22, height: 22)
            } else {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .overlay {
                        Image(systemName: "app.dashed")
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 22, height: 22)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(resolved.displayName)
                    .font(.system(size: 13))
                Text(bundleID)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button(role: .destructive) {
                onRemove()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .foregroundStyle(.red)
            .help("Remove from ignore list")
        }
        .padding(.vertical, 6)
    }
}

private struct ResolvedApp {
    let displayName: String
    let icon: NSImage?

    static func resolve(bundleID: String) -> ResolvedApp {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return ResolvedApp(displayName: bundleID, icon: nil)
        }

        let infoDictionary = Bundle(url: url)?.infoDictionary
        let name = (infoDictionary?["CFBundleDisplayName"] as? String)
            ?? (infoDictionary?["CFBundleName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent

        let icon = NSWorkspace.shared.icon(forFile: url.path)
        return ResolvedApp(displayName: name, icon: icon)
    }
}
