import Foundation

struct XCResultRawValue {
    var typeName: String?
    var fields: [String: XCResultRawValue]
    var elements: [XCResultRawValue]
    var scalar: String?

    init(typeName: String? = nil,
         fields: [String: XCResultRawValue] = [:],
         elements: [XCResultRawValue] = [],
         scalar: String? = nil) {
        self.typeName = typeName
        self.fields = fields
        self.elements = elements
        self.scalar = scalar
    }

    func value(for key: String) -> XCResultRawValue? {
        fields[key]
    }

    var arrayValues: [XCResultRawValue] {
        if typeName == "Array" {
            return elements
        }
        return []
    }

    var stringValue: String? {
        scalar ?? fields["_v"]?.stringValue
    }

    var hasScalarOnly: Bool {
        guard stringValue != nil else { return false }
        let otherKeys = fields.keys.filter { $0 != "_n" && $0 != "_v" && $0 != "_s" }
        return otherKeys.isEmpty && elements.isEmpty
    }

    func toJSONValue(dateParser: XCResultDateParser) -> Any {
        if typeName == "Array" {
            return elements.map { $0.toJSONValue(dateParser: dateParser) }
        }

        if hasScalarOnly, let value = stringValue {
            return dateParser.convertScalar(value, typeName: typeName)
        }

        var dict: [String: Any] = [:]
        for (key, value) in fields where key != "_n" && key != "_v" && key != "_s" {
            dict[key] = value.toJSONValue(dateParser: dateParser)
        }
        if !elements.isEmpty {
            dict["values"] = elements.map { $0.toJSONValue(dateParser: dateParser) }
        }
        return dict
    }

    func toLegacyJSONValue() -> Any {
        if typeName == "Array" || (typeName == nil && fields.isEmpty && !elements.isEmpty) {
            let values = elements.map { $0.toLegacyJSONValue() }
            return [
                "_type": ["_name": typeName ?? "Array"],
                "_values": values
            ]
        }

        if hasScalarOnly, let value = stringValue {
            return [
                "_type": ["_name": typeName ?? "String"],
                "_value": value
            ]
        }

        var dict: [String: Any] = [:]
        if let typeName {
            var typeDict: [String: Any] = ["_name": typeName]
            if let supertype = XCResultRawValue.legacySupertypes[typeName] {
                typeDict["_supertype"] = ["_name": supertype]
            }
            dict["_type"] = typeDict
        }
        for (key, value) in fields where key != "_n" && key != "_v" && key != "_s" {
            dict[key] = value.toLegacyJSONValue()
        }
        if !elements.isEmpty {
            dict["_values"] = elements.map { $0.toLegacyJSONValue() }
        }
        return dict
    }

    private static let legacySupertypes: [String: String] = [
        "ActionTestMetadata": "ActionTestSummaryIdentifiableObject",
        "ActionTestPlanRunSummary": "ActionAbstractTestSummary",
        "ActionTestSummary": "ActionTestSummaryIdentifiableObject",
        "ActionTestSummaryGroup": "ActionTestSummaryIdentifiableObject",
        "ActionTestSummaryIdentifiableObject": "ActionAbstractTestSummary",
        "ActionTestableSummary": "ActionAbstractTestSummary",
        "ActivityLogAnalyzerControlFlowStep": "ActivityLogAnalyzerStep",
        "ActivityLogAnalyzerEventStep": "ActivityLogAnalyzerStep",
        "ActivityLogAnalyzerResultMessage": "ActivityLogMessage",
        "ActivityLogAnalyzerWarningMessage": "ActivityLogMessage",
        "ActivityLogCommandInvocationSection": "ActivityLogSection",
        "ActivityLogMajorSection": "ActivityLogSection",
        "ActivityLogTargetBuildSection": "ActivityLogMajorSection",
        "ActivityLogUnitTestSection": "ActivityLogSection",
        "TestFailureIssueSummary": "IssueSummary",
        "TestIssueSummary": "IssueSummary"
    ]

    func toLogJSONValue(dateParser: XCResultDateParser) -> Any {
        if typeName == "Array" {
            return elements.map { $0.toLogJSONValue(dateParser: dateParser) }
        }

        if hasScalarOnly, let value = stringValue {
            return dateParser.convertScalar(value, typeName: typeName)
        }

        var dict: [String: Any] = [:]
        for (key, value) in fields where key != "_n" && key != "_v" && key != "_s" {
            dict[key] = value.toLogJSONValue(dateParser: dateParser)
        }
        if !elements.isEmpty {
            dict["values"] = elements.map { $0.toLogJSONValue(dateParser: dateParser) }
        }

        applyLogDefaults(&dict)
        return dict
    }

    private func applyLogDefaults(_ dict: inout [String: Any]) {
        guard let typeName else { return }

        if typeName == "ActivityLogMessage" {
            if dict["annotations"] == nil {
                dict["annotations"] = []
            }
        }

        if typeName == "ActivityLogMessageAnnotation" {
            if dict["location"] == nil {
                dict["location"] = NSNull()
            }
        }

        if typeName == "DocumentLocation" || typeName == "DVTTextDocumentLocation" {
            if dict["url"] == nil {
                dict["url"] = ""
            }
        }

        if typeName == "ActivityLogSectionAttachment" {
            if let value = dict.removeValue(forKey: "identifier") {
                dict["uniformTypeIdentifier"] = value
            }
            if let value = dict.removeValue(forKey: "majorVersion") {
                dict["typeMajorVersion"] = value
            }
            if let value = dict.removeValue(forKey: "minorVersion") {
                dict["typeMinorVersion"] = value
            }
        }

        if typeName == "ActivityLogCommandInvocationSection" {
            let commandDetails = dict.removeValue(forKey: "commandDetails") ?? ""
            let emittedOutput = dict.removeValue(forKey: "emittedOutput") ?? ""
            let exitCode = dict.removeValue(forKey: "exitCode") ?? 0
            dict["commandInvocationDetails"] = [
                "commandDetails": commandDetails,
                "emittedOutput": emittedOutput,
                "exitCode": exitCode
            ]
        }

        if typeName == "ActivityLogUnitTestSection" {
            let testDetailKeys = [
                "emittedOutput",
                "suiteName",
                "summary",
                "testName",
                "testsPassedString",
                "runnablePath",
                "runnableUTI",
                "wasSkipped"
            ]
            var testDetails = dict["testDetails"] as? [String: Any] ?? [:]
            for key in testDetailKeys {
                if let value = dict.removeValue(forKey: key) {
                    testDetails[key] = value
                }
            }
            if testDetails["wasSkipped"] == nil {
                testDetails["wasSkipped"] = false
            }
            if !testDetails.isEmpty {
                dict["testDetails"] = testDetails
            }
        }

        if typeName == "ActivityLogSection" || (typeName.hasSuffix("Section") && typeName != "ActivityLogSectionAttachment") {
            if dict["attachments"] == nil {
                dict["attachments"] = []
            }
            if dict["messages"] == nil {
                dict["messages"] = []
            }
            if dict["subsections"] == nil {
                dict["subsections"] = []
            }
            if dict["duration"] == nil {
                dict["duration"] = 0
            }
        }
    }
}

struct XCResultDateParser {
    private let formatters: [DateFormatter]

    init() {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ"
        ]
        self.formatters = formats.map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            return formatter
        }
    }

    func convertScalar(_ value: String, typeName: String?) -> Any {
        switch typeName {
        case "Double":
            if value.range(of: "e", options: .caseInsensitive) != nil {
                return Double(value) ?? 0
            }
            return Decimal(string: value) ?? 0
        case "Int", "Integer":
            return Int(value) ?? 0
        case "UInt8", "UInt16", "UInt32", "UInt64":
            return UInt64(value) ?? 0
        case "Bool":
            return value == "true" || value == "1"
        case "Date":
            if let date = parseDate(value) {
                return (date.timeIntervalSince1970 * 1000).rounded() / 1000
            }
            return value
        default:
            return value
        }
    }

    private func parseDate(_ string: String) -> Date? {
        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }
}
