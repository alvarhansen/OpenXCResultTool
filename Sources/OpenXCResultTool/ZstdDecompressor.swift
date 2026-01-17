import Foundation
import libzstd

struct ZstdDecompressor {
    static func decompress(_ data: Data) throws -> Data {
        return try data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                return Data()
            }

            let frameSize = ZSTD_getFrameContentSize(baseAddress, rawBuffer.count)
            if frameSize != ZSTD_CONTENTSIZE_ERROR,
               frameSize != ZSTD_CONTENTSIZE_UNKNOWN {
                return try decompressKnownSize(data: data, size: frameSize)
            }

            return try decompressStreaming(data: data)
        }
    }

    private static func decompressKnownSize(data: Data, size: UInt64) throws -> Data {
        guard size > 0 else {
            return Data()
        }
        let outputSize = Int(size)
        var output = Data(count: outputSize)
        let result: size_t = try output.withUnsafeMutableBytes { outputBuffer in
            try data.withUnsafeBytes { inputBuffer in
                guard let outputPointer = outputBuffer.baseAddress,
                      let inputPointer = inputBuffer.baseAddress else {
                    throw ZstdError("Invalid buffers for zstd decompression.")
                }
                return ZSTD_decompress(outputPointer, outputSize, inputPointer, inputBuffer.count)
            }
        }
        if ZSTD_isError(result) != 0 {
            let message = String(cString: ZSTD_getErrorName(result))
            throw ZstdError("Zstd decompression failed: \(message)")
        }
        if result < output.count {
            output.removeSubrange(Int(result)..<output.count)
        }
        return output
    }

    private static func decompressStreaming(data: Data) throws -> Data {
        guard let dctx = ZSTD_createDCtx() else {
            throw ZstdError("Failed to create ZSTD decompression context.")
        }
        defer {
            ZSTD_freeDCtx(dctx)
        }

        var output = Data()
        let chunkSize = 64 * 1024
        var buffer = [UInt8](repeating: 0, count: chunkSize)

        var input = data.withUnsafeBytes { rawBuffer -> ZSTD_inBuffer in
            ZSTD_inBuffer(src: rawBuffer.baseAddress, size: rawBuffer.count, pos: 0)
        }

        while input.pos < input.size {
            let result: size_t = buffer.withUnsafeMutableBytes { outputBuffer in
                var outBuffer = ZSTD_outBuffer(dst: outputBuffer.baseAddress, size: outputBuffer.count, pos: 0)
                let decompressResult = ZSTD_decompressStream(dctx, &outBuffer, &input)
                if outBuffer.pos > 0 {
                    output.append(contentsOf: outputBuffer.bindMemory(to: UInt8.self)[0..<outBuffer.pos])
                }
                return decompressResult
            }
            if ZSTD_isError(result) != 0 {
                let message = String(cString: ZSTD_getErrorName(result))
                throw ZstdError("Zstd decompression failed: \(message)")
            }
            if result == 0 && input.pos == input.size {
                break
            }
        }

        return output
    }
}

struct ZstdError: Error, CustomStringConvertible {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var description: String {
        message
    }
}
