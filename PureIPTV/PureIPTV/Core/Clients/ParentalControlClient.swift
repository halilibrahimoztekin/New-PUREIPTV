import ComposableArchitecture
import Foundation
#if canImport(LocalAuthentication)
    import LocalAuthentication
#endif

// MARK: - HiddenItemDTO

public struct HiddenItemDTO: Identifiable, Equatable, Hashable, Sendable, Codable {
    public let id: String
    public let title: String
    public let type: HiddenItemType
    public let hiddenAt: Date

    public enum HiddenItemType: String, Equatable, Hashable, Sendable, Codable, CaseIterable {
        case channel
        case category
    }

    public init(id: String, title: String, type: HiddenItemType, hiddenAt: Date = Date()) {
        self.id = id
        self.title = title
        self.type = type
        self.hiddenAt = hiddenAt
    }
}

// MARK: - ParentalControlClient

@DependencyClient
public struct ParentalControlClient: Sendable {
    public var isParentalControlEnabled: @Sendable () -> Bool = { false }
    public var verifyPIN: @Sendable (_ pin: String) -> Bool = { _ in true }
    public var setParentalPIN: @Sendable (_ pin: String?, _ enabled: Bool) -> Void
    public var hasPIN: @Sendable () -> Bool = { false }
    public var isAdultContent: @Sendable (_ text: String) -> Bool = { _ in false }
    public var authenticateWithBiometrics: @Sendable (_ reason: String) async -> Bool = { _ in false }

    public var hiddenChannelIDs: @Sendable () -> Set<String> = { [] }
    public var hideChannel: @Sendable (_ id: String, _ title: String) -> Void
    public var unhideChannel: @Sendable (_ id: String) -> Void
    public var unhideAllChannels: @Sendable () -> Void
    public var isChannelHidden: @Sendable (_ id: String) -> Bool = { _ in false }

    public var blacklistedCategoryIDs: @Sendable () -> Set<String> = { [] }
    public var blacklistCategory: @Sendable (_ id: String, _ title: String) -> Void
    public var unblacklistCategory: @Sendable (_ id: String) -> Void
    public var unblacklistAllCategories: @Sendable () -> Void
    public var isCategoryBlacklisted: @Sendable (_ id: String) -> Bool = { _ in false }

    public var fetchHiddenChannels: @Sendable () -> [HiddenItemDTO] = { [] }
    public var fetchBlacklistedCategories: @Sendable () -> [HiddenItemDTO] = { [] }
}

// MARK: - DependencyKey & Live Value

extension ParentalControlClient: DependencyKey {
    public static let liveValue: ParentalControlClient = {
        let defaults = UserDefaults.standard
        let pinKey = "com.pureiptv.parentalPIN"
        let enabledKey = "com.pureiptv.parentalControlEnabled"
        let hiddenChannelsKey = "com.pureiptv.hiddenChannelsMetadata"
        let legacyHiddenChannelsKey = "PureIPTV.hiddenChannelIDs"
        let blacklistedCategoriesKey = "com.pureiptv.blacklistedCategoriesMetadata"

        @Sendable func loadHiddenItems(key: String) -> [HiddenItemDTO] {
            guard let data = defaults.data(forKey: key) else { return [] }
            let decoder = JSONDecoder()
            return (try? decoder.decode([HiddenItemDTO].self, from: data)) ?? []
        }

        @Sendable func saveHiddenItems(_ items: [HiddenItemDTO], key: String) {
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(items) {
                defaults.set(data, forKey: key)
            }
        }

        return ParentalControlClient(
            isParentalControlEnabled: {
                defaults.bool(forKey: enabledKey)
            },
            verifyPIN: { inputPin in
                guard defaults.bool(forKey: enabledKey) else {
                    return true
                }
                let savedPin = (try? KeychainManager.shared.retrieve(for: pinKey, as: String.self)) ?? defaults.string(forKey: pinKey)
                guard let savedPin else {
                    return true
                }
                return savedPin == inputPin
            },
            setParentalPIN: { pin, enabled in
                defaults.set(enabled, forKey: enabledKey)
                if let pin, enabled {
                    try? KeychainManager.shared.save(pin, for: pinKey)
                    defaults.removeObject(forKey: pinKey)
                } else {
                    try? KeychainManager.shared.delete(for: pinKey)
                    defaults.removeObject(forKey: pinKey)
                }
            },
            hasPIN: {
                let savedPin = (try? KeychainManager.shared.retrieve(for: pinKey, as: String.self)) ?? defaults.string(forKey: pinKey)
                return savedPin != nil && !(savedPin?.isEmpty ?? true)
            },
            isAdultContent: { text in
                let lowercased = text.lowercased()
                let adultKeywords = ["adult", "xxx", "18+", "yetişkin", "porn", "erotic", "nsfw"]
                return adultKeywords.contains { lowercased.contains($0) }
            },
            authenticateWithBiometrics: { reason in
                #if os(tvOS)
                    return false
                #else
                    let context = LAContext()
                    var error: NSError?
                    if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                        do {
                            return try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
                        } catch {
                            return false
                        }
                    }
                    return false
                #endif
            },
            hiddenChannelIDs: {
                let items = loadHiddenItems(key: hiddenChannelsKey)
                var ids = Set(items.map(\.id))
                // Merge legacy format if exists
                if let legacy = defaults.stringArray(forKey: legacyHiddenChannelsKey) {
                    ids.formUnion(legacy)
                }
                return ids
            },
            hideChannel: { id, title in
                var items = loadHiddenItems(key: hiddenChannelsKey)
                if !items.contains(where: { $0.id == id }) {
                    items.append(HiddenItemDTO(id: id, title: title, type: .channel))
                    saveHiddenItems(items, key: hiddenChannelsKey)
                }
                // Update legacy key as well for backward compatibility
                var legacy = Set(defaults.stringArray(forKey: legacyHiddenChannelsKey) ?? [])
                legacy.insert(id)
                defaults.set(Array(legacy), forKey: legacyHiddenChannelsKey)
            },
            unhideChannel: { id in
                var items = loadHiddenItems(key: hiddenChannelsKey)
                items.removeAll { $0.id == id }
                saveHiddenItems(items, key: hiddenChannelsKey)

                var legacy = Set(defaults.stringArray(forKey: legacyHiddenChannelsKey) ?? [])
                legacy.remove(id)
                defaults.set(Array(legacy), forKey: legacyHiddenChannelsKey)
            },
            unhideAllChannels: {
                defaults.removeObject(forKey: hiddenChannelsKey)
                defaults.removeObject(forKey: legacyHiddenChannelsKey)
            },
            isChannelHidden: { id in
                let items = loadHiddenItems(key: hiddenChannelsKey)
                if items.contains(where: { $0.id == id }) {
                    return true
                }
                if let legacy = defaults.stringArray(forKey: legacyHiddenChannelsKey), legacy.contains(id) {
                    return true
                }
                return false
            },
            blacklistedCategoryIDs: {
                let items = loadHiddenItems(key: blacklistedCategoriesKey)
                return Set(items.map(\.id))
            },
            blacklistCategory: { id, title in
                var items = loadHiddenItems(key: blacklistedCategoriesKey)
                if !items.contains(where: { $0.id == id }) {
                    items.append(HiddenItemDTO(id: id, title: title, type: .category))
                    saveHiddenItems(items, key: blacklistedCategoriesKey)
                }
            },
            unblacklistCategory: { id in
                var items = loadHiddenItems(key: blacklistedCategoriesKey)
                items.removeAll { $0.id == id }
                saveHiddenItems(items, key: blacklistedCategoriesKey)
            },
            unblacklistAllCategories: {
                defaults.removeObject(forKey: blacklistedCategoriesKey)
            },
            isCategoryBlacklisted: { id in
                let items = loadHiddenItems(key: blacklistedCategoriesKey)
                return items.contains(where: { $0.id == id })
            },
            fetchHiddenChannels: {
                var items = loadHiddenItems(key: hiddenChannelsKey)
                if items.isEmpty, let legacy = defaults.stringArray(forKey: legacyHiddenChannelsKey), !legacy.isEmpty {
                    items = legacy.map { HiddenItemDTO(id: $0, title: "Kanal #\($0)", type: .channel) }
                }
                return items.sorted(by: { $0.hiddenAt > $1.hiddenAt })
            },
            fetchBlacklistedCategories: {
                let items = loadHiddenItems(key: blacklistedCategoriesKey)
                return items.sorted(by: { $0.hiddenAt > $1.hiddenAt })
            }
        )
    }()

    public static let testValue: ParentalControlClient = .init(
        isParentalControlEnabled: { false },
        verifyPIN: { _ in true },
        setParentalPIN: { _, _ in },
        hasPIN: { true },
        isAdultContent: { $0.lowercased().contains("adult") || $0.lowercased().contains("xxx") },
        authenticateWithBiometrics: { _ in true },
        hiddenChannelIDs: { [] },
        hideChannel: { _, _ in },
        unhideChannel: { _ in },
        unhideAllChannels: {},
        isChannelHidden: { _ in false },
        blacklistedCategoryIDs: { [] },
        blacklistCategory: { _, _ in },
        unblacklistCategory: { _ in },
        unblacklistAllCategories: {},
        isCategoryBlacklisted: { _ in false },
        fetchHiddenChannels: { [] },
        fetchBlacklistedCategories: { [] }
    )
}

// MARK: - DependencyValues

public extension DependencyValues {
    var parentalControlClient: ParentalControlClient {
        get { self[ParentalControlClient.self] }
        set { self[ParentalControlClient.self] = newValue }
    }
}
