import Foundation

public struct SportsMatchItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let homeTeam: String
    public let awayTeam: String
    public let competition: String
    public let channelName: String
    public let channelItem: MediaModels.Item
    public let startTime: Date
    public let endTime: Date

    public var isLiveNow: Bool {
        let now = Date()
        return startTime <= now && now <= endTime
    }

    public var formattedTime: String {
        formattedTime(locale: .autoupdatingCurrent)
    }

    public func formattedTime(locale: Locale) -> String {
        LocalTimePresentation.string(from: startTime, locale: locale)
    }
}

public struct SportsFixtureIdentity: Equatable, Sendable {
    public let homeTeam: String
    public let awayTeam: String
    public let competition: String?
}

public final class SportsHubManager: @unchecked Sendable {
    public static let shared = SportsHubManager()

    private init() {}

    private nonisolated static let sportsContextTerms = [
        "sport", "sports", "football", "soccer", "futbol", "basketball", "basketbol", "hockey", "tennis", "tenis",
        "rugby", "volleyball", "voleybol", "cricket", "boxing", "wrestling", "güreş", "motorsport", "formula 1",
        "moto gp", "ufc", "mma", "nba", "nfl", "nhl", "mlb", "premier league", "champions league", "la liga",
        "serie a", "bundesliga", "süper lig", "super lig", "euroleague", "matchday", "maç", "şampiyonlar ligi",
    ]

    /// Returns true only for explicit fixture syntax, or a dash-separated title with sports context.
    public nonisolated static func isSportsFixture(program: EPGProgram, channelTitle: String) -> Bool {
        teams(in: program.title, allowDashSeparator: false) != nil
            || (hasSportsContext(program: program, channelTitle: channelTitle)
                && teams(in: program.title, allowDashSeparator: true) != nil)
    }

    private nonisolated static func teams(in title: String, allowDashSeparator: Bool) -> (home: String, away: String)? {
        let explicitSeparators = [" vs. ", " vs ", " v. ", " v "]
        let separators = explicitSeparators + (allowDashSeparator ? [" – ", " — ", " - "] : [])

        for separator in separators {
            guard let range = title.range(of: separator, options: .caseInsensitive) else { continue }
            let home = String(title[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let away = String(title[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !home.isEmpty, !away.isEmpty else { continue }
            return (home, away)
        }
        return nil
    }

    private nonisolated static func hasSportsContext(program: EPGProgram, channelTitle: String) -> Bool {
        let context = ([channelTitle, program.description] + program.categories)
            .joined(separator: " ")
        return sportsContextTerms.contains { context.localizedCaseInsensitiveContains($0) }
    }

    private nonisolated static let leagues = [
        "Süper Lig", "Şampiyonlar Ligi", "Premier League", "La Liga",
        "Serie A", "Bundesliga", "EuroLeague", "NBA", "Formula 1",
    ]

    public nonisolated static func fixtureIdentity(
        program: EPGProgram,
        channelTitle: String
    ) -> SportsFixtureIdentity? {
        let allowDashSeparator = hasSportsContext(program: program, channelTitle: channelTitle)
        guard let teams = teams(in: program.title, allowDashSeparator: allowDashSeparator) else { return nil }
        let competition = leagues.first {
            program.title.localizedCaseInsensitiveContains($0)
                || program.description.localizedCaseInsensitiveContains($0)
        }
        return SportsFixtureIdentity(homeTeam: teams.home, awayTeam: teams.away, competition: competition)
    }

    /// Extracts today's sports matches from channel EPG listings
    public func extractMatches(from channels: [MediaModels.Item], epgData: [String: [EPGProgram]]) -> [SportsMatchItem] {
        var matches: [SportsMatchItem] = []
        let calendar = Calendar.current
        let today = Date()

        for channel in channels {
            guard let programs = epgData[channel.id] else { continue }

            for program in programs {
                guard calendar.isDate(program.startTime, inSameDayAs: today) || program.isPlayingNow else {
                    continue
                }

                if let teams = Self.teams(in: program.title, allowDashSeparator: Self.hasSportsContext(program: program, channelTitle: channel.title)) {
                    let home = teams.home
                    let away = teams.away

                    let competition = Self.leagues.first {
                        program.title.localizedCaseInsensitiveContains($0) || program.description.localizedCaseInsensitiveContains($0)
                    } ?? "Canlı Maç"

                    let match = SportsMatchItem(
                        id: "\(channel.id)_\(program.id)",
                        homeTeam: home,
                        awayTeam: away,
                        competition: competition,
                        channelName: channel.title,
                        channelItem: channel,
                        startTime: program.startTime,
                        endTime: program.endTime
                    )
                    matches.append(match)
                }
            }
        }

        return matches.sorted { $0.startTime < $1.startTime }
    }
}
