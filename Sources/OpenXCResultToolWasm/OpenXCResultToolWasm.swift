import Foundation
import OpenXCResultTool

@main
struct OpenXCResultToolWasmMain {
    static func main() {}
}

@MainActor
private var lastErrorMessage: String?

@_cdecl("openxcresulttool_free")
public func openxcresulttool_free(_ pointer: UnsafeMutablePointer<CChar>?) {
    guard let pointer else {
        return
    }
    pointer.deallocate()
}

@MainActor
@_cdecl("openxcresulttool_last_error")
public func openxcresulttool_last_error() -> UnsafeMutablePointer<CChar>? {
    guard let message = lastErrorMessage else {
        return nil
    }
    return makeCString(message)
}

@MainActor
@_cdecl("openxcresulttool_get_test_results_summary_json")
public func openxcresulttool_get_test_results_summary_json(
    _ pathPointer: UnsafePointer<CChar>?,
    _ compact: Bool
) -> UnsafeMutablePointer<CChar>? {
    return buildJSONString(pathPointer: pathPointer, compact: compact) { path in
        let builder = try TestResultsSummaryBuilder(xcresultPath: path)
        let summary = try builder.summary()
        return try encodeJSON(summary, compact: compact)
    }
}

@MainActor
@_cdecl("openxcresulttool_get_test_results_tests_json")
public func openxcresulttool_get_test_results_tests_json(
    _ pathPointer: UnsafePointer<CChar>?,
    _ compact: Bool
) -> UnsafeMutablePointer<CChar>? {
    return buildJSONString(pathPointer: pathPointer, compact: compact) { path in
        let builder = try TestResultsTestsBuilder(xcresultPath: path)
        let tests = try builder.tests()
        return try encodeJSON(tests, compact: compact)
    }
}

@MainActor
@_cdecl("openxcresulttool_get_test_results_test_details_json")
public func openxcresulttool_get_test_results_test_details_json(
    _ pathPointer: UnsafePointer<CChar>?,
    _ testIdPointer: UnsafePointer<CChar>?,
    _ compact: Bool
) -> UnsafeMutablePointer<CChar>? {
    return buildJSONString(pathPointer: pathPointer, compact: compact) { path in
        guard let testId = optionalString(from: testIdPointer) else {
            throw WasmExportError("testId is required")
        }
        let builder = try TestResultsTestDetailsBuilder(xcresultPath: path)
        let details = try builder.testDetails(testId: testId)
        return try encodeJSON(details, compact: compact)
    }
}

@MainActor
@_cdecl("openxcresulttool_get_test_results_activities_json")
public func openxcresulttool_get_test_results_activities_json(
    _ pathPointer: UnsafePointer<CChar>?,
    _ testIdPointer: UnsafePointer<CChar>?,
    _ compact: Bool
) -> UnsafeMutablePointer<CChar>? {
    return buildJSONString(pathPointer: pathPointer, compact: compact) { path in
        guard let testId = optionalString(from: testIdPointer) else {
            throw WasmExportError("testId is required")
        }
        let builder = try TestResultsActivitiesBuilder(xcresultPath: path)
        let activities = try builder.activities(testId: testId)
        return try encodeJSON(activities, compact: compact)
    }
}

@MainActor
@_cdecl("openxcresulttool_get_test_results_metrics_json")
public func openxcresulttool_get_test_results_metrics_json(
    _ pathPointer: UnsafePointer<CChar>?,
    _ testIdPointer: UnsafePointer<CChar>?,
    _ compact: Bool
) -> UnsafeMutablePointer<CChar>? {
    return buildJSONString(pathPointer: pathPointer, compact: compact) { path in
        let builder = try TestResultsMetricsBuilder(xcresultPath: path)
        let testId = optionalString(from: testIdPointer)
        let metrics = try builder.metrics(testId: testId)
        return try encodeJSON(metrics, compact: compact)
    }
}

@MainActor
@_cdecl("openxcresulttool_get_test_results_insights_json")
public func openxcresulttool_get_test_results_insights_json(
    _ pathPointer: UnsafePointer<CChar>?,
    _ compact: Bool
) -> UnsafeMutablePointer<CChar>? {
    return buildJSONString(pathPointer: pathPointer, compact: compact) { path in
        let builder = try TestResultsInsightsBuilder(xcresultPath: path)
        let insights = try builder.insights()
        return try encodeJSON(insights, compact: compact)
    }
}

@MainActor
private func buildJSONString(
    pathPointer: UnsafePointer<CChar>?,
    compact: Bool,
    work: (String) throws -> String
) -> UnsafeMutablePointer<CChar>? {
    guard let path = optionalString(from: pathPointer) else {
        lastErrorMessage = "path is required"
        return nil
    }
    do {
        let value = try work(path)
        lastErrorMessage = nil
        return makeCString(value)
    } catch {
        lastErrorMessage = String(describing: error)
        return nil
    }
}

private func optionalString(from pointer: UnsafePointer<CChar>?) -> String? {
    guard let pointer else {
        return nil
    }
    return String(cString: pointer)
}

private func encodeJSON<T: Encodable>(_ value: T, compact: Bool) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = compact ? [] : [.prettyPrinted]
    let data = try encoder.encode(value)
    return String(decoding: data, as: UTF8.self)
}

private func makeCString(_ value: String) -> UnsafeMutablePointer<CChar>? {
    var utf8 = Array(value.utf8)
    utf8.append(0)
    let pointer = UnsafeMutablePointer<CChar>.allocate(capacity: utf8.count)
    for (index, byte) in utf8.enumerated() {
        pointer[index] = CChar(bitPattern: byte)
    }
    return pointer
}

private struct WasmExportError: Error, CustomStringConvertible {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var description: String {
        message
    }
}
