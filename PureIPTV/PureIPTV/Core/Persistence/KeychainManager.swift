import Foundation
import Security

public enum KeychainError: Error {
    case duplicateEntry
    case unknown(OSStatus)
    case itemNotFound
    case decodingError
}

public final class KeychainManager {
    public static let shared = KeychainManager()

    private init() {}

    /// Saves a Codable object to Keychain securely and syncs via iCloud
    public func save<T: Codable>(_ item: T, for key: String) throws {
        let data = try JSONEncoder().encode(item)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrSynchronizable as String: kCFBooleanTrue!, // Enable iCloud Sync
        ]

        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unknown(status)
        }
    }

    /// Retrieves a Codable object from Keychain
    public func retrieve<T: Codable>(for key: String, as type: T.Type) throws -> T {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrSynchronizable as String: kCFBooleanTrue!,
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
    public func delete(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: kCFBooleanTrue!,
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknown(status)
        }
    }
}
