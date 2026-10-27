import Foundation

public nonisolated enum PlaybackContentKind: String, CaseIterable, Codable, Equatable, Hashable, Identifiable, Sendable {
    case live
    case vod
    case archive

    public var id: Self { self }

    public var title: String {
        switch self {
        case .live: "Canlı"
        case .vod: "Film / Dizi"
        case .archive: "Arşiv"
        }
    }

    public static func resolve(isLive: Bool, isArchive: Bool) -> Self {
        if isArchive { return .archive }
        return isLive ? .live : .vod
    }
}

public nonisolated enum BufferProfile: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case lowLatency = "Düşük Gecikme (1s)"
    case balanced = "Dengeli (3s)"
    case smooth = "Kesintisiz / Yüksek Arabellek (8s)"

    public var seconds: Double {
        switch self {
        case .lowLatency: 1.0
        case .balanced: 3.0
        case .smooth: 8.0
        }
    }

    public var networkCachingMilliseconds: Int {
        Int(seconds * 1000)
    }

    public static func activeNetworkCachingMilliseconds(for isLive: Bool) -> Int? {
        guard !isLive else { return nil }
        let key = "pureiptv_buffer_profile"
        let storedValue = UserDefaults.standard.string(forKey: key)
        let profile = storedValue.flatMap(Self.init(rawValue:)) ?? .balanced
        return profile.networkCachingMilliseconds
    }
}

public nonisolated enum PlaybackBufferChoice: String, CaseIterable, Codable, Equatable, Hashable, Identifiable, Sendable {
    case automatic
    case lowLatency
    case balanced
    case smooth

    public var id: Self { self }

    public var title: String {
        switch self {
        case .automatic: "Otomatik"
        case .lowLatency: BufferProfile.lowLatency.rawValue
        case .balanced: BufferProfile.balanced.rawValue
        case .smooth: BufferProfile.smooth.rawValue
        }
    }

    public var profile: BufferProfile? {
        switch self {
        case .automatic: nil
        case .lowLatency: .lowLatency
        case .balanced: .balanced
        case .smooth: .smooth
        }
    }

    public static func choice(for profile: BufferProfile) -> Self {
        switch profile {
        case .lowLatency: .lowLatency
        case .balanced: .balanced
        case .smooth: .smooth
        }
    }
}

public nonisolated struct PlaybackDefaults: Codable, Equatable, Sendable {
    public var preferredEngine: PlaybackEngine
    public var preferredAudioLanguage: String
    public var preferredSubtitleLanguage: String
    public var subtitleTextSize: SubtitleTextSize
    public var bufferChoice: PlaybackBufferChoice
    public var deinterlaceMode: DeinterlaceMode
    public var isAFREnabled: Bool
    public var isMatchDynamicRangeEnabled: Bool

    public init(
        preferredEngine: PlaybackEngine = .vlc,
        preferredAudioLanguage: String = "tr",
        preferredSubtitleLanguage: String = "off",
        subtitleTextSize: SubtitleTextSize = .standard,
        bufferChoice: PlaybackBufferChoice = .automatic,
        deinterlaceMode: DeinterlaceMode = .automatic,
        isAFREnabled: Bool = true,
        isMatchDynamicRangeEnabled: Bool = true
    ) {
        self.preferredEngine = preferredEngine
        self.preferredAudioLanguage = preferredAudioLanguage
        self.preferredSubtitleLanguage = preferredSubtitleLanguage
        self.subtitleTextSize = subtitleTextSize
        self.bufferChoice = bufferChoice
        self.deinterlaceMode = deinterlaceMode
        self.isAFREnabled = isAFREnabled
        self.isMatchDynamicRangeEnabled = isMatchDynamicRangeEnabled
    }

    public static func legacy(for kind: PlaybackContentKind, defaults: UserDefaults = .standard) -> Self {
        let audio = defaults.string(forKey: "com.pureiptv.preferredAudioLanguage") ?? "tr"
        let subtitle = defaults.string(forKey: "com.pureiptv.preferredSubtitleLanguage") ?? "off"
        let subtitleSize = defaults.integer(forKey: "com.pureiptv.subtitleTextSize")
        let subtitleTextSize = SubtitleTextSize(rawValue: subtitleSize) ?? .standard

        let legacyBuffer = defaults.string(forKey: "pureiptv_buffer_profile")
            .flatMap(BufferProfile.init(rawValue:)) ?? .balanced
        let bufferChoice = kind == .vod ? PlaybackBufferChoice.choice(for: legacyBuffer) : .automatic

        let afrKey: String
        switch kind {
        case .live, .archive: afrKey = "com.pureiptv.afrEnabled.live"
        case .vod: afrKey = "com.pureiptv.afrEnabled.vod"
        }
        let afr = defaults.object(forKey: afrKey) as? Bool
            ?? defaults.object(forKey: "com.pureiptv.afrEnabled") as? Bool
            ?? true
        let matchDynamicRange = defaults.object(forKey: "com.pureiptv.matchDynamicRangeEnabled") as? Bool ?? true

        return Self(
            preferredAudioLanguage: audio,
            preferredSubtitleLanguage: subtitle,
            subtitleTextSize: subtitleTextSize,
            bufferChoice: bufferChoice,
            isAFREnabled: afr,
            isMatchDynamicRangeEnabled: matchDynamicRange
        )
    }

    public func networkCachingMilliseconds(for kind: PlaybackContentKind) -> Int? {
        if let profile = bufferChoice.profile {
            return profile.networkCachingMilliseconds
        }
        guard kind == .vod else { return nil }
        return BufferProfile.activeNetworkCachingMilliseconds(for: false)
    }
}

public nonisolated enum PlaybackPreferenceUpdate: Equatable, Sendable {
    case preferredEngine(PlaybackEngine)
    case preferredAudioLanguage(String)
    case preferredSubtitleLanguage(String)
    case subtitleTextSize(SubtitleTextSize)
    case bufferChoice(PlaybackBufferChoice)
    case deinterlaceMode(DeinterlaceMode)
    case isAFREnabled(Bool)
    case isMatchDynamicRangeEnabled(Bool)

    public func apply(to defaults: inout PlaybackDefaults) {
        switch self {
        case let .preferredEngine(value): defaults.preferredEngine = value
        case let .preferredAudioLanguage(value): defaults.preferredAudioLanguage = value
        case let .preferredSubtitleLanguage(value): defaults.preferredSubtitleLanguage = value
        case let .subtitleTextSize(value): defaults.subtitleTextSize = value
        case let .bufferChoice(value): defaults.bufferChoice = value
        case let .deinterlaceMode(value): defaults.deinterlaceMode = value
        case let .isAFREnabled(value): defaults.isAFREnabled = value
        case let .isMatchDynamicRangeEnabled(value): defaults.isMatchDynamicRangeEnabled = value
        }
    }
}

public nonisolated enum PlaybackDefaultsStore {
    private static let keyPrefix = "com.pureiptv.playbackDefaults.v1."

    public static func load(
        for kind: PlaybackContentKind,
        defaults: UserDefaults = .standard
    ) -> PlaybackDefaults {
        guard let data = defaults.data(forKey: keyPrefix + kind.rawValue),
              let value = try? JSONDecoder().decode(PlaybackDefaults.self, from: data)
        else {
            return .legacy(for: kind, defaults: defaults)
        }
        return value
    }

    public static func save(
        _ value: PlaybackDefaults,
        for kind: PlaybackContentKind,
        defaults: UserDefaults = .standard
    ) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: keyPrefix + kind.rawValue)
    }
}
