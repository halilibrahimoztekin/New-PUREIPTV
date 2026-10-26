import Foundation
import Security

public enum KeychainError: Error {
    case duplicateEntry
    case unknown(OSStatus)
    case itemNotFound
    case decodingError
}

public final class KeychainManager: @unchecked Sendable {
    public nonisolated static let shared = KeychainManager()

    private init() {}

    /// Saves a Codable object to Keychain securely and syncs via iCloud
    public nonisolated func save(_ item: some Codable, for key: String) throws {
        let data = try JSONEncoder().encode(item)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: true as CFBoolean, // Enable iCloud Sync
        ]

        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            if addStatus == errSecDuplicateItem {
                let retryStatus = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
                guard retryStatus == errSecSuccess else { throw KeychainError.unknown(retryStatus) }
                return
            }
            guard addStatus == errSecSuccess else { throw KeychainError.unknown(addStatus) }
            return
        }

        guard status == errSecSuccess else {
            throw KeychainError.unknown(status)
        }
    }

    /// Retrieves a Codable object from Keychain
    public nonisolated func retrieve<T: Codable>(for key: String, as type: T.Type) throws -> T {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true as CFBoolean,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrSynchronizable as String: true as CFBoolean,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status != errSecItemNotFound else {
            throw KeychainError.itemNotFound
        }

        guard status == errSecSuccess, let data = item as? Data else {
            throw KeychainError.unknown(status)
        }

        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw KeychainError.decodingError
        }
    }

    /// Deletes an item from Keychain
    public nonisolated func delete(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: true as CFBoolean,
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknown(status)
        }
    }
}
