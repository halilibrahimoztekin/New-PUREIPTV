import Foundation
import zlib

enum XMLTVArchiveError: LocalizedError {
    case invalidOrUnsupported

    var errorDescription: String? {
        AppStrings.Errors.invalidXMLTVSource
    }
}

struct XMLTVDecodedDocument: Sendable {
    let data: Data
    let wasArchived: Bool
}

enum XMLTVArchiveDecoder {
    static let maximumDownloadBytes = 64 * 1024 * 1024
    private static let maximumExpandedBytes = 128 * 1024 * 1024
    private static let tarBlockSize = 512

    static func decode(_ data: Data) throws -> XMLTVDecodedDocument {
        guard !data.isEmpty, data.count <= maximumDownloadBytes else {
            throw XMLTVArchiveError.invalidOrUnsupported
        }

        let wasGzipped = isGzipped(data)
        let expanded = wasGzipped ? try decompressGzip(data) : data

        guard !isGzipped(expanded), !isUnsupportedArchive(expanded) else {
            throw XMLTVArchiveError.invalidOrUnsupported
        }

        if isTarArchive(expanded) {
            let xml = try extractSingleXMLFile(from: expanded)
            guard !isGzipped(xml), !isTarArchive(xml), !isUnsupportedArchive(xml) else {
                throw XMLTVArchiveError.invalidOrUnsupported
            }
            return XMLTVDecodedDocument(data: xml, wasArchived: true)
        }

        return XMLTVDecodedDocument(data: expanded, wasArchived: wasGzipped)
    }

    static func decompressGzip(_ data: Data) throws -> Data {
        guard isGzipped(data), data.count <= maximumDownloadBytes else {
            throw XMLTVArchiveError.invalidOrUnsupported
        }

        var stream = z_stream()
        let initializationStatus = inflateInit2_(
            &stream,
            16 + MAX_WBITS,
            ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size)
        )
        guard initializationStatus == Z_OK else {
            throw XMLTVArchiveError.invalidOrUnsupported
        }
        defer { inflateEnd(&stream) }

        let outputBufferSize = 64 * 1024
        let outputBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: outputBufferSize)
        defer { outputBuffer.deallocate() }

        return try data.withUnsafeBytes { rawBuffer in
            guard let input = rawBuffer.bindMemory(to: Bytef.self).baseAddress else {
                throw XMLTVArchiveError.invalidOrUnsupported
            }
            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: input)
            stream.avail_in = uInt(data.count)

            var output = Data()
            output.reserveCapacity(min(maximumExpandedBytes, 1 * 1024 * 1024))

            while true {
                try Task.checkCancellation()
                stream.next_out = outputBuffer
                stream.avail_out = uInt(outputBufferSize)

                let status = inflate(&stream, Z_NO_FLUSH)
                let bytesProduced = outputBufferSize - Int(stream.avail_out)
                guard bytesProduced <= maximumExpandedBytes - output.count else {
                    throw XMLTVArchiveError.invalidOrUnsupported
                }
                if bytesProduced > 0 {
                    output.append(outputBuffer, count: bytesProduced)
                }

                if status == Z_STREAM_END {
                    // Reject concatenated gzip members and any hidden trailing payload.
                    guard stream.avail_in == 0 else {
                        throw XMLTVArchiveError.invalidOrUnsupported
                    }
                    return output
                }

                guard status == Z_OK, bytesProduced > 0 || stream.avail_in > 0 else {
                    throw XMLTVArchiveError.invalidOrUnsupported
                }
            }
        }
    }

    private static func isGzipped(_ data: Data) -> Bool {
        data.count >= 2 && data[0] == 0x1F && data[1] == 0x8B
    }

    private static func isTarArchive(_ data: Data) -> Bool {
        guard data.count >= tarBlockSize else { return false }
        let magic = Array(data[257 ..< 263])
        return magic == [0x75, 0x73, 0x74, 0x61, 0x72, 0x00]
            || magic == [0x75, 0x73, 0x74, 0x61, 0x72, 0x20]
            || isValidTarHeader(data, at: 0)
    }

    private static func isUnsupportedArchive(_ data: Data) -> Bool {
        guard data.count >= 4 else { return false }
        let signature = Array(data.prefix(8))
        return signature.starts(with: [0x50, 0x4B, 0x03, 0x04]) // ZIP
            || signature.starts(with: [0x42, 0x5A, 0x68]) // bzip2
            || signature.starts(with: [0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00]) // xz
            || signature.starts(with: [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]) // 7z
            || signature.starts(with: [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07]) // RAR
            || signature.starts(with: [0x28, 0xB5, 0x2F, 0xFD]) // zstd
    }

    private static func extractSingleXMLFile(from tar: Data) throws -> Data {
        var offset = 0
        var xmlFile: Data?
        var foundEndMarker = false

        while offset + tarBlockSize <= tar.count {
            try Task.checkCancellation()

            if isZeroBlock(tar, at: offset) {
                let secondBlock = offset + tarBlockSize
                guard secondBlock + tarBlockSize <= tar.count,
                      isZeroBlock(tar, at: secondBlock),
                      tar[(secondBlock + tarBlockSize) ..< tar.count].allSatisfy({ $0 == 0 })
                else {
                    throw XMLTVArchiveError.invalidOrUnsupported
                }
                foundEndMarker = true
                break
            }

            guard isValidTarHeader(tar, at: offset),
                  let size = parseOctal(tar, range: (offset + 124) ..< (offset + 136))
            else {
                throw XMLTVArchiveError.invalidOrUnsupported
            }
            guard size <= maximumExpandedBytes else {
                throw XMLTVArchiveError.invalidOrUnsupported
            }

            let typeFlag = tar[offset + 156]
            let contentStart = offset + tarBlockSize
            let paddedBlocks = (size / tarBlockSize) + (size.isMultiple(of: tarBlockSize) ? 0 : 1)
            let (paddedSize, paddedSizeOverflow) = paddedBlocks.multipliedReportingOverflow(by: tarBlockSize)
            let (contentEnd, overflow) = contentStart.addingReportingOverflow(paddedSize)
            guard !paddedSizeOverflow, !overflow, contentEnd <= tar.count else {
                throw XMLTVArchiveError.invalidOrUnsupported
            }

            if typeFlag == 0 || typeFlag == 48 { // regular file
                guard xmlFile == nil, size > 0 else {
                    throw XMLTVArchiveError.invalidOrUnsupported
                }
                let payloadEnd = contentStart + size
                let payload = Data(tar[contentStart ..< payloadEnd])
                guard !payload.isEmpty else { throw XMLTVArchiveError.invalidOrUnsupported }
                xmlFile = payload
            } else if typeFlag == 53 { // directory entries are harmless when empty
                guard size == 0 else { throw XMLTVArchiveError.invalidOrUnsupported }
            } else {
                // Reject links, sparse files, PAX/GNU extensions, and nested archive metadata.
                throw XMLTVArchiveError.invalidOrUnsupported
            }

            offset = contentEnd
        }

        guard foundEndMarker, let xmlFile else {
            throw XMLTVArchiveError.invalidOrUnsupported
        }
        return xmlFile
    }

    private static func isValidTarHeader(_ data: Data, at offset: Int) -> Bool {
        guard offset + tarBlockSize <= data.count,
              let expectedChecksum = parseOctal(data, range: (offset + 148) ..< (offset + 156))
        else {
            return false
        }

        var checksum = 0
        for index in offset ..< (offset + tarBlockSize) {
            checksum += (offset + 148 ..< offset + 156).contains(index) ? 32 : Int(data[index])
        }
        return checksum == expectedChecksum
    }

    private static func parseOctal(_ data: Data, range: Range<Int>) -> Int? {
        guard range.lowerBound >= 0, range.upperBound <= data.count else { return nil }
        var digits: [UInt8] = []
        for byte in data[range] {
            if byte == 0 || byte == 32 {
                if !digits.isEmpty {
                    break
                }
                continue
            }
            guard (48 ... 55).contains(byte) else { return nil }
            digits.append(byte)
        }
        guard !digits.isEmpty else { return 0 }

        var value = 0
        for digit in digits {
            let (multiplied, multiplyOverflow) = value.multipliedReportingOverflow(by: 8)
            let (added, addOverflow) = multiplied.addingReportingOverflow(Int(digit - 48))
            guard !multiplyOverflow, !addOverflow else { return nil }
            value = added
        }
        return value
    }

    private static func isZeroBlock(_ data: Data, at offset: Int) -> Bool {
        guard offset + tarBlockSize <= data.count else { return false }
        return data[offset ..< (offset + tarBlockSize)].allSatisfy { $0 == 0 }
    }
}
