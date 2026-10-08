import AppKit
import UniformTypeIdentifiers

@MainActor final class PlantUMLPlugin {
    let panel: PlantUMLPanel
    private let host: DuckpadHost
    private let strings: PlantUMLStrings
    private let connection = PlantUMLConnection()
    private let settingsArchive: URL
    private let runtimeSettings: PlantUMLSettings
    private var closeMonitor: Any?
    private var activePicker: NSSavePanel?
    private var task: Task<Void, Never>?
    private var active = true
    private var generation: UInt64 = 0
    private var previewSource: String?
    private var png: Data?
    private var image: NSImage?
    private var viewer: PlantUMLPreviewWindow?
    init(host: DuckpadHost, config: [String: String]) {
        self.host = host
        strings = PlantUMLStrings(directory: URL(fileURLWithPath: config["resourceDirectory"] ?? ""), language: config["language"] ?? "en")
        let storage = URL(fileURLWithPath: config["storageDirectory"] ?? "")
        settingsArchive = storage.appendingPathComponent("paths.json")
        runtimeSettings = PlantUMLSettings(strings: strings)
        panel = PlantUMLPanel(strings: strings)
        if let bytes = try? Data(contentsOf: settingsArchive), let paths = try? JSONDecoder().decode([String: String].self, from: bytes) {
            runtimeSettings.java.stringValue = paths["java"] ?? ""; runtimeSettings.jar.stringValue = paths["jar"] ?? ""
        }
        panel.onRender = { [weak self] in self?.renderDocument() }
        panel.onOpen = { [weak self] in self?.openFile() }
        panel.onSettings = { [weak self] in self?.runtimeSettings.showWindow(nil) }
        runtimeSettings.onSetup = { [weak self] in self?.setup() }
        runtimeSettings.onChange = { [weak self] in
            guard let self else { return }
            do { try self.persistPaths() } catch { self.fail("settingsFailed") }
        }
        panel.onExport = { [weak self] format in self?.export(format) }
        panel.onExpand = { [weak self] in self?.expand() }
        panel.onClose = { [weak self] in self?.hide() }
        closeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.active, self.panel.window != nil, event.window === self.panel.window,
                  // IMEs can report a localized character (e.g. Korean ㅈ) for the W key.
                  (event.keyCode == 13 || event.charactersIgnoringModifiers?.lowercased() == "w"),
                  event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.capsLock, .numericPad]) == .control else { return event }
            self.hide(); return nil
        }
        panel.setStatus(strings.text("Open a PlantUML document, then preview it."))
    }
    func show() -> NSView {
        generation &+= 1; task?.cancel(); task = nil; connection.close()
        cancelPicker()
        panel.setBusy(false, hasImage: image != nil); runtimeSettings.setBusy(false)
        panel.setStatus(strings.text(image == nil ? "Open a PlantUML document, then preview it." : "Ready"))
        return panel
    }
    func setLanguage(_ code: String) {
        strings.language = code; panel.refreshLocalization(); runtimeSettings.refreshLocalization(); viewer?.preview.refreshLocalization()
        if task == nil { panel.setStatus(strings.text(image == nil ? "Open a PlantUML document, then preview it." : "Ready")) }
    }
    func stop() {
        active = false; generation &+= 1; task?.cancel(); task = nil; connection.close()
        cancelPicker()
        viewer?.close(); viewer = nil; runtimeSettings.close()
        if let closeMonitor { NSEvent.removeMonitor(closeMonitor) }; closeMonitor = nil
        runtimeSettings.onSetup = nil; runtimeSettings.onChange = nil
        panel.onRender = nil; panel.onOpen = nil; panel.onSettings = nil; panel.onExport = nil; panel.onExpand = nil; panel.onClose = nil
    }
    private func cancelPicker() {
        let picker = activePicker; activePicker = nil; picker?.cancel(nil)
    }
    private func hide() {
        generation &+= 1; task?.cancel(); task = nil; connection.close()
        cancelPicker(); runtimeSettings.close()
        panel.setBusy(false, hasImage: image != nil); runtimeSettings.setBusy(false)
        host.closePanel()
    }
    private func renderDocument() {
        guard let source = host.documentText() else { panel.setStatus(strings.text("Document unavailable or larger than 512 KiB."), error: true); return }
        render(source, install: false)
    }
    private func setup() {
        runtimeSettings.java.stringValue = ""; runtimeSettings.jar.stringValue = ""
        render("@startuml\nAlice -> Bob: Ready\n@enduml", install: true)
    }
    private func persistPaths() throws {
        try FileManager.default.createDirectory(at: settingsArchive.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(["java": runtimeSettings.java.stringValue, "jar": runtimeSettings.jar.stringValue])
        try data.write(to: settingsArchive, options: .atomic)
    }
    private func render(_ source: String, install: Bool) {
        guard active else { return }
        do { try persistPaths() } catch { fail("settingsFailed"); return }
        cancelPicker()
        generation &+= 1; let token = generation
        task?.cancel(); connection.close()
        image = nil; png = nil; previewSource = nil; panel.preview.display(nil); viewer?.preview.display(nil)
        panel.setBusy(true, hasImage: false); runtimeSettings.setBusy(true)
        panel.setStatus(strings.text(install ? "Downloading and verifying the runtime…" : "Rendering locally…"))
        let request = PlantUMLRequest(source: source, javaPath: runtimeSettings.java.stringValue, jarPath: runtimeSettings.jar.stringValue, install: install)
        task = Task { [weak self] in
            guard let self, self.active, self.generation == token, !Task.isCancelled else { return }
            defer { if self.generation == token { self.task = nil; self.panel.setBusy(false, hasImage: self.image != nil); self.runtimeSettings.setBusy(false) } }
            do {
                let bytes = try await self.connection.render(request)
                guard self.active, self.generation == token, !Task.isCancelled else { return }
                guard let bitmap = NSBitmapImageRep(data: bytes), let result = NSImage(data: bytes) else { self.fail("renderFailed"); return }
                result.size = NSSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
                self.png = bytes; self.image = result; self.previewSource = source
                self.panel.preview.display(result)
                self.viewer?.preview.display(result)
                self.panel.setStatus(String(format: self.strings.text("Ready · %d × %d"), bitmap.pixelsWide, bitmap.pixelsHigh))
            } catch {
                guard self.active, self.generation == token, !Task.isCancelled else { return }
                self.report(error)
            }
        }
    }
    private func openFile() {
        let picker = NSOpenPanel(); picker.allowsMultipleSelection = false
        picker.canChooseFiles = true; picker.canChooseDirectories = false
        picker.allowedContentTypes = [UTType(filenameExtension: "puml") ?? .plainText,
                                      UTType(filenameExtension: "plantuml") ?? .plainText, .plainText]
        let pickerToken = generation; activePicker = picker
        picker.begin { [weak self] response in
            guard let self, self.active, self.generation == pickerToken, self.activePicker === picker else { return }
            self.activePicker = nil
            guard response == .OK, let url = picker.url else { return }
            do {
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
                guard size <= 512 * 1024 else { self.fail("invalidInput"); return }
                self.render(try String(contentsOf: url, encoding: .utf8), install: false)
            } catch { self.fail("fileFailed") }
        }
    }
    private func export(_ format: String) {
        guard let source = previewSource, let png else { return }
        let picker = NSSavePanel(); picker.nameFieldStringValue = "diagram." + format
        picker.allowedContentTypes = [format == "png" ? .png : .svg]
        let pickerToken = generation; activePicker = picker
        picker.begin { [weak self] response in
            guard let self, self.active, self.generation == pickerToken, self.activePicker === picker else { return }
            self.activePicker = nil
            guard response == .OK, let url = picker.url else { return }
            self.panel.setBusy(true, hasImage: true); self.runtimeSettings.setBusy(true)
            let token = self.generation
            let request = PlantUMLRequest(source: source, format: format, javaPath: self.runtimeSettings.java.stringValue, jarPath: self.runtimeSettings.jar.stringValue)
            self.task = Task { [weak self] in
                guard let self, self.active, self.generation == token, !Task.isCancelled else { return }
                defer { if self.generation == token { self.task = nil; self.panel.setBusy(false, hasImage: self.image != nil); self.runtimeSettings.setBusy(false) } }
                do {
                    let data = format == "png" ? png : try await self.connection.render(request)
                    guard self.active, self.generation == token, !Task.isCancelled else { return }
                    try data.write(to: url, options: .atomic)
                    self.panel.setStatus(self.strings.text("Saved"))
                } catch { if self.active, self.generation == token { self.fail("fileFailed") } }
            }
        }
    }
    private func expand() {
        guard let image else { return }
        if viewer == nil { viewer = PlantUMLPreviewWindow(strings: strings) }
        viewer?.display(image)
    }
    private func report(_ error: any Error) {
        let text = (error as NSError).localizedDescription
        if let bytes = text.data(using: .utf8), let fields = try? JSONSerialization.jsonObject(with: bytes) as? [String: String] {
            fail(fields["code"] ?? "renderFailed", detail: fields["detail"] ?? "")
        } else { fail(text) }
    }
    private func fail(_ code: String, detail: String = "") {
        let keys = [
            "missingJava": "Java not found. Use automatic setup or enter an offline Java path.",
            "missingJar": "PlantUML not found. Use automatic setup or enter an offline JAR path.",
            "invalidJava": "Choose a Java 11+ home or its bin/java executable.",
            "invalidInput": "Use one complete @startuml…@enduml diagram, up to 512 KiB.",
            "checksum": "Runtime verification failed. Use an official PlantUML 1.2026.8 JAR.",
            "downloadFailed": "Download failed. Retry or configure offline paths.",
            "timeout": "Rendering exceeded its time or output limit.",
            "busy": "The renderer is busy. Try again shortly.",
            "settingsFailed": "Could not save runtime paths.",
            "fileFailed": "Could not read or save the file.",
            "renderFailed": "Rendering failed. Check the diagram and runtime paths."
        ]
        let message = strings.text(keys[code] ?? keys["renderFailed"]!)
        panel.setStatus(detail.isEmpty ? message : message + "\n" + detail, error: true)
    }
}
