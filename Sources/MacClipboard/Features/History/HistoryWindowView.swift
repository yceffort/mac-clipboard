import AppKit
import SwiftUI

struct HistoryWindowView: View {
    @ObservedObject var historyStore: HistoryStore
    @ObservedObject var settingsStore: AppSettingsStore
    let pasteService: PasteService

    @State private var query = ""
    @State private var selection: ClipboardItem.ID?
    @State private var isShowingClearConfirmation = false

    private var filteredItems: [ClipboardItem] {
        historyStore.search(matching: query)
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
                .overlay(alignment: .trailing) {
                    Divider()
                        .padding(.vertical, 2)
                }

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
            Text("This removes all saved text and image items from yceffort Clipboard.")
        }
        .onAppear {
            adoptFirstSelectionIfNeeded()
        }
        .onChange(of: query) { _, _ in
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
                List(filteredItems, selection: $selection) { item in
                    HistoryRowView(item: item)
                        .tag(item.id)
                        .id(item.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selection = item.id
                        }
                        .simultaneousGesture(
                            TapGesture(count: 2)
                                .onEnded {
                                    selection = item.id
                                    performDefaultAction(for: item)
                                }
                        )
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .onAppear {
                    scrollToNewestIfNeeded(using: proxy, animated: false)
                }
                .onChange(of: historyStore.items.first?.id) { _, _ in
                    scrollToNewestIfNeeded(using: proxy, animated: true)
                }
                .onChange(of: query) { _, _ in
                    if normalizedQuery.isEmpty {
                        scrollToNewestIfNeeded(using: proxy, animated: false)
                    }
                }
            }

            Text("Press Enter to use the default action for the selected item.")
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
                            .keyboardShortcut(.defaultAction)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(defaultActionRequiresAccessibilityPermission)
                            .help("Accessibility permission is required to auto-paste into another app.")

                            Button(secondaryActionTitle) {
                                performSecondaryAction(for: item)
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                            .disabled(secondaryActionRequiresAccessibilityPermission)
                            .help("Accessibility permission is required to auto-paste into another app.")
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
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var defaultActionTitle: String {
        settingsStore.settings.autoPasteOnSelection ? "Paste" : "Copy"
    }

    private var secondaryActionTitle: String {
        settingsStore.settings.autoPasteOnSelection ? "Copy" : "Paste"
    }

    private var defaultActionRequiresAccessibilityPermission: Bool {
        settingsStore.settings.autoPasteOnSelection && pasteService.canAutoPaste == false
    }

    private var secondaryActionRequiresAccessibilityPermission: Bool {
        settingsStore.settings.autoPasteOnSelection == false && pasteService.canAutoPaste == false
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
               let image = NSImage(contentsOfFile: imagePath)
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
            feedbackMessage: shouldAutoPaste ? nil : "복사되었습니다",
            closeWindowOnSuccess: true
        )
    }

    private func performSecondaryAction(for item: ClipboardItem) {
        if settingsStore.settings.autoPasteOnSelection {
            restore(
                item,
                autoPaste: false,
                feedbackMessage: "복사되었습니다",
                closeWindowOnSuccess: false
            )
        } else {
            restore(
                item,
                autoPaste: true,
                feedbackMessage: nil,
                closeWindowOnSuccess: true
            )
        }
    }

    private func restore(
        _ item: ClipboardItem,
        autoPaste: Bool,
        feedbackMessage: String? = nil,
        closeWindowOnSuccess: Bool = false
    ) {
        guard
            pasteService.restore(
                item: item,
                autoPaste: autoPaste,
                feedbackMessage: feedbackMessage
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
