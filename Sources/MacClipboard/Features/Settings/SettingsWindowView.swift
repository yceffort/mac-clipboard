import SwiftUI

struct SettingsWindowView: View {
    @ObservedObject var settingsStore: AppSettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Settings")
                    .font(.system(size: 22, weight: .medium))

                section("General", detail: "Tune how clipboard selections behave by default.") {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("History limit")
                            Spacer()
                            Stepper(
                                value: Binding(
                                    get: { settingsStore.settings.maxHistoryCount },
                                    set: { settingsStore.settings.maxHistoryCount = max(20, $0) }
                                ),
                                in: 20 ... 1000,
                                step: 10
                            ) {
                                Text("\(settingsStore.settings.maxHistoryCount) items")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 220, alignment: .trailing)
                            .controlSize(.small)
                        }

                        Divider()

                        HStack {
                            Text("Appearance")
                            Spacer()
                            Picker(
                                "Appearance",
                                selection: Binding(
                                    get: { settingsStore.settings.appearancePreference },
                                    set: { settingsStore.settings.appearancePreference = $0 }
                                )
                            ) {
                                ForEach(AppearancePreference.allCases) { preference in
                                    Text(preference.title).tag(preference)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 220)
                            .labelsHidden()
                        }

                        Divider()

                        Toggle(
                            "Use Paste as the default action for double-click and Enter",
                            isOn: Binding(
                                get: { settingsStore.settings.autoPasteOnSelection },
                                set: { settingsStore.settings.autoPasteOnSelection = $0 }
                            )
                        )

                        Divider()

                        Toggle(
                            "Open the clipboard window when the app launches",
                            isOn: Binding(
                                get: { settingsStore.settings.openWindowOnLaunch },
                                set: { settingsStore.settings.openWindowOnLaunch = $0 }
                            )
                        )

                        Divider()

                        Toggle(
                            "Launch automatically when you log in to macOS",
                            isOn: Binding(
                                get: { settingsStore.settings.launchAtLoginEnabled },
                                set: { settingsStore.settings.launchAtLoginEnabled = $0 }
                            )
                        )
                    }
                }

                Divider()

                section("Updates", detail: "Keep the app aligned with the latest GitHub release.") {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Current version")
                            Spacer()
                            Text(AppMetadata.currentVersionString)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        Toggle(
                            "Check GitHub Releases for updates automatically once a day",
                            isOn: Binding(
                                get: { settingsStore.settings.automaticUpdateChecksEnabled },
                                set: { settingsStore.settings.automaticUpdateChecksEnabled = $0 }
                            )
                        )

                        Divider()

                        if let lastUpdateCheckDate = settingsStore.settings.lastUpdateCheckDate {
                            Text("Last checked: \(lastUpdateCheckDate.formatted(date: .abbreviated, time: .shortened))")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("No update checks have been recorded yet.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider()

                section("Privacy", detail: "Skip sensitive apps or pause capture entirely.") {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle(
                            "Private Mode",
                            isOn: Binding(
                                get: { settingsStore.settings.privateModeEnabled },
                                set: { settingsStore.settings.privateModeEnabled = $0 }
                            )
                        )

                        Text("When Private Mode is on, new clipboard copies are not saved to history.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        Divider()

                        ForEach(Array(IgnoredAppPreset.allCases.enumerated()), id: \.element.id) { index, preset in
                            Toggle(
                                isOn: Binding(
                                    get: { settingsStore.isIgnored(preset) },
                                    set: { settingsStore.setIgnored(preset, enabled: $0) }
                                )
                            ) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.title)
                                    Text(preset.detail)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if index < IgnoredAppPreset.allCases.count - 1 {
                                Divider()
                            }
                        }
                    }
                }

                Divider()

                section("Shortcut", detail: "Pick the global key combination that opens the history window.") {
                    Picker(
                        "Global shortcut",
                        selection: Binding(
                            get: { settingsStore.settings.shortcutPreset },
                            set: { settingsStore.settings.shortcutPreset = $0 }
                        )
                    ) {
                        ForEach(ShortcutPreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 240, alignment: .leading)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func section(
        _ title: String,
        detail: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            content()
        }
    }
}
