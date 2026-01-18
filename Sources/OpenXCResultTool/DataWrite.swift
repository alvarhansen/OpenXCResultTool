import Foundation

extension Data {
    func writeAtomic(to url: URL) throws {
#if os(WASI)
        try write(to: url)
#else
        try write(to: url, options: [.atomic])
#endif
    }
}
