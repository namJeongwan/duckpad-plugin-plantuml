import AppKit

@MainActor final class PlantUMLPreviewWindow: NSWindowController {
    let preview: PlantUMLPreview
    init(strings: PlantUMLStrings) {
        preview = PlantUMLPreview(strings: strings)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 800),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "PlantUML"; window.contentView = preview
        window.minSize = NSSize(width: 500, height: 350)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.center()
    }
    required init?(coder: NSCoder) { nil }
    func display(_ image: NSImage) { preview.display(image); showWindow(nil); window?.makeKeyAndOrderFront(nil) }
}
