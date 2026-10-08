import AppKit
import DuckpadNativeABI

/// Separate AppKit test process: no user documents, installed packages or Java.
@main @MainActor final class PreviewSmoke: NSObject, NSApplicationDelegate {
    private var plugin: PlantUMLPlugin?
    private var window: NSWindow?
    private var closed = false
    static func main() {
        let app = NSApplication.shared
        let delegate = PreviewSmoke(); app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        var api = DuckpadHostV1()
        api.abi_version = 1; api.struct_size = UInt32(MemoryLayout<DuckpadHostV1>.size)
        api.context = Unmanaged.passUnretained(self).toOpaque()
        api.close_panel = { context in
            guard let context else { return }
            let address = UInt(bitPattern: context)
            MainActor.assumeIsolated {
                let owner = Unmanaged<PreviewSmoke>.fromOpaque(UnsafeMutableRawPointer(bitPattern: address)!).takeUnretainedValue()
                owner.closed = true; owner.plugin?.panel.removeFromSuperview()
            }
        }
        guard let host = DuckpadHost(&api) else { fatalError("Host ABI") }
        let storage = FileManager.default.temporaryDirectory.appendingPathComponent("plantuml-ui-" + UUID().uuidString)
        plugin = PlantUMLPlugin(host: host, config: ["resourceDirectory": Bundle.main.resourceURL!.path,
                                                  "storageDirectory": storage.path, "language": "ko"])
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 720),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "PlantUML UI smoke"; window.contentView = plugin?.show()
        self.window = window; window.center(); window.makeKeyAndOrderFront(nil)
        plugin?.panel.onSettings?()
        precondition(NSApp.windows.contains { $0.isVisible && $0.title == "런타임 설정…" })
        NSApp.windows.filter { $0 !== window }.forEach { $0.orderOut(nil) }
        window.makeKeyAndOrderFront(nil)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            for language in ["en", "ko", "ja", "zh-Hans", "de", "fr", "it", "pt-BR"] {
                self.plugin?.setLanguage(language)
                for width: CGFloat in [300, 560] {
                    window.setContentSize(NSSize(width: width, height: 720))
                    window.contentView?.layoutSubtreeIfNeeded()
                    guard let panel = self.plugin?.panel else { fatalError("Missing panel") }
                    precondition(panel.bounds.height - panel.preview.frame.maxY <= 90, "Controls must stay compact in every locale")
                    @MainActor func checkControls(_ view: NSView) {
                        if let button = view as? NSButton {
                            let frame = button.convert(button.bounds, to: panel)
                            precondition(frame.minX >= 0 && frame.maxX <= panel.bounds.width + 1, "Translated controls must stay inside the narrow panel")
                        }
                        for child in view.subviews { checkControls(child) }
                    }
                    checkControls(panel)
                }
            }
            print("Compact controls fit 300/560-point panels in all eight locales")
            for character in ["w", "ㅈ", "\u{17}"] {
                self.closed = false; window.contentView = self.plugin?.show()
                let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .control,
                                            timestamp: 0, windowNumber: window.windowNumber, context: nil,
                                            characters: character, charactersIgnoringModifiers: character, isARepeat: false, keyCode: 13)!
                NSApp.postEvent(event, atStart: false)
                try? await Task.sleep(for: .milliseconds(200))
                precondition(self.closed && self.plugin?.panel.window == nil, "Ctrl+W must close only the dock with English or Korean input")
                precondition(window.isVisible, "Editor window must remain open")
            }
            self.plugin?.stop(); self.plugin?.stop()
            try? FileManager.default.removeItem(at: storage)
            print("Localized separate runtime settings, Ctrl+W dock close and idempotent teardown passed")
            NSApp.terminate(nil)
        }
    }
}
