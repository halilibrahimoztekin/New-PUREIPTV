import Foundation

public enum SportsFollowKind: String, Codable, CaseIterable, Sendable {
    case team
    case competition
}

public enum SportsFollowSyncError: Error, Equatable, LocalizedError {
    case invalidRecord
    case remoteStorageLimitExceeded
    case remoteStoreUnavailable

    public var errorDescription: String? {
        switch self {
        case .invalidRecord, .remoteStoreUnavailable:
            AppStrings.Dashboard.sportsFollowSyncUnavailable
        case .remoteStorageLimitExceeded:
            AppStrings.Dashboard.sportsFollowSyncLimitExceeded
        }
    }
}

/// Contains only a followed team or competition identity and its sync state.
/// It deliberately has no playlist, channel, stream, or provider fields.
public struct SportsFollowSyncRecord: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let kind: SportsFollowKind
    public let displayName: String
    public let profileID: UUID?
    public let isFollowing: Bool
    public let modifiedAt: Date
    public let deviceID: String

    public init(
        kind: SportsFollowKind,
        displayName: String,
        profileID: UUID?,
        isFollowing: Bool,
        modifiedAt: Date,
        deviceID: String
    ) {
        id = Self.identity(kind: kind, displayName: displayName)
        self.kind = kind
        self.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.profileID = profileID
        self.isFollowing = isFollowing
        self.modifiedAt = modifiedAt
        self.deviceID = deviceID
    }

    public var isValid: Bool {
        !displayName.isEmpty
            && displayName.count <= 120
            && id == Self.identity(kind: kind, displayName: displayName)
            && !deviceID.isEmpty
            && deviceID.count <= 128
    }

    public func wins(over current: SportsFollowSyncRecord) -> Bool {
        if modifiedAt != current.modifiedAt {
            return modifiedAt > current.modifiedAt
        }
        if deviceID != current.deviceID {
            return deviceID > current.deviceID
        }
        if isFollowing != current.isFollowing {
            return !isFollowing
        }
        return displayName > current.displayName
    }

    public static func identity(kind: SportsFollowKind, displayName: String) -> String {
        let foldedName = displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let normalizedName = foldedName.unicodeScalars
            .filter(CharacterSet.alphanumerics.contains)
            .map { String($0) }
            .joined()
        return "\(kind.rawValue):\(normalizedName)"
    }
}
