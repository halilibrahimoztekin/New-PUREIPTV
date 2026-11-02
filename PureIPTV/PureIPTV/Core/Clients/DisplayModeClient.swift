import AVFoundation
import ComposableArchitecture
import Foundation
#if os(tvOS)
    import AVKit
#endif
#if canImport(QuartzCore)
    import QuartzCore
#endif
#if canImport(UIKit)
    import UIKit
#endif

#if os(tvOS)
    @MainActor
    private func activeDisplayManager() -> AVDisplayManager? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .avDisplayManager
    }
#endif

// MARK: - FrameRate Enum

/// Standard cinematic and broadcast video frame rates with associated refresh rates.
public enum FrameRate: Float, CaseIterable, Sendable, Codable, Equatable {
    case fps23_976 = 23.976
    case fps24 = 24.0
    case fps25 = 25.0
    case fps29_97 = 29.97
    case fps30 = 30.0
    case fps50 = 50.0
    case fps59_94 = 59.94
    case fps60 = 60.0
    case fps120 = 120.0

    public var displayHz: Float {
        switch self {
        case .fps23_976, .fps24:
            24.0
        case .fps25, .fps50:
            50.0
        case .fps29_97, .fps30, .fps59_94, .fps60:
            60.0
        case .fps120:
            120.0
        }
    }

    public var displayString: String {
        String(format: "%.2f Hz", displayHz)
    }

    public var label: String {
        switch self {
        case .fps23_976, .fps24:
            "24p (Sinematik Film)"
        case .fps25:
            "25 fps (PAL Standart)"
        case .fps29_97, .fps30:
            "30 fps (NTSC Standart)"
        case .fps50:
            "50 fps (Canlı Spor / TV)"
        case .fps59_94, .fps60:
            "60 fps (Yüksek Akıcılık)"
        case .fps120:
            "120 fps (ProMotion Ultra)"
        }
    }

    public var isCinematic: Bool {
        self == .fps23_976 || self == .fps24
    }
}

// MARK: - FrameRateDetector

/// Fast pattern analyzer that detects video stream frame rates from title tags, stream parameters, and metadata.
public enum FrameRateDetector {
    private static let fps50Regex = try? NSRegularExpression(
        pattern: #"\b(50fps|50\s*fps|50hz|50\s*hz)\b"#,
        options: .caseInsensitive
    )

    private static let fps60Regex = try? NSRegularExpression(
        pattern: #"\b(60fps|60\s*fps|60hz|60\s*hz|59\.94)\b"#,
        options: .caseInsensitive
    )

    private static let fps24Regex = try? NSRegularExpression(
        pattern: #"\b(24fps|24\s*fps|23\.976|23\.98|24p)\b"#,
        options: .caseInsensitive
    )

    private static let fps25Regex = try? NSRegularExpression(
        pattern: #"\b(25fps|25\s*fps|25p)\b"#,
        options: .caseInsensitive
    )

    private static let fps30Regex = try? NSRegularExpression(
        pattern: #"\b(30fps|30\s*fps|29\.97|30p)\b"#,
        options: .caseInsensitive
    )

    /// Detects target frame rate from stream title, URL, and media type.
    public static func detect(title: String, urlString: String? = nil, isLive: Bool) -> FrameRate {
        let combined = "\(title) \(urlString ?? "")"
        let range = NSRange(location: 0, length: combined.utf16.count)

        // 1. Explicit 50 FPS
        if let regex = fps50Regex, regex.firstMatch(in: combined, options: [], range: range) != nil {
            return .fps50
        }

        // 2. Explicit 60 FPS
        if let regex = fps60Regex, regex.firstMatch(in: combined, options: [], range: range) != nil {
            return .fps60
        }

        // 3. Explicit 24 FPS
        if let regex = fps24Regex, regex.firstMatch(in: combined, options: [], range: range) != nil {
            return .fps24
        }

        // 4. Explicit 25 FPS
        if let regex = fps25Regex, regex.firstMatch(in: combined, options: [], range: range) != nil {
            return .fps25
        }

        // 5. Explicit 30 FPS
        if let regex = fps30Regex, regex.firstMatch(in: combined, options: [], range: range) != nil {
            return .fps30
        }

        // 6. Heuristic defaults: Movies and VOD series are natively 24fps (23.976)
        if !isLive {
            return .fps24
        }

        // 7. Live TV default: European & Turkish broadcast streams standard is 50fps
        return .fps50
    }
}

// MARK: - DisplayMatchResult

public enum DisplayMatchStatus: Equatable, Sendable {
    /// A legacy rate recommendation. It does not confirm or perform a display switch.
    case suggestionOnly
    /// tvOS accepted a preferred criteria request; the resulting TV mode is not observable here.
    case requestSubmitted
    case systemMatchingDisabled
    case criteriaUnavailable
    case displayManagerUnavailable
    case unsupportedPlaybackEngine
    case partialMatchingUnsupported
    case unsupportedPlatform
}

public struct DisplayMatchResult: Equatable, Sendable {
    public let matchedRate: Float
    public let matchedRange: VideoDynamicRange
    public let message: String
    public let isJudderFree: Bool
    public let status: DisplayMatchStatus

    public init(
        matchedRate: Float,
        matchedRange: VideoDynamicRange,
        message: String,
        isJudderFree: Bool = true,
        status: DisplayMatchStatus = .suggestionOnly
    ) {
        self.matchedRate = matchedRate
        self.matchedRange = matchedRange
        self.message = message
        self.isJudderFree = isJudderFree
        self.status = status
    }
}

// MARK: - DisplayModeClient

@DependencyClient
public struct DisplayModeClient: Sendable {
    public var isAFREnabledForLive: @Sendable () -> Bool = { true }
    public var setAFREnabledForLive: @Sendable (_ enabled: Bool) -> Void
    public var isAFREnabledForVOD: @Sendable () -> Bool = { true }
    public var setAFREnabledForVOD: @Sendable (_ enabled: Bool) -> Void
    public var isMatchDynamicRangeEnabled: @Sendable () -> Bool = { true }
    public var setMatchDynamicRangeEnabled: @Sendable (_ enabled: Bool) -> Void
    public var currentDisplayRefreshRate: @Sendable () -> Float = { 60.0 }
    public var availableRefreshRates: @Sendable () -> [Float] = { [24.0, 50.0, 60.0] }
    /// Legacy target-rate estimate; it never changes the device display mode.
    public var switchDisplayMode: @Sendable (_ frameRate: Float, _ dynamicRange: VideoDynamicRange) async -> DisplayMatchResult = { rate, range in
        DisplayMatchResult(
            matchedRate: rate,
            matchedRange: range,
            message: "\(Int(rate)) Hz • Eşlendi (Judder-Free)"
        )
    }

    #if os(tvOS)
        public var applyPreferredDisplayCriteria: @Sendable (_ criteria: AVDisplayCriteria?) async -> DisplayMatchResult = { _ in
            DisplayMatchResult(
                matchedRate: 0,
                matchedRange: .unknown,
                message: AppStrings.Player.displayMatchDisplayUnavailable,
                isJudderFree: false,
                status: .displayManagerUnavailable
            )
        }
    #endif

    public var resetDisplayMode: @Sendable () async -> Void
}

// MARK: - DependencyKey & Live Value

extension DisplayModeClient: DependencyKey {
    public static let liveValue: DisplayModeClient = {
        let defaults = UserDefaults.standard
        let legacyAFRKey = "com.pureiptv.afrEnabled"
        let liveAFRKey = "com.pureiptv.afrEnabled.live"
        let vodAFRKey = "com.pureiptv.afrEnabled.vod"
        let matchRangeKey = "com.pureiptv.matchDynamicRangeEnabled"

        func afrPreference(for key: String) -> Bool {
            if let value = defaults.object(forKey: key) as? Bool {
                return value
            }
            return defaults.object(forKey: legacyAFRKey) as? Bool ?? true
        }

        var client = DisplayModeClient(
            isAFREnabledForLive: {
                afrPreference(for: liveAFRKey)
            },
            setAFREnabledForLive: { enabled in
                defaults.set(enabled, forKey: liveAFRKey)
            },
            isAFREnabledForVOD: {
                afrPreference(for: vodAFRKey)
            },
            setAFREnabledForVOD: { enabled in
                defaults.set(enabled, forKey: vodAFRKey)
            },
            isMatchDynamicRangeEnabled: {
                if defaults.object(forKey: matchRangeKey) == nil {
                    return true // Enabled by default
                }
                return defaults.bool(forKey: matchRangeKey)
            },
            setMatchDynamicRangeEnabled: { enabled in
                defaults.set(enabled, forKey: matchRangeKey)
            },
            currentDisplayRefreshRate: {
                #if os(tvOS)
                    if #available(tvOS 11.2, *) {
                        let currentMode = UIScreen.main.currentMode
                        // On tvOS available refresh rates depend on display mode
                        return 60.0
                    }
                    return 60.0
                #elseif os(iOS)
                    let maxFrames = Float(UIScreen.main.maximumFramesPerSecond)
                    return maxFrames > 0 ? maxFrames : 60.0
                #else
                    return 60.0
                #endif
            },
            availableRefreshRates: {
                #if os(tvOS)
                    return [24.0, 25.0, 30.0, 50.0, 60.0]
                #elseif os(iOS)
                    return [24.0, 30.0, 48.0, 60.0, 120.0]
                #else
                    return [60.0]
                #endif
            },
            switchDisplayMode: { frameRate, dynamicRange in
                let targetHz: Float = if frameRate <= 24.5 {
                    24.0
                } else if frameRate <= 30.0 {
                    30.0
                } else if frameRate <= 50.0 {
                    50.0
                } else if frameRate <= 60.0 {
                    60.0
                } else {
                    120.0
                }

                #if os(tvOS)
                // On tvOS, system AVPlayerViewController and AVDisplayManager automatically match display mode
                // when content matches criteria
                #elseif os(iOS)
                    // On iOS ProMotion displays, hint the runloop/CADisplayLink for optimal refresh pacing
                #endif

                let modeLabel = targetHz == 24.0 ? "24 Hz Sinematik (Judder-Free)" : (targetHz == 50.0 ? "50 Hz Canlı Spor Eşleme" : "\(Int(targetHz)) Hz Akıcı Mod")
                let dynamicLabel = dynamicRange.isHDR ? " • \(dynamicRange.shortBadge)" : ""

                return DisplayMatchResult(
                    matchedRate: targetHz,
                    matchedRange: dynamicRange,
                    message: "\(modeLabel)\(dynamicLabel)"
                )
            },
            resetDisplayMode: {
                #if os(tvOS)
                    await MainActor.run {
                        activeDisplayManager()?.preferredDisplayCriteria = nil
                    }
                #endif
            }
        )
        #if os(tvOS)
            client.applyPreferredDisplayCriteria = { criteria in
                await MainActor.run {
                    guard let displayManager = activeDisplayManager() else {
                        return DisplayMatchResult(
                            matchedRate: 0,
                            matchedRange: .unknown,
                            message: AppStrings.Player.displayMatchDisplayUnavailable,
                            isJudderFree: false,
                            status: .displayManagerUnavailable
                        )
                    }
                    guard displayManager.isDisplayCriteriaMatchingEnabled else {
                        displayManager.preferredDisplayCriteria = nil
                        return DisplayMatchResult(
                            matchedRate: 0,
                            matchedRange: .unknown,
                            message: AppStrings.Player.displayMatchSystemDisabled,
                            isJudderFree: false,
                            status: .systemMatchingDisabled
                        )
                    }
                    guard let criteria else {
                        displayManager.preferredDisplayCriteria = nil
                        return DisplayMatchResult(
                            matchedRate: 0,
                            matchedRange: .unknown,
                            message: AppStrings.Player.displayMatchCriteriaUnavailable,
                            isJudderFree: false,
                            status: .criteriaUnavailable
                        )
                    }

                    displayManager.preferredDisplayCriteria = criteria
                    return DisplayMatchResult(
                        matchedRate: 0,
                        matchedRange: .unknown,
                        message: AppStrings.Player.displayMatchRequested,
                        isJudderFree: false,
                        status: .requestSubmitted
                    )
                }
            }
        #endif
        return client
    }()

    public static let testValue: DisplayModeClient = {
        var client = DisplayModeClient()
        client.isAFREnabledForLive = { true }
        client.setAFREnabledForLive = { _ in }
        client.isAFREnabledForVOD = { true }
        client.setAFREnabledForVOD = { _ in }
        client.isMatchDynamicRangeEnabled = { true }
        client.setMatchDynamicRangeEnabled = { _ in }
        client.currentDisplayRefreshRate = { 60.0 }
        client.availableRefreshRates = { [24.0, 50.0, 60.0] }
        client.switchDisplayMode = { rate, range in
            DisplayMatchResult(
                matchedRate: rate,
                matchedRange: range,
                message: "\(Int(rate)) Hz • Eşlendi"
            )
        }
        #if os(tvOS)
            client.applyPreferredDisplayCriteria = { _ in
                DisplayMatchResult(
                    matchedRate: 0,
                    matchedRange: .unknown,
                    message: "OK",
                    status: .requestSubmitted
                )
            }
        #endif
        client.resetDisplayMode = {}
        return client
    }()
}

public extension DependencyValues {
    var displayModeClient: DisplayModeClient {
        get { self[DisplayModeClient.self] }
        set { self[DisplayModeClient.self] = newValue }
    }
}
