#if os(WASI)
import Foundation

public enum WasiFileRegistry {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var storage: [String: Data] = [:]

    public static func register(path: String, data: Data) {
        lock.lock()
        defer { lock.unlock() }
        storage[path] = data
    }

    public static func data(for path: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return storage[path]
    }

    public static func clear(path: String) {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: path)
    }
}
#endif
