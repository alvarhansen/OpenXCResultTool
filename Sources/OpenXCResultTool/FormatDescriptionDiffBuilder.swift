import Foundation

struct FormatDescriptionDiffBuilder {
    func diff(fromURL: URL, toURL: URL) throws -> FormatDescriptionDiffResult {
        let decoder = JSONDecoder()
        let from = try decoder.decode(FormatDescriptionFile.self, from: Data(contentsOf: fromURL))
        let to = try decoder.decode(FormatDescriptionFile.self, from: Data(contentsOf: toURL))

        let fromVersion = from.versionString
        let toVersion = to.versionString

        let fromTypes = from.typesByName
        let toTypes = to.typesByName

        let fromNames = Set(fromTypes.keys)
        let toNames = Set(toTypes.keys)

        let addedTypes = Array(toNames.subtracting(fromNames)).sorted()
        let removedTypes = Array(fromNames.subtracting(toNames)).sorted()

        var addedProperties: [FormatDescriptionPropertyChange] = []
        var removedProperties: [FormatDescriptionPropertyChange] = []
        var changedProperties: [FormatDescriptionPropertyTypeChange] = []

        let commonTypes = fromNames.intersection(toNames).sorted()
        for typeName in commonTypes {
            guard let fromType = fromTypes[typeName],
                  let toType = toTypes[typeName] else {
                continue
            }

            let fromProps = fromType.propertiesByName
            let toProps = toType.propertiesByName
            let fromPropNames = Set(fromProps.keys)
            let toPropNames = Set(toProps.keys)

            let added = toPropNames.subtracting(fromPropNames).sorted()
            for property in added {
                addedProperties.append(
                    FormatDescriptionPropertyChange(typeName: typeName, propertyName: property)
                )
            }

            let removed = fromPropNames.subtracting(toPropNames).sorted()
            for property in removed {
                removedProperties.append(
                    FormatDescriptionPropertyChange(typeName: typeName, propertyName: property)
                )
            }

            let commonProps = fromPropNames.intersection(toPropNames).sorted()
            for property in commonProps {
                guard let fromProp = fromProps[property],
                      let toProp = toProps[property] else {
                    continue
                }
                let fromTypeString = propertyTypeString(fromProp)
                let toTypeString = propertyTypeString(toProp)
                if fromTypeString != toTypeString {
                    changedProperties.append(
                        FormatDescriptionPropertyTypeChange(
                            typeName: typeName,
                            propertyName: property,
                            fromType: fromTypeString,
                            toType: toTypeString
                        )
                    )
                }
            }
        }

        return FormatDescriptionDiffResult(
            fromVersion: fromVersion,
            toVersion: toVersion,
            addedTypes: addedTypes,
            removedTypes: removedTypes,
            addedProperties: addedProperties.sorted(),
            removedProperties: removedProperties.sorted(),
            changedProperties: changedProperties.sorted()
        )
    }

    func textOutput(diff: FormatDescriptionDiffResult) -> String {
        var lines = [
            "Diff of versions: \(diff.fromVersion) -> \(diff.toVersion)",
            "Changes:"
        ]
        for typeName in diff.addedTypes {
            lines.append("* added type '\(typeName)'")
        }
        for typeName in diff.removedTypes {
            lines.append("* removed type '\(typeName)'")
        }
        for change in diff.addedProperties {
            lines.append("* type '\(change.typeName)' added property '\(change.propertyName)'")
        }
        for change in diff.removedProperties {
            lines.append("* type '\(change.typeName)' removed property '\(change.propertyName)'")
        }
        for change in diff.changedProperties {
            lines.append("* type '\(change.typeName)', property '\(change.propertyName)' changed type from '\(change.fromType)' to '\(change.toType)'")
        }
        return lines.joined(separator: "\n")
    }

    func markdownOutput(diff: FormatDescriptionDiffResult) -> String {
        var lines = [
            "# Format Description Diff \(diff.fromVersion) -> \(diff.toVersion)",
            "## Changes"
        ]
        for typeName in diff.addedTypes {
            lines.append("- added type `\(typeName)`")
        }
        for typeName in diff.removedTypes {
            lines.append("- removed type `\(typeName)`")
        }
        for change in diff.addedProperties {
            lines.append("- type `\(change.typeName)` added property `\(change.propertyName)`")
        }
        for change in diff.removedProperties {
            lines.append("- type `\(change.typeName)` removed property `\(change.propertyName)`")
        }
        for change in diff.changedProperties {
            lines.append("- type `\(change.typeName)`, property `\(change.propertyName)` changed type from `\(change.fromType)` to `\(change.toType)`")
        }
        return lines.joined(separator: "\n")
    }

    private func propertyTypeString(_ property: FormatDescriptionProperty) -> String {
        switch property.type {
        case "Optional":
            let wrapped = property.wrappedType ?? "Unknown"
            return "\(wrapped)?"
        case "Array":
            let wrapped = property.wrappedType ?? "Unknown"
            return "[\(wrapped)]"
        default:
            return property.type
        }
    }
}

struct FormatDescriptionDiffResult {
    let fromVersion: String
    let toVersion: String
    let addedTypes: [String]
    let removedTypes: [String]
    let addedProperties: [FormatDescriptionPropertyChange]
    let removedProperties: [FormatDescriptionPropertyChange]
    let changedProperties: [FormatDescriptionPropertyTypeChange]
}

struct FormatDescriptionPropertyChange: Comparable {
    let typeName: String
    let propertyName: String

    static func < (lhs: FormatDescriptionPropertyChange, rhs: FormatDescriptionPropertyChange) -> Bool {
        if lhs.typeName != rhs.typeName {
            return lhs.typeName < rhs.typeName
        }
        return lhs.propertyName < rhs.propertyName
    }
}

struct FormatDescriptionPropertyTypeChange: Comparable {
    let typeName: String
    let propertyName: String
    let fromType: String
    let toType: String

    static func < (lhs: FormatDescriptionPropertyTypeChange, rhs: FormatDescriptionPropertyTypeChange) -> Bool {
        if lhs.typeName != rhs.typeName {
            return lhs.typeName < rhs.typeName
        }
        if lhs.propertyName != rhs.propertyName {
            return lhs.propertyName < rhs.propertyName
        }
        if lhs.fromType != rhs.fromType {
            return lhs.fromType < rhs.fromType
        }
        return lhs.toType < rhs.toType
    }
}

private struct FormatDescriptionFile: Decodable {
    let types: [FormatDescriptionType]
    let version: FormatDescriptionVersion?

    var typesByName: [String: FormatDescriptionType] {
        Dictionary(uniqueKeysWithValues: types.compactMap { type in
            guard let name = type.typeName else { return nil }
            return (name, type)
        })
    }

    var versionString: String {
        version?.stringValue ?? "unknown"
    }
}

private struct FormatDescriptionType: Decodable {
    let type: FormatDescriptionTypeName?
    let properties: [FormatDescriptionProperty]?

    var typeName: String? {
        type?.name
    }

    var propertiesByName: [String: FormatDescriptionProperty] {
        Dictionary(uniqueKeysWithValues: (properties ?? []).map { ($0.name, $0) })
    }
}

private struct FormatDescriptionTypeName: Decodable {
    let name: String
}

private struct FormatDescriptionProperty: Decodable {
    let name: String
    let type: String
    let wrappedType: String?
}

private struct FormatDescriptionVersion: Decodable {
    let major: Int
    let minor: Int
    let patch: Int?

    var stringValue: String {
        if let patch {
            return "\(major).\(minor).\(patch)"
        }
        return "\(major).\(minor)"
    }
}
