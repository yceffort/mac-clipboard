import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()

ProcessInfo.processInfo.processName = AppMetadata.displayName
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
