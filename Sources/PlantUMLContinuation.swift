import Foundation

/// XPC can deliver a reply and an invalidation error; resume only once.
final class PlantUMLContinuation: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Data, any Error>?
    init(_ continuation: CheckedContinuation<Data, any Error>) { self.continuation = continuation }
    func finish(_ result: Result<Data, any Error>) {
        lock.lock(); let pending = continuation; continuation = nil; lock.unlock()
        pending?.resume(with: result)
    }
}
