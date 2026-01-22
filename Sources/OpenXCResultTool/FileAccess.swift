import Foundation

enum FileAccess {
    static func readData(at url: URL) throws -> Data {
        #if os(WASI)
        if let data = WasiFileRegistry.data(for: url.path) {
            return data
        }
        #endif
        return try Data(contentsOf: url)
    }

    static func fileExists(at url: URL) -> Bool {
        #if os(WASI)
        if WasiFileRegistry.data(for: url.path) != nil {
            return true
        }
        #endif
        return FileManager.default.fileExists(atPath: url.path)
    }

    static func fileSize(at url: URL) -> Int? {
        #if os(WASI)
        if let data = WasiFileRegistry.data(for: url.path) {
            return data.count
        }
        #endif
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber else {
            return nil
        }
        return size.intValue
    }
}
