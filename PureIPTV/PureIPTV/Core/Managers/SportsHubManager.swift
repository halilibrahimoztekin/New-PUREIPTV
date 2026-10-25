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

public final class SportsHubManager: @unchecked Sendable {
    public static let shared = SportsHubManager()

    private init() {}

    private let leagues = [
        "Süper Lig", "Şampiyonlar Ligi", "Premier League", "La Liga",
        "Serie A", "Bundesliga", "EuroLeague", "NBA", "Formula 1",
    ]

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

                let title = program.title
                // Detect "Team A - Team B" or "Team A vs Team B" patterns
                var teams: [String] = []
                if title.contains(" - ") {
                    teams = title.components(separatedBy: " - ")
                } else if title.lowercased().contains(" vs ") {
                    teams = title.components(separatedBy: " vs ")
                } else if title.lowercased().contains(" v ") {
                    teams = title.components(separatedBy: " v ")
                }

                if teams.count == 2 {
                    let home = teams[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let away = teams[1].trimmingCharacters(in: .whitespacesAndNewlines)

                    let competition = leagues.first {
                        title.localizedCaseInsensitiveContains($0) || program.description.localizedCaseInsensitiveContains($0)
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
