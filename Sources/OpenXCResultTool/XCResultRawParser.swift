import Foundation

struct XCResultRawParser {
    private let data: Data

    init(data: Data) {
        self.data = data
    }

    mutating func parse() throws -> XCResultRawValue {
        return try data.withUnsafeBytes { rawBuffer in
            let buffer = rawBuffer.bindMemory(to: UInt8.self)
            var cursor = Cursor(bytes: buffer)
            return try cursor.parse()
        }
    }

    private struct Cursor {
        let bytes: UnsafeBufferPointer<UInt8>
        var index = 0

        mutating func parse() throws -> XCResultRawValue {
            skipWhitespace()
            guard peek() == UInt8(ascii: "[") else {
                throw XCResultRawParserError("Expected '[' at start of raw object.")
            }
            return try parseContainer()
        }

        private mutating func parseContainer() throws -> XCResultRawValue {
            try consume(expected: UInt8(ascii: "["))
            skipWhitespace()

            var typeName: String?
            var fields: [String: XCResultRawValue] = [:]
            var elements: [XCResultRawValue] = []

            var sawTypedContainer = false
            if peek() == UInt8(ascii: "T") {
                index += 1
                sawTypedContainer = true
                skipWhitespace()
            }
            if peek() == UInt8(ascii: "S") {
                typeName = try parseToken(expected: UInt8(ascii: "S"))
                skipWhitespace()
            }

            if sawTypedContainer && peek() == UInt8(ascii: "[") {
                let metadata = try parseContainer()
                if let name = metadata.fields["_n"]?.stringValue {
                    typeName = name
                }
                for (key, value) in metadata.fields {
                    fields[key] = value
                }
                skipWhitespace()
            }

            while index < bytes.count {
                skipWhitespace()
                guard let next = peek() else {
                    throw XCResultRawParserError("Unexpected end of raw data.")
                }
                if next == UInt8(ascii: "]") {
                    index += 1
                    break
                }
                if next == UInt8(ascii: "K") {
                    let key = try parseToken(expected: UInt8(ascii: "K"))
                    let value = try parseValue()
                    fields[key] = value
                    if key == "_n", let name = value.stringValue {
                        typeName = name
                    }
                    continue
                }
                if next == UInt8(ascii: "[") {
                    let element = try parseContainer()
                    elements.append(element)
                    continue
                }
                throw XCResultRawParserError("Unexpected token '\(Character(UnicodeScalar(next)))' while parsing container.")
            }

            return XCResultRawValue(typeName: typeName, fields: fields, elements: elements)
        }

        private mutating func parseValue() throws -> XCResultRawValue {
            skipWhitespace()
            guard let next = peek() else {
                throw XCResultRawParserError("Unexpected end of raw data.")
            }
            if next == UInt8(ascii: "[") {
                return try parseContainer()
            }
            if next == UInt8(ascii: "V") {
                let value = try parseToken(expected: UInt8(ascii: "V"))
                return XCResultRawValue(scalar: value)
            }
            throw XCResultRawParserError("Unexpected value token '\(Character(UnicodeScalar(next)))'.")
        }

        private mutating func parseToken(expected: UInt8) throws -> String {
            try consume(expected: expected)
            let length = try parseLength()
            guard index + length <= bytes.count else {
                throw XCResultRawParserError("Token length exceeds buffer.")
            }
            let slice = bytes[index..<index + length]
            index += length
            return String(decoding: slice, as: UTF8.self)
        }

        private mutating func parseLength() throws -> Int {
            var value = 0
            var sawDigit = false
            while index < bytes.count {
                let byte = bytes[index]
                if byte == UInt8(ascii: ":") {
                    index += 1
                    if !sawDigit {
                        throw XCResultRawParserError("Expected length digits before ':'.")
                    }
                    return value
                }
                guard byte >= UInt8(ascii: "0"), byte <= UInt8(ascii: "9") else {
                    throw XCResultRawParserError("Invalid length character '\(Character(UnicodeScalar(byte)))'.")
                }
                sawDigit = true
                value = value * 10 + Int(byte - UInt8(ascii: "0"))
                index += 1
            }
            throw XCResultRawParserError("Unexpected end of data while parsing length.")
        }

        private mutating func skipWhitespace() {
            while index < bytes.count {
                let byte = bytes[index]
                if byte == 0x20 || byte == 0x0A || byte == 0x0D || byte == 0x09 {
                    index += 1
                } else {
                    break
                }
            }
        }

        private func peek() -> UInt8? {
            guard index < bytes.count else { return nil }
            return bytes[index]
        }

        private mutating func consume(expected: UInt8) throws {
            guard let next = peek(), next == expected else {
                let found = peek().map { Character(UnicodeScalar($0)) } ?? "?"
                throw XCResultRawParserError("Expected '\(Character(UnicodeScalar(expected)))' but found '\(found)'.")
            }
            index += 1
        }
    }
}

struct XCResultRawParserError: Error, CustomStringConvertible {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var description: String {
        message
    }
}
