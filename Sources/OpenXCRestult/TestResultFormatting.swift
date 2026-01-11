import Foundation

struct TestResultFormatter {
    static func mapResult(_ result: String) -> String {
        switch result {
        case "Success":
            return "Passed"
        case "Failure":
            return "Failed"
        default:
            return result
        }
    }

    static func aggregate(_ results: [String]) -> String? {
        if results.contains("Failed") {
            return "Failed"
        }
        if results.contains("Skipped") {
            return "Skipped"
        }
        if results.contains("Expected Failure") {
            return "Expected Failure"
        }
        if results.contains("Passed") {
            return "Passed"
        }
        return nil
    }
}

struct RunDurationFormatter {
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.decimalSeparator = ","
        formatter.usesSignificantDigits = true
        formatter.minimumSignificantDigits = 2
        formatter.maximumSignificantDigits = 2
        return formatter
    }()

    static func format(seconds: Double) -> String {
        if seconds >= 60 {
            let totalSeconds = Int(seconds.rounded(.down))
            let minutes = totalSeconds / 60
            let remaining = totalSeconds % 60
            return "\(minutes)m \(remaining)s"
        }
        if seconds >= 1 {
            let whole = Int(seconds.rounded(.down))
            return "\(whole)s"
        }
        let number = NSNumber(value: seconds)
        let value = formatter.string(from: number) ?? String(format: "%.2f", seconds)
        return "\(value)s"
    }
}

struct DetailDurationFormatter {
    static func format(seconds: Double, average: Bool) -> String {
        let prefix = average ? "Average duration" : "Ran for"
        if seconds >= 60 {
            let totalSeconds = Int(seconds.rounded(.down))
            let minutes = totalSeconds / 60
            let remaining = totalSeconds % 60
            let minuteLabel = minutes == 1 ? "minute" : "minutes"
            let secondLabel = remaining == 1 ? "second" : "seconds"
            return "\(prefix) \(minutes) \(minuteLabel), \(remaining) \(secondLabel)"
        }

        let runDuration = RunDurationFormatter.format(seconds: seconds)
        let trimmed = runDuration.hasSuffix("s") ? String(runDuration.dropLast()) : runDuration
        let label = trimmed == "1" ? "second" : "seconds"
        return "\(prefix) \(trimmed) \(label)"
    }

    static func formatAverage(seconds: Double) -> String {
        let rounded = Int(seconds.rounded(.down))
        if rounded >= 60 {
            return format(seconds: Double(rounded), average: true)
        }
        return "Average duration \(rounded) seconds"
    }
}

struct ArgumentNameFormatter {
    static func displayName(label: String, value: String) -> String {
        switch label {
        case "XCUIAppearanceMode":
            return appearanceName(from: value)
        case "XCUIDeviceOrientation":
            return orientationName(from: value)
        default:
            return value
        }
    }

    private static func appearanceName(from value: String) -> String {
        switch value {
        case "1":
            return "Light Appearance"
        case "2":
            return "Dark Appearance"
        case "4":
            return "Unspecified"
        default:
            return value
        }
    }

    private static func orientationName(from value: String) -> String {
        switch value {
        case "1":
            return "Portrait"
        case "4":
            return "Landscape Right"
        default:
            return value
        }
    }
}
