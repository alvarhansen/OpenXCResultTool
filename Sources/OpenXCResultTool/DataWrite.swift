import Foundation

extension Data {
    func writeAtomic(to url: URL) throws {
#if os(WASI)
        try FileAccess.writeData(self, to: url)
#else
        try write(to: url, options: [.atomic])
#endif
    }
}
