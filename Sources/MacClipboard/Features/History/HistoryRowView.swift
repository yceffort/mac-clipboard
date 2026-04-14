import AppKit
import SwiftUI

struct HistoryRowView: View {
    let item: ClipboardItem

    private var separatorColor: Color {
        Color(nsColor: .separatorColor).opacity(0.5)
    }

    var body: some View {
        HStack(spacing: 10) {
            thumbnail

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.displayTitle)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)

                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Text(item.displaySubtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(item.effectiveSortDate.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var thumbnail: some View {
        switch item.kind {
        case .text, .url, .file, .html, .richText:
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .windowBackgroundColor))
                .overlay {
                    Image(systemName: item.symbolName)
                        .foregroundStyle(.secondary)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(separatorColor, lineWidth: 1)
                }
                .frame(width: 36, height: 36)

        case .image:
            if let imagePath = item.imagePath,
               let image = NSImage(contentsOfFile: imagePath)
            {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(separatorColor, lineWidth: 1)
                    }
                    .frame(width: 36, height: 36)
            }
        }
    }
}
