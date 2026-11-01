import ComposableArchitecture
import Foundation

public enum PlaylistRefreshTarget: String, CaseIterable, Codable, Equatable, Hashable, Identifiable, Sendable {
    case live
    case movies
    case series
    case epg

    public var id: String {
        rawValue
    }

    public var defaultInterval: PlaylistRefreshInterval {
        switch self {
        case .live: .daily
        case .movies, .series: .everyThreeDays
        case .epg: .fourHours
        }
    }

    public var title: String {
        switch self {
        case .live: AppStrings.PlaylistMgmt.liveTVRefreshFrequency
        case .movies: AppStrings.PlaylistMgmt.moviesRefreshFrequency
        case .series: AppStrings.PlaylistMgmt.seriesRefreshFrequency
        case .epg: AppStrings.Player.epg
        }
    }
}

public enum PlaylistRefreshInterval: Int, CaseIterable, Codable, Equatable, Hashable, Identifiable, Sendable {
    case disabled = 0
    case oneHour = 1
    case fourHours = 4
    case twelveHours = 12
    case daily = 24
    case everyThreeDays = 72
    case weekly = 168

    public var id: Int {
        rawValue
    }

    public var duration: TimeInterval? {
        guard rawValue > 0 else { return nil }
        return TimeInterval(rawValue * 60 * 60)
    }

    public var title: String {
        switch self {
        case .disabled: AppStrings.Player.off
        case .oneHour: AppStrings.PlaylistMgmt.refreshEveryOneHour
        case .fourHours: AppStrings.PlaylistMgmt.refreshEveryFourHours
        case .twelveHours: AppStrings.PlaylistMgmt.refreshEveryTwelveHours
        case .daily: AppStrings.PlaylistMgmt.refreshEveryDay
        case .everyThreeDays: AppStrings.PlaylistMgmt.refreshEveryThreeDays
        case .weekly: AppStrings.PlaylistMgmt.refreshEveryWeek
        }
    }

    public static func epgInterval(for interval: EPGAutoRefreshInterval) -> Self {
        switch interval {
        case .fourHours: .fourHours
        case .twelveHours: .twelveHours
        case .twentyFourHours: .daily
        }
    }
}

public nonisolated struct PlaylistRefreshSchedule: Equatable, Sendable {
    public var live: PlaylistRefreshInterval
    public var movies: PlaylistRefreshInterval
    public var series: PlaylistRefreshInterval
    public var epg: PlaylistRefreshInterval

    public init(
        live: PlaylistRefreshInterval = .daily,
        movies: PlaylistRefreshInterval = .everyThreeDays,
        series: PlaylistRefreshInterval = .everyThreeDays,
        epg: PlaylistRefreshInterval = .fourHours
    ) {
        self.live = live
        self.movies = movies
        self.series = series
        self.epg = epg
    }

    public subscript(target: PlaylistRefreshTarget) -> PlaylistRefreshInterval {
        get {
            switch target {
            case .live: live
            case .movies: movies
            case .series: series
            case .epg: epg
            }
        }
        set {
            switch target {
            case .live: live = newValue
            case .movies: movies = newValue
            case .series: series = newValue
            case .epg: epg = newValue
            }
        }
    }
}

public struct PlaylistRefreshScheduleClient: Sendable {
    public var interval: @Sendable (
        _ profileID: UUID?,
        _ playlistID: UUID?,
        _ target: PlaylistRefreshTarget,
        _ defaultValue: PlaylistRefreshInterval
    ) -> PlaylistRefreshInterval

    public var setInterval: @Sendable (
        _ interval: PlaylistRefreshInterval,
        _ profileID: UUID?,
        _ playlistID: UUID?,
        _ target: PlaylistRefreshTarget
    ) -> Void

    public var claimAutomaticRefresh: @Sendable (
        _ profileID: UUID?,
        _ playlistID: UUID?,
        _ target: PlaylistRefreshTarget,
        _ interval: PlaylistRefreshInterval,
        _ now: Date
    ) -> Bool

    public var markSuccessfulRefresh: @Sendable (
        _ profileID: UUID?,
        _ playlistID: UUID?,
        _ target: PlaylistRefreshTarget,
        _ date: Date
    ) -> Void

    public var clearAutomaticRefreshAttempt: @Sendable (
        _ profileID: UUID?,
        _ playlistID: UUID?,
        _ target: PlaylistRefreshTarget
    ) -> Void

    public init(
        interval: @escaping @Sendable (UUID?, UUID?, PlaylistRefreshTarget, PlaylistRefreshInterval) -> PlaylistRefreshInterval,
        setInterval: @escaping @Sendable (PlaylistRefreshInterval, UUID?, UUID?, PlaylistRefreshTarget) -> Void,
        claimAutomaticRefresh: @escaping @Sendable (UUID?, UUID?, PlaylistRefreshTarget, PlaylistRefreshInterval, Date) -> Bool,
        markSuccessfulRefresh: @escaping @Sendable (UUID?, UUID?, PlaylistRefreshTarget, Date) -> Void,
        clearAutomaticRefreshAttempt: @escaping @Sendable (UUID?, UUID?, PlaylistRefreshTarget) -> Void
    ) {
        self.interval = interval
        self.setInterval = setInterval
        self.claimAutomaticRefresh = claimAutomaticRefresh
        self.markSuccessfulRefresh = markSuccessfulRefresh
        self.clearAutomaticRefreshAttempt = clearAutomaticRefreshAttempt
    }
}

extension PlaylistRefreshScheduleClient: DependencyKey {
    public static let liveValue: PlaylistRefreshScheduleClient = {
        let defaults = UserDefaults.standard
        let prefix = "com.pureiptv.playlistRefreshSchedule.v1"

        let key: @Sendable (UUID?, UUID?, PlaylistRefreshTarget, String) -> String? = {
            profileID, playlistID, target, field in
            guard let playlistID else { return nil }
            let profileKey = profileID?.uuidString ?? "default"
            return "\(prefix).\(profileKey).\(playlistID.uuidString).\(target.rawValue).\(field)"
        }

        return PlaylistRefreshScheduleClient(
            interval: { profileID, playlistID, target, defaultValue in
                guard let storageKey = key(profileID, playlistID, target, "interval"),
                      let rawValue = defaults.object(forKey: storageKey) as? Int,
                      let interval = PlaylistRefreshInterval(rawValue: rawValue)
                else { return defaultValue }
                return interval
            },
            setInterval: { interval, profileID, playlistID, target in
                guard let storageKey = key(profileID, playlistID, target, "interval") else { return }
                defaults.set(interval.rawValue, forKey: storageKey)
            },
            claimAutomaticRefresh: { profileID, playlistID, target, interval, now in
                guard let duration = interval.duration,
                      let attemptKey = key(profileID, playlistID, target, "lastAttempt"),
                      let successKey = key(profileID, playlistID, target, "lastSuccess") else { return false }
                let storedLastSuccess = defaults.object(forKey: successKey) as? Date
                let storedLastAttempt = defaults.object(forKey: attemptKey) as? Date
                let latestDate = [storedLastSuccess, storedLastAttempt].compactMap(\.self).max() ?? .distantPast
                guard now.timeIntervalSince(latestDate) >= duration else { return false }
                defaults.set(now, forKey: attemptKey)
                return true
            },
            markSuccessfulRefresh: { profileID, playlistID, target, date in
                guard let successKey = key(profileID, playlistID, target, "lastSuccess") else { return }
                defaults.set(date, forKey: successKey)
            },
            clearAutomaticRefreshAttempt: { profileID, playlistID, target in
                guard let attemptKey = key(profileID, playlistID, target, "lastAttempt") else { return }
                defaults.removeObject(forKey: attemptKey)
            }
        )
    }()

    public static let testValue = PlaylistRefreshScheduleClient(
        interval: { _, _, _, defaultValue in defaultValue },
        setInterval: { _, _, _, _ in },
        claimAutomaticRefresh: { _, _, _, _, _ in false },
        markSuccessfulRefresh: { _, _, _, _ in },
        clearAutomaticRefreshAttempt: { _, _, _ in }
    )
}

public extension DependencyValues {
    var playlistRefreshScheduleClient: PlaylistRefreshScheduleClient {
        get { self[PlaylistRefreshScheduleClient.self] }
        set { self[PlaylistRefreshScheduleClient.self] = newValue }
    }
}
