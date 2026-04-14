import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    fputs("Usage: swift generate_app_icon.swift <output-directory>\n", stderr)
    exit(1)
}

let outputDirectory = URL(fileURLWithPath: arguments[1], isDirectory: true)
try? FileManager.default.removeItem(at: outputDirectory)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let sizes: [Int] = [16, 32, 128, 256, 512]

for pointSize in sizes {
    try renderIcon(pointSize: pointSize, scale: 1, into: outputDirectory)
    try renderIcon(pointSize: pointSize, scale: 2, into: outputDirectory)
}

func renderIcon(pointSize: Int, scale: Int, into directory: URL) throws {
    let pixelSize = pointSize * scale
    let size = NSSize(width: pixelSize, height: pixelSize)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "IconGeneration", code: 1)
    }

    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "IconGeneration", code: 2)
    }

    NSGraphicsContext.current = context
    defer {
        NSGraphicsContext.restoreGraphicsState()
    }

    NSColor.clear.setFill()
    NSRect(origin: .zero, size: size).fill()

    let outerRect = NSRect(origin: .zero, size: size).insetBy(dx: size.width * 0.04, dy: size.height * 0.04)
    let outerPath = NSBezierPath(
        roundedRect: outerRect,
        xRadius: size.width * 0.21,
        yRadius: size.width * 0.21
    )

    let gradient = NSGradient(
        colors: [
            NSColor(calibratedRed: 0.05, green: 0.31, blue: 0.91, alpha: 1),
            NSColor(calibratedRed: 0.12, green: 0.62, blue: 1.0, alpha: 1),
        ]
    )!
    gradient.draw(in: outerPath, angle: 90)

    let glowPath = NSBezierPath(ovalIn: NSRect(
        x: size.width * 0.08,
        y: size.height * 0.12,
        width: size.width * 0.84,
        height: size.height * 0.46
    ))
    NSColor(calibratedWhite: 1, alpha: 0.16).setFill()
    glowPath.fill()

    let boardRect = NSRect(
        x: size.width * 0.23,
        y: size.height * 0.16,
        width: size.width * 0.54,
        height: size.height * 0.64
    )
    let boardPath = NSBezierPath(
        roundedRect: boardRect,
        xRadius: size.width * 0.12,
        yRadius: size.width * 0.12
    )
    NSColor(calibratedWhite: 1.0, alpha: 0.95).setFill()
    boardPath.fill()

    let sheetRect = boardRect.insetBy(dx: size.width * 0.08, dy: size.height * 0.08)
    let sheetPath = NSBezierPath(
        roundedRect: sheetRect,
        xRadius: size.width * 0.05,
        yRadius: size.width * 0.05
    )
    NSColor(calibratedWhite: 0.96, alpha: 1).setFill()
    sheetPath.fill()

    let clipRect = NSRect(
        x: size.width * 0.37,
        y: size.height * 0.68,
        width: size.width * 0.26,
        height: size.height * 0.11
    )
    let clipPath = NSBezierPath(
        roundedRect: clipRect,
        xRadius: size.width * 0.05,
        yRadius: size.width * 0.05
    )
    NSColor(calibratedRed: 0.02, green: 0.19, blue: 0.66, alpha: 1).setFill()
    clipPath.fill()

    NSColor(calibratedRed: 0.23, green: 0.50, blue: 0.96, alpha: 1).setStroke()
    for index in 0 ..< 4 {
        let y = sheetRect.maxY - size.height * (0.12 + (Double(index) * 0.095))
        let line = NSBezierPath()
        line.lineWidth = max(2, size.width * 0.024)
        line.lineCapStyle = .round
        line.move(to: NSPoint(x: sheetRect.minX + size.width * 0.04, y: y))
        line.line(to: NSPoint(x: sheetRect.maxX - size.width * 0.04, y: y))
        line.stroke()
    }

    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGeneration", code: 1)
    }

    let fileName = scale == 1 ? "icon_\(pointSize)x\(pointSize).png" : "icon_\(pointSize)x\(pointSize)@2x.png"
    try pngData.write(to: directory.appendingPathComponent(fileName))
}
