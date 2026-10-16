import Foundation
import SwiftUI

// MARK: - Media Audio & Subtitle Language Tag

public enum MediaAudioLanguageTag: String, CaseIterable, Sendable, Equatable, Hashable {
    case turkishDubbed
    case turkishSubtitled
    case dualAudio
    case originalAudio

    public var label: String {
        switch self {
        case .turkishDubbed:
            "TR DUB"
        case .turkishSubtitled:
            "TR ALT"
        case .dualAudio:
            "DUAL"
        case .originalAudio:
            "EN"
        }
    }

    public var systemIcon: String {
        switch self {
        case .turkishDubbed:
            "waveform"
        case .turkishSubtitled:
            "captions.bubble.fill"
        case .dualAudio:
            "hifispeaker.2.fill"
        case .originalAudio:
            "globe"
        }
    }

    public var hexColor: String {
        switch self {
        case .turkishDubbed:
            "#00F5D4" // Neon Cyan
        case .turkishSubtitled:
            "#FFD166" // Warm Amber
        case .dualAudio:
            "#A78BFA" // Vibrant Lavender/Purple
        case .originalAudio:
            "#0A84FF" // Electric Blue
        }
    }

    public var color: Color {
        Color(hex: hexColor)
    }
}

// MARK: - Media Language Filter

public enum MediaLanguageFilter: String, CaseIterable, Sendable, Equatable, Hashable, Identifiable {
    case all
    case turkishDubbed = "tr_dub"
    case turkishSubtitled = "tr_sub"
    case dualAudio = "dual"
    case originalAudio = "original"

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .all:
            AppStrings.MediaFilter.all
        case .turkishDubbed:
            AppStrings.MediaFilter.turkishDubbed
        case .turkishSubtitled:
            AppStrings.MediaFilter.turkishSubtitled
        case .dualAudio:
            AppStrings.MediaFilter.dualAudio
        case .originalAudio:
            AppStrings.MediaFilter.originalAudio
        }
    }

    public var iconName: String {
        switch self {
        case .all:
            "square.stack.3d.up"
        case .turkishDubbed:
            "waveform"
        case .turkishSubtitled:
            "captions.bubble.fill"
        case .dualAudio:
            "hifispeaker.2.fill"
        case .originalAudio:
            "globe"
        }
    }

    public var tintColor: Color {
        switch self {
        case .all:
            Color.white
        case .turkishDubbed:
            Color(hex: "#00F5D4")
        case .turkishSubtitled:
            Color(hex: "#FFD166")
        case .dualAudio:
            Color(hex: "#A78BFA")
        case .originalAudio:
            Color(hex: "#0A84FF")
        }
    }
}

// MARK: - Media Language Detector Engine

public enum MediaLanguageDetector {
    /// Regular Expression Patterns
    private static let turkishDubbedRegex: NSRegularExpression? = {
        let pattern = #"(?i)(?:\[|\(|\b)(?:TR[-_\.\s]?DUB(?:LAJ)?|T[ÜU]RK[ÇC]E[-_\.\s]?DUB(?:LAJ)?|TR[-_\.\s]?DUBLAJ|TUR[-_\.\s]?DUB)(?:\]|\)|\b)"#
        return try? NSRegularExpression(pattern: pattern)
    }()

    private static let turkishSubtitledRegex: NSRegularExpression? = {
        let pattern = #"(?i)(?:\[|\(|\b)(?:TR[-_\.\s]?ALT(?:YAZI(?:LI)?)?|T[ÜU]RK[ÇC]E[-_\.\s]?ALTYAZI(?:LI)?|TR[-_\.\s]?SUB(?:TITLE)?)(?:\]|\)|\b)"#
        return try? NSRegularExpression(pattern: pattern)
    }()

    private static let dualAudioRegex: NSRegularExpression? = {
        let pattern = #"(?i)(?:\[|\(|\b)(?:DUAL(?:[-_\.\s]?AUDIO)?|[ÇC][İI]FT[-_\.\s]?SES|MULTI(?:[-_\.\s]?(?:DUB|AUDIO))?|TR[-_\.\s\/]EN|EN[-_\.\s\/]TR)(?:\]|\)|\b)"#
        return try? NSRegularExpression(pattern: pattern)
    }()

    private static let originalAudioRegex: NSRegularExpression? = {
        let pattern = #"(?i)(?:\[|\(|\b)(?:ORIGINAL(?:[-_\.\s]?AUDIO)?|OR[İI]J[İI]NAL(?:[-_\.\s]?SES)?|ENG(?:LISH)?|EN[-_\.\s]?DUB)(?:\]|\)|\b)"#
        return try? NSRegularExpression(pattern: pattern)
    }()

    /// Detects all matching audio and subtitle language tags in a title
    public static func detectTags(from title: String) -> Set<MediaAudioLanguageTag> {
        var tags = Set<MediaAudioLanguageTag>()
        let range = NSRange(title.startIndex ..< title.endIndex, in: title)

        if let regex = dualAudioRegex, regex.firstMatch(in: title, range: range) != nil {
            tags.insert(.dualAudio)
            // Dual audio files invariably provide Turkish audio channel as well
            tags.insert(.turkishDubbed)
        }

        if let regex = turkishDubbedRegex, regex.firstMatch(in: title, range: range) != nil {
            tags.insert(.turkishDubbed)
        }

        if let regex = turkishSubtitledRegex, regex.firstMatch(in: title, range: range) != nil {
            tags.insert(.turkishSubtitled)
        }

        if let regex = originalAudioRegex, regex.firstMatch(in: title, range: range) != nil {
            tags.insert(.originalAudio)
        }

        return tags
    }

    /// Highest priority single tag to display as a badge on the item's poster card
    public static func primaryTag(from title: String) -> MediaAudioLanguageTag? {
        let tags = detectTags(from: title)
        if tags.contains(.dualAudio) {
            return .dualAudio
        }
        if tags.contains(.turkishDubbed) {
            return .turkishDubbed
        }
        if tags.contains(.turkishSubtitled) {
            return .turkishSubtitled
        }
        if tags.contains(.originalAudio) {
            return .originalAudio
        }
        return nil
    }

    /// Determines if an item matches the requested language filter
    public static func matches(title: String, filter: MediaLanguageFilter) -> Bool {
        if filter == .all {
            return true
        }

        let tags = detectTags(from: title)
        switch filter {
        case .all:
            return true
        case .turkishDubbed:
            return tags.contains(.turkishDubbed) || tags.contains(.dualAudio)
        case .turkishSubtitled:
            return tags.contains(.turkishSubtitled)
        case .dualAudio:
            return tags.contains(.dualAudio)
        case .originalAudio:
            return tags.contains(.originalAudio) || tags.contains(.dualAudio)
        }
    }

    /// Count how many items match a given filter
    public static func count(for filter: MediaLanguageFilter, in items: [MediaModels.Item]) -> Int {
        if filter == .all {
            return items.count
        }
        return items.filter { matches(title: $0.title, filter: filter) }.count
    }

    /// Returns filters that have at least one match in the item list, plus .all
    public static func availableFilters(for items: [MediaModels.Item]) -> [MediaLanguageFilter] {
        var results: [MediaLanguageFilter] = [.all]
        for filter in MediaLanguageFilter.allCases where filter != .all {
            if items.contains(where: { matches(title: $0.title, filter: filter) }) {
                results.append(filter)
            }
        }
        return results
    }
}
