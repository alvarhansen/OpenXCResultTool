import Foundation

public struct ContentAvailabilityBuilder {
    private let store: XCResultFileBackedStore

    public init(xcresultPath: String) throws {
        self.store = try XCResultFileBackedStore(xcresultPath: xcresultPath)
    }

    public func contentAvailability() throws -> ContentAvailability {
        let root = try store.loadObject(id: store.rootId)
        let actions = root.value(for: "actions")?.arrayValues ?? []
        guard let action = actions.first else {
            return ContentAvailability(
                hasCoverage: false,
                hasDiagnostics: false,
                hasTestResults: false,
                logs: []
            )
        }

        let actionResult = action.value(for: "actionResult")
        let buildResult = action.value(for: "buildResult")

        let hasCoverage = hasCoverageData(actionResult: actionResult)
        let hasDiagnostics = actionResult?.value(for: "diagnosticsRef") != nil
        let hasTestResults = actionResult?.value(for: "testsRef") != nil

        var logs: [String] = []
        if buildResult?.value(for: "logRef") != nil {
            logs.append("build")
        }
        if actionResult?.value(for: "logRef") != nil {
            logs.append("action")
        }

        return ContentAvailability(
            hasCoverage: hasCoverage,
            hasDiagnostics: hasDiagnostics,
            hasTestResults: hasTestResults,
            logs: logs
        )
    }

    private func hasCoverageData(actionResult: XCResultRawValue?) -> Bool {
        guard let coverage = actionResult?.value(for: "coverage") else {
            return false
        }
        if let value = coverage.value(for: "hasCoverageData")?.stringValue {
            return value == "true" || value == "1"
        }
        return false
    }
}
