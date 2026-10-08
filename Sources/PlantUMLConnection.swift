import Foundation

@MainActor final class PlantUMLConnection {
    private var connection: NSXPCConnection?
    private var pending: PlantUMLContinuation?
    private var timer: Task<Void, Never>?
    func render(_ request: PlantUMLRequest) async throws -> Data {
        try Task.checkCancellation()
        close()
        let frame = try JSONEncoder().encode(request)
        guard frame.count <= 1024 * 1024 else { throw NSError(domain: "PlantUML", code: 1) }
        let app = Bundle.main.bundleURL
        let helper = app.appendingPathComponent("Contents/XPCServices/DuckpadNativeInstaller.xpc")
        let connection = NSXPCConnection(serviceName: NativeInstallerXPC.identifier)
        connection.setCodeSigningRequirement(try NativeInstallerXPC.requirement(for: helper, matchingSignerOf: app))
        connection.remoteObjectInterface = NSXPCInterface(with: DuckpadNativeInstallerProtocol.self)
        self.connection = connection
        defer { if self.connection === connection { close() } }
        return try await withCheckedThrowingContinuation { continuation in
            let reply = PlantUMLContinuation(continuation)
            pending = reply
            connection.invalidationHandler = { reply.finish(.failure(CancellationError())) }
            connection.interruptionHandler = { reply.finish(.failure(CancellationError())) }
            connection.resume()
            timer = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(300)) } catch { return }
                if self?.pending === reply { reply.finish(.failure(NSError(domain: "PlantUML", code: 4))); self?.close() }
            }
            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in reply.finish(.failure(error)) }) as? DuckpadNativeInstallerProtocol else {
                reply.finish(.failure(NSError(domain: "PlantUML", code: 2))); return
            }
            proxy.renderPlantUML(frame) { data, error in
                if let data { reply.finish(.success(data)) }
                else { reply.finish(.failure(NSError(domain: "PlantUML", code: 3, userInfo: [NSLocalizedDescriptionKey: error ?? "renderFailed"]))) }
            }
        }
    }
    func close() { timer?.cancel(); timer = nil; pending?.finish(.failure(CancellationError())); pending = nil; connection?.invalidate(); connection = nil }
}
