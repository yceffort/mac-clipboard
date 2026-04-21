import AppKit
import SwiftUI

struct HistoryWindowView: View {
    @ObservedObject var historyStore: HistoryStore
    @ObservedObject var settingsStore: AppSettingsStore
    @ObservedObject var pasteService: PasteService

    @State private var query = ""
    @State private var debouncedQuery = ""
    @State private var selection: ClipboardItem.ID?
    @State private var isShowingClearConfirmation = false

    private static let searchDebounceInterval: Duration = .milliseconds(150)

    private var filteredItems: [ClipboardItem] {
        historyStore.search(matching: debouncedQuery)
    }

    private var selectedItem: ClipboardItem? {
        if let selection {
            return filteredItems.first(where: { $0.id == selection })
        }

        return filteredItems.first
    }

    private var separatorColor: Color {
        Color(nsColor: .separatorColor).opacity(0.55)
    }

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 330, idealWidth: 360, maxWidth: 420)
                .padding(.trailing, 18)

            previewPane
                .frame(minWidth: 420)
                .padding(.leading, 22)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .frame(minWidth: 900, minHeight: 540)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Clear Clipboard History?", isPresented: $isShowingClearConfirmation) {
            Button("Clear", role: .destructive) {
                clearHistory()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes all saved text and image items from \(AppMetadata.displayName).")
        }
        .task(id: query) {
            try? await Task.sleep(for: Self.searchDebounceInterval)

            guard Task.isCancelled == false else {
                return
            }

            if debouncedQuery != query {
                debouncedQuery = query
            }
        }
        .onAppear {
            adoptFirstSelectionIfNeeded()
            pasteService.refreshAccessibilityPermission()
        }
        .onChange(of: debouncedQuery) { _, _ in
            adoptFirstSelectionIfNeeded()
        }
        .onChange(of: historyStore.items) { _, _ in
            adoptFirstSelectionIfNeeded()
        }
        .onExitCommand {
            closeWindow()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Text("Clipboard")
                    .font(.system(size: 21, weight: .medium))

                Spacer()

                Text("\(filteredItems.count) items")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Button("Clear") {
                    isShowingClearConfirmation = true
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .disabled(historyStore.items.isEmpty)
            }

            TextField("Search text or source app", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(separatorColor, lineWidth: 1)
                )

            ScrollViewReader { proxy in
                List(selection: $selection) {
                    ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                        HistoryRowView(
                            item: item,
                            shortcutHint: index < 9 ? "⌘\(index + 1)" : nil
                        )
                        .tag(item.id)
                        .id(item.id)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .background(
                    TableRowDoubleClickMonitor { rowIndex in
                        guard filteredItems.indices.contains(rowIndex) else {
                            return
                        }

                        let item = filteredItems[rowIndex]
                        selection = item.id
                        performDefaultAction(for: item)
                    }
                )
                .background(
                    QuickPasteKeyMonitor { number in
                        let index = number - 1
                        guard filteredItems.indices.contains(index) else {
                            return
                        }

                        let item = filteredItems[index]
                        selection = item.id
                        performDefaultAction(for: item)
                    }
                )
                .background(
                    EnterKeyMonitor {
                        guard let item = resolvedSelectedItem() else {
                            return
                        }

                        selection = item.id
                        performDefaultAction(for: item)
                    }
                )
                .onAppear {
                    scrollToNewestIfNeeded(using: proxy, animated: false)
                }
                .onChange(of: historyStore.items.first?.id) { _, _ in
                    scrollToNewestIfNeeded(using: proxy, animated: true)
                }
                .onChange(of: debouncedQuery) { _, _ in
                    if normalizedQuery.isEmpty {
                        scrollToNewestIfNeeded(using: proxy, animated: false)
                    }
                }
            }

            Text("Press Enter for the selected item, or ⌘1–⌘9 for the top nine.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var previewPane: some View {
        if let item = selectedItem {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 18) {
                        metadataLine(for: item)
                        Spacer()
                        HStack(spacing: 8) {
                            Button(role: .destructive) {
                                delete(item)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                            .foregroundStyle(.red)
                            .help("Delete this clipboard item")

                            Button(item.isPinned ? "Unpin" : "Pin") {
                                historyStore.togglePinned(item)
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.small)

                            Button(defaultActionTitle) {
                                performDefaultAction(for: item)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button(secondaryActionTitle) {
                                performSecondaryAction(for: item)
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                        }
                    }

                    Divider()

                    if pasteService.canAutoPaste == false {
                        Button("Enable Accessibility") {
                            pasteService.openAccessibilitySettings()
                        }
                        .buttonStyle(.link)
                        .font(.system(size: 11))
                    }

                    previewContent(for: item)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 2)
            }
        } else {
            ContentUnavailableView(
                "No Clipboard Items Yet",
                systemImage: "doc.on.clipboard",
                description: Text("Copy text or an image, then open this window again.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func resolvedSelectedItem() -> ClipboardItem? {
        let items = filteredItems

        if let selection, let match = items.first(where: { $0.id == selection }) {
            return match
        }

        return items.first
    }

    private func adoptFirstSelectionIfNeeded() {
        guard let currentSelection = selection else {
            selection = filteredItems.first?.id
            return
        }

        if filteredItems.contains(where: { $0.id == currentSelection }) == false {
            selection = filteredItems.first?.id
        }
    }

    private var normalizedQuery: String {
        debouncedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var defaultActionTitle: String {
        settingsStore.settings.autoPasteOnSelection ? "Paste" : "Copy"
    }

    private var secondaryActionTitle: String {
        settingsStore.settings.autoPasteOnSelection ? "Copy" : "Paste"
    }

    private func metadataLine(for item: ClipboardItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(item.kindLabel.uppercased())
                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))

                if item.isPinned {
                    Label("Pinned", systemImage: "pin.fill")
                }
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)

            if let sourceAppBundleID = item.sourceAppBundleID {
                Text(sourceAppBundleID)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    @ViewBuilder
    private func previewContent(for item: ClipboardItem) -> some View {
        switch item.kind {
        case .text, .html, .richText:
            previewTextCard(item.textContent ?? "")

        case .image:
            if let imagePath = item.imagePath,
               let image = ClipboardImageCache.shared.image(forPath: imagePath)
            {
                previewSurface {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                ContentUnavailableView(
                    "Image Preview Unavailable",
                    systemImage: "photo",
                    description: Text("The image file could not be loaded from disk.")
                )
            }

        case .url:
            previewTextCard(item.urlString ?? item.textContent ?? "")

        case .file:
            previewSurface {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(item.filePaths, id: \.self) { path in
                        HStack(spacing: 10) {
                            Image(systemName: "doc")
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(URL(fileURLWithPath: path).lastPathComponent)
                                    .font(.system(size: 13, weight: .medium))
                                Text(path)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
            }
        }
    }

    private func previewTextCard(_ text: String) -> some View {
        previewSurface {
            Text(text)
                .font(.system(size: 15))
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    private func previewSurface(@ViewBuilder content: () -> some View) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .textBackgroundColor).opacity(0.35))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(separatorColor, lineWidth: 1)
            )
    }

    private func scrollToNewestIfNeeded(using proxy: ScrollViewProxy, animated: Bool) {
        guard normalizedQuery.isEmpty,
              let newestItemID = filteredItems.first?.id
        else {
            return
        }

        selection = newestItemID

        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo(newestItemID, anchor: .top)
                }
            } else {
                proxy.scrollTo(newestItemID, anchor: .top)
            }
        }
    }

    private func performDefaultAction(for item: ClipboardItem) {
        let shouldAutoPaste = settingsStore.settings.autoPasteOnSelection

        restore(
            item,
            autoPaste: shouldAutoPaste,
            closeWindowOnSuccess: true
        )
    }

    private func performSecondaryAction(for item: ClipboardItem) {
        if settingsStore.settings.autoPasteOnSelection {
            restore(
                item,
                autoPaste: false,
                closeWindowOnSuccess: false
            )
        } else {
            restore(
                item,
                autoPaste: true,
                closeWindowOnSuccess: true
            )
        }
    }

    private func restore(
        _ item: ClipboardItem,
        autoPaste: Bool,
        closeWindowOnSuccess: Bool = false
    ) {
        guard
            pasteService.restore(
                item: item,
                autoPaste: autoPaste
            )
        else {
            return
        }

        if closeWindowOnSuccess {
            NSApp.keyWindow?.orderOut(nil)
            DispatchQueue.main.async {
                historyStore.markItemAsUsed(item)
            }
        } else {
            historyStore.markItemAsUsed(item)
        }
    }

    private func clearHistory() {
        historyStore.clearAll()
        selection = nil
    }

    private func delete(_ item: ClipboardItem) {
        guard historyStore.remove(item) else {
            return
        }

        if selection == item.id {
            selection = nil
            adoptFirstSelectionIfNeeded()
        }
    }

    private func closeWindow() {
        NSApp.keyWindow?.orderOut(nil)
    }
}
