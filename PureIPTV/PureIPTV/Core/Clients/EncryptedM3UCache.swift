import CryptoKit
import Foundation
import Security

/// Stores only validated M3U response bodies. The filename is an HMAC of the
/// complete request identity, while the snapshot and its HTTP validators are
/// authenticated-encrypted together.
actor EncryptedM3UCache {
    struct Snapshot: Sendable {
        let body: Data
        let etag: String?
        let lastModified: String?
        let vary: String?
    }

    struct RequestContext: Sendable {
        let snapshot: Snapshot?
    }

    private struct DiskEnvelope: Codable {
        let version: Int
        let sealedPayload: Data
    }

    private struct Payload: Codable {
        let body: Data
        let etag: String?
        let lastModified: String?
        let vary: String?
        let updatedAt: Date
    }

    private static let keychainService = "com.oztech.PureIPTV.encryptedM3UCache.v1"
    private static let keychainAccount = "device-only-key.v1"
    private static let filePrefix = "m3u-cache-v1-"
    private static let schemaVersion = 1
    static let maximumPersistedBodyBytes = 16 * 1024 * 1024
    private static let maximumSnapshotFileBytes = 16 * 1024 * 1024 + 64 * 1024
    private static let maximumDirectoryBytes = 64 * 1024 * 1024
    private static let maximumAge: TimeInterval = 7 * 24 * 60 * 60

    private var cachedMasterKeyData: Data?

    func prepare(for config: PlaylistConfig) -> RequestContext? {
        guard let url = config.m3uURL,
              let masterKeyData = loadOrCreateMasterKeyData()
        else { return nil }

        let scopeKey = Self.scopeKey(for: config, url: url, masterKeyData: masterKeyData)
        let snapshot = loadSnapshot(scopeKey: scopeKey, masterKeyData: masterKeyData)
        return RequestContext(snapshot: snapshot)
    }

    func store(
        body: Data,
        etag: String?,
        lastModified: String?,
        vary: String?,
        for config: PlaylistConfig
    ) {
        guard body.count <= Self.maximumPersistedBodyBytes,
              let url = config.m3uURL,
              let masterKeyData = loadOrCreateMasterKeyData(),
              let directory = try? cacheDirectory()
        else { return }

        let scopeKey = Self.scopeKey(for: config, url: url, masterKeyData: masterKeyData)
        let payload = Payload(
            body: body,
            etag: Self.safeETag(etag),
            lastModified: Self.safeHTTPDate(lastModified),
            vary: Self.safeHeaderValue(vary),
            updatedAt: Date()
        )

        do {
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .binary
            let plaintext = try encoder.encode(payload)
            let sealedBox = try AES.GCM.seal(
                plaintext,
                using: Self.encryptionKey(masterKeyData),
                authenticating: Self.authenticatedData(for: scopeKey)
            )
            guard let combined = sealedBox.combined else { return }
            let envelope = DiskEnvelope(version: Self.schemaVersion, sealedPayload: combined)
            let encodedEnvelope = try encoder.encode(envelope)
            guard encodedEnvelope.count <= Self.maximumSnapshotFileBytes else { return }

            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete]
            )
            try evictExpiredFiles(in: directory)
            try makeRoom(for: encodedEnvelope.count, replacing: Self.fileURL(scopeKey: scopeKey, in: directory), in: directory)

            let destination = Self.fileURL(scopeKey: scopeKey, in: directory)
            try encodedEnvelope.write(to: destination, options: .atomic)
            // The cache directory and its contents stay protected while the
            // device is locked. The body is encrypted even if this attribute
            // cannot be applied by a particular filesystem implementation.
            try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: destination.path)
        } catch {
            // Cache persistence is optional; a validated network response is
            // still returned to the caller when the filesystem is unavailable.
        }
    }

    func invalidate(for config: PlaylistConfig) {
        guard let url = config.m3uURL,
              let masterKeyData = loadOrCreateMasterKeyData(),
              let directory = try? cacheDirectory()
        else { return }
        let scopeKey = Self.scopeKey(for: config, url: url, masterKeyData: masterKeyData)
        try? FileManager.default.removeItem(at: Self.fileURL(scopeKey: scopeKey, in: directory))
    }

    static func responseAllowsPersistence(
        _ response: M3UHTTPResponseMetadata,
        fallbackVary: String? = nil
    ) -> Bool {
        let cacheDirectives = (response.cacheControl ?? "")
            .split(separator: ",")
            .compactMap { directive -> String? in
                guard let name = directive.split(separator: "=", maxSplits: 1).first else { return nil }
                return String(name).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
        guard !cacheDirectives.contains("no-store") else { return false }

        let varyValue = (response.vary ?? fallbackVary ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !varyValue.isEmpty else { return true }
        let varyFields = varyValue
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        return !varyFields.isEmpty && varyFields.allSatisfy { $0 == "user-agent" }
    }

    static func responseValidatorsMatch(_ response: M3UHTTPResponseMetadata, snapshot: Snapshot) -> Bool {
        if let storedETag = snapshot.etag {
            return safeETag(response.etag) == storedETag
        }
        if let storedLastModified = snapshot.lastModified {
            return safeETag(response.etag) == nil
                && safeHTTPDate(response.lastModified) == storedLastModified
        }
        return false
    }

    static func responseHasUsableValidator(_ response: M3UHTTPResponseMetadata) -> Bool {
        safeETag(response.etag) != nil || safeHTTPDate(response.lastModified) != nil
    }

    private func loadSnapshot(scopeKey: String, masterKeyData: Data) -> Snapshot? {
        guard let directory = try? cacheDirectory() else { return nil }
        let fileURL = Self.fileURL(scopeKey: scopeKey, in: directory)
        do {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile == true,
                  let fileSize = values.fileSize,
                  (1 ... Self.maximumSnapshotFileBytes).contains(fileSize)
            else {
                try? FileManager.default.removeItem(at: fileURL)
                return nil
            }

            let data = try Data(contentsOf: fileURL)
            let envelope = try PropertyListDecoder().decode(DiskEnvelope.self, from: data)
            guard envelope.version == Self.schemaVersion else {
                try? FileManager.default.removeItem(at: fileURL)
                return nil
            }
            let sealedBox = try AES.GCM.SealedBox(combined: envelope.sealedPayload)
            let plaintext = try AES.GCM.open(
                sealedBox,
                using: Self.encryptionKey(masterKeyData),
                authenticating: Self.authenticatedData(for: scopeKey)
            )
            let payload = try PropertyListDecoder().decode(Payload.self, from: plaintext)
            let age = Date().timeIntervalSince(payload.updatedAt)
            guard payload.body.count <= Self.maximumPersistedBodyBytes,
                  age >= 0,
                  age <= Self.maximumAge
            else {
                try? FileManager.default.removeItem(at: fileURL)
                return nil
            }
            return Snapshot(
                body: payload.body,
                etag: Self.safeETag(payload.etag),
                lastModified: Self.safeHTTPDate(payload.lastModified),
                vary: Self.safeHeaderValue(payload.vary)
            )
        } catch {
            // A corrupt, unsupported, or unauthentic file must never supply a
            // response body or validator to a conditional request.
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }
    }

    private func loadOrCreateMasterKeyData() -> Data? {
        if let cachedMasterKeyData {
            return cachedMasterKeyData
        }

        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
        ]
        var readQuery = baseQuery
        readQuery[kSecReturnData as String] = true
        readQuery[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let readStatus = SecItemCopyMatching(readQuery as CFDictionary, &item)
        if readStatus == errSecSuccess {
            guard let data = item as? Data else { return nil }
            if data.count == 32 {
                cachedMasterKeyData = data
                return data
            }
            let deleteStatus = SecItemDelete(baseQuery as CFDictionary)
            guard deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound else { return nil }
        }
        guard readStatus == errSecItemNotFound || readStatus == errSecSuccess else {
            return nil
        }

        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        var addQuery = baseQuery
        addQuery[kSecValueData as String] = keyData
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecSuccess {
            cachedMasterKeyData = keyData
            return keyData
        }
        if addStatus == errSecDuplicateItem {
            var retryItem: CFTypeRef?
            let retryStatus = SecItemCopyMatching(readQuery as CFDictionary, &retryItem)
            if retryStatus == errSecSuccess, let data = retryItem as? Data, data.count == 32 {
                cachedMasterKeyData = data
                return data
            }
        }
        return nil
    }

    private func cacheDirectory() throws -> URL {
        guard let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        return cachesDirectory
            .appendingPathComponent("PureIPTV", isDirectory: true)
            .appendingPathComponent("EncryptedM3UCache-v1", isDirectory: true)
    }

    private func evictExpiredFiles(in directory: URL) throws {
        let files = try ownedCacheFiles(in: directory)
        let expiration = Date().addingTimeInterval(-Self.maximumAge)
        for file in files {
            let values = try file.resourceValues(forKeys: [.contentModificationDateKey])
            if let modified = values.contentModificationDate, modified < expiration {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    private func makeRoom(for byteCount: Int, replacing target: URL, in directory: URL) throws {
        var files = try ownedCacheFiles(in: directory).filter { $0 != target }
        func totalBytes() -> Int {
            files.reduce(into: 0) { total, file in
                let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                total += size
            }
        }

        files.sort { lhs, rhs in
            let leftDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? nil
            let rightDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? nil
            return (leftDate ?? .distantPast) < (rightDate ?? .distantPast)
        }
        var currentBytes = totalBytes()
        while currentBytes + byteCount > Self.maximumDirectoryBytes, let oldest = files.first {
            try FileManager.default.removeItem(at: oldest)
            files.removeFirst()
            currentBytes = totalBytes()
        }
    }

    private func ownedCacheFiles(in directory: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ).filter { file in
            guard file.lastPathComponent.hasPrefix(Self.filePrefix),
                  file.pathExtension == "bin"
            else { return false }
            return (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        }
    }

    private static func fileURL(scopeKey: String, in directory: URL) -> URL {
        directory.appendingPathComponent("\(filePrefix)\(scopeKey).bin", isDirectory: false)
    }

    private static func scopeKey(for config: PlaylistConfig, url: URL, masterKeyData: Data) -> String {
        let trimmedOverride = config.userAgentOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        let userAgent = trimmedOverride.flatMap { $0.isEmpty ? nil : $0 } ?? UserAgentManager.resolveUserAgent()
        let components = [
            config.type.rawValue,
            url.absoluteString,
            config.username ?? "",
            config.password ?? "",
            userAgent,
        ]
        var identity = Data("PureIPTV.M3U.cache.scope.v1".utf8)
        for component in components {
            let bytes = Data(component.utf8)
            var length = UInt64(bytes.count).bigEndian
            withUnsafeBytes(of: &length) { identity.append(contentsOf: $0) }
            identity.append(bytes)
        }

        let hmacKey = SymmetricKey(data: masterKeyData)
        let code = HMAC<SHA256>.authenticationCode(for: identity, using: Self.derivedKey(hmacKey, info: "scope"))
        return code.map { String(format: "%02x", $0) }.joined()
    }

    private static func encryptionKey(_ masterKeyData: Data) -> SymmetricKey {
        derivedKey(SymmetricKey(data: masterKeyData), info: "encryption")
    }

    private static func derivedKey(_ masterKey: SymmetricKey, info: String) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(
            inputKeyMaterial: masterKey,
            salt: Data("PureIPTV.M3U.cache.v1".utf8),
            info: Data(info.utf8),
            outputByteCount: 32
        )
    }

    private static func authenticatedData(for scopeKey: String) -> Data {
        Data("PureIPTV.M3U.cache.payload.v1:\(scopeKey)".utf8)
    }

    private static func safeHeaderValue(_ value: String?) -> String? {
        guard let value,
              value.utf8.count <= 4096,
              !value.contains("\r"),
              !value.contains("\n")
        else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func safeETag(_ value: String?) -> String? {
        guard let value = safeHeaderValue(value) else { return nil }
        let opaqueTag = value.hasPrefix("W/") ? value.dropFirst(2) : value[...]
        guard opaqueTag.count >= 2,
              opaqueTag.first == "\"",
              opaqueTag.last == "\""
        else { return nil }

        let opaqueBytes = opaqueTag.dropFirst().dropLast().unicodeScalars
        guard opaqueBytes.allSatisfy({ scalar in
            let value = scalar.value
            return value == 0x21 || (0x23 ... 0x7E).contains(value) || (0x80 ... 0xFF).contains(value)
        }) else { return nil }
        return value
    }

    private static func safeHTTPDate(_ value: String?) -> String? {
        guard let value = safeHeaderValue(value) else { return nil }
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss 'GMT'",
            "EEEE, dd-MMM-yy HH:mm:ss 'GMT'",
            "EEE MMM d HH:mm:ss yyyy",
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.isLenient = false
        for format in formats {
            formatter.dateFormat = format
            if formatter.date(from: value) != nil {
                return value
            }
        }
        return nil
    }
}
