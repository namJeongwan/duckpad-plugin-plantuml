import AppKit
import UniformTypeIdentifiers

@MainActor final class PlantUMLSettings: NSWindowController, NSTextFieldDelegate {
    let java = NSTextField()
    let jar = NSTextField()
    var onSetup: (() -> Void)?
    var onChange: (() -> Void)?
    private let strings: PlantUMLStrings
    private let javaLabel = NSTextField(labelWithString: "")
    private let jarLabel = NSTextField(labelWithString: "")
    private let hint = NSTextField(wrappingLabelWithString: "")
    private var picker: NSOpenPanel?
    private var controls: [(NSButton, String)] = []
    init(strings: PlantUMLStrings) {
        self.strings = strings
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 320),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        func button(_ key: String, _ action: Selector) -> NSButton {
            let control = NSButton(); control.bezelStyle = .rounded
            control.target = self; control.action = action
            controls.append((control, key)); return control
        }
        for field in [java, jar] {
            field.font = .systemFont(ofSize: 12); field.delegate = self
            field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        java.setAccessibilityIdentifier("duckpad.plantuml.java")
        jar.setAccessibilityIdentifier("duckpad.plantuml.jar")
        let javaRow = NSStackView(views: [java, button("Browse…", #selector(browseJava))])
        let jarRow = NSStackView(views: [jar, button("Browse…", #selector(browseJar))])
        hint.font = .systemFont(ofSize: 12); hint.textColor = .secondaryLabelColor
        let setup = button("Set up automatically", #selector(setupRuntime))
        setup.setAccessibilityIdentifier("duckpad.plantuml.setup")
        let rows: [NSView] = [javaLabel, javaRow, jarLabel, jarRow, hint, setup]
        let stack = NSStackView(views: rows)
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView?.addSubview(stack)
        for row in rows { row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
        if let content = window.contentView {
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
                stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
                stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
                stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -20)
            ])
        }
        refreshLocalization(); window.center()
    }
    required init?(coder: NSCoder) { nil }
    override func close() { let previous = picker; picker = nil; previous?.cancel(nil); super.close() }
    func refreshLocalization() {
        window?.title = strings.text("Runtime settings…")
        javaLabel.stringValue = strings.text("Java executable or home")
        jarLabel.stringValue = strings.text("PlantUML JAR")
        java.placeholderString = strings.text("Automatic"); jar.placeholderString = strings.text("Automatic")
        java.setAccessibilityLabel(javaLabel.stringValue); jar.setAccessibilityLabel(jarLabel.stringValue)
        hint.stringValue = strings.text("Local rendering. Setup downloads Java 21 and PlantUML once. Offline: enter paths. JAR must be version 1.2026.8.")
        for (control, key) in controls { control.title = strings.text(key); control.setAccessibilityLabel(control.title) }
    }
    func setBusy(_ busy: Bool) {
        java.isEnabled = !busy; jar.isEnabled = !busy
        controls.forEach { $0.0.isEnabled = !busy }
    }
    func controlTextDidChange(_ notification: Notification) { onChange?() }
    @objc private func setupRuntime() { onSetup?(); close() }
    @objc private func browseJava() { choosePath(java, directory: true) }
    @objc private func browseJar() { choosePath(jar, directory: false) }
    private func choosePath(_ field: NSTextField, directory: Bool) {
        guard let window else { return }
        let picker = NSOpenPanel()
        picker.canChooseDirectories = directory; picker.canChooseFiles = !directory
        picker.treatsFilePackagesAsDirectories = true; picker.allowsMultipleSelection = false
        picker.message = strings.text(directory ? "Choose a Java home folder containing bin/java." : "Choose an official PlantUML 1.2026.8 JAR.")
        if !directory { picker.allowedContentTypes = [UTType(filenameExtension: "jar") ?? .data] }
        self.picker = picker
        picker.beginSheetModal(for: window) { [weak self] result in
            guard let self, self.picker === picker else { return }
            self.picker = nil
            if result == .OK, let url = picker.url { field.stringValue = url.path; self.onChange?() }
        }
    }
}
