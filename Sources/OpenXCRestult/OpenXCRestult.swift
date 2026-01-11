import Foundation

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

@main
struct OpenXCRestult {
    static func main() {
        let exitCode = CLI().run()
        if exitCode != 0 {
            exit(exitCode)
        }
    }
}
