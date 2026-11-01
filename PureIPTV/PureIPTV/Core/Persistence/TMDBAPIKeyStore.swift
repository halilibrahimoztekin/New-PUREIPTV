import Foundation
import Security

actor TMDBAPIKeyStore {
    nonisolated static let shared = TMDBAPIKeyStore()

    private static let fallbackAPIKey = "8265bd1679663a7ea12ac168da84d2e8"
    private static let keychainAccount = "personal-v3-api-key"
    private static let keychainAccessibility = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

    private let keychainService: String
    private var cachedUserAPIKey: String?
    private var hasLoadedUserAPIKey = false

    init(bundleIdentifier: String? = Bundle.main.bundleIdentifier) {
        keychainService = "\(bundleIdentifier ?? "com.pureiptv").tmdb-api-key"
    }

    func hasStoredAPIKey() throws -> Bool {
        try userAPIKey() != nil
    }

    func effectiveAPIKey() throws -> String {
        try userAPIKey() ?? Self.fallbackAPIKey
    }

    func saveUserAPIKey(_ apiKey: String) throws {
        let data = Data(apiKey.utf8)
        var addQuery = baseQuery()
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = Self.keychainAccessibility

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        switch addStatus {
        case errSecSuccess:
            break
        case errSecDuplicateItem:
            let updateAttributes: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrAccessible as String: Self.keychainAccessibility,
            ]
            let updateStatus = SecItemUpdate(baseQuery() as CFDictionary, updateAttributes as CFDictionary)
            try Self.requireSuccessfulUpdate(updateStatus)
        case errSecInteractionNotAllowed:
            throw TMDBAPIKeyStoreError.keychainStatus(addStatus)
        default:
            throw TMDBAPIKeyStoreError.keychainStatus(addStatus)
        }

        cachedUserAPIKey = apiKey
        hasLoadedUserAPIKey = true
    }

    func deleteUserAPIKey() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        switch status {
        case errSecSuccess, errSecItemNotFound:
            cachedUserAPIKey = nil
            hasLoadedUserAPIKey = true
        case errSecInteractionNotAllowed:
            throw TMDBAPIKeyStoreError.keychainStatus(status)
        default:
            throw TMDBAPIKeyStoreError.keychainStatus(status)
        }
    }

    private func userAPIKey() throws -> String? {
        if hasLoadedUserAPIKey {
            return cachedUserAPIKey
        }

        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let value = String(data: data, encoding: .utf8),
                  !value.isEmpty
            else {
                throw TMDBAPIKeyStoreError.invalidStoredValue
            }
            cachedUserAPIKey = value
            hasLoadedUserAPIKey = true
            return value
        case errSecItemNotFound:
            cachedUserAPIKey = nil
            hasLoadedUserAPIKey = true
            return nil
        case errSecInteractionNotAllowed:
            throw TMDBAPIKeyStoreError.keychainStatus(status)
        default:
            throw TMDBAPIKeyStoreError.keychainStatus(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
        ]
        #if os(macOS)
            query[kSecUseDataProtectionKeychain as String] = true
        #endif
        return query
    }

    private static func requireSuccessfulUpdate(_ status: OSStatus) throws {
        switch status {
        case errSecSuccess:
            return
        case errSecInteractionNotAllowed:
            throw TMDBAPIKeyStoreError.keychainStatus(status)
        default:
            throw TMDBAPIKeyStoreError.keychainStatus(status)
        }
    }
}

enum TMDBAPIKeyStoreError: Error {
    case invalidStoredValue
    case keychainStatus(OSStatus)
}
