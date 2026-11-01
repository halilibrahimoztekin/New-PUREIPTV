import Foundation

nonisolated enum SeriesEpisodeCatalogNormalizer {
    static func diagnostics(for episodes: [DetailModels.Episode]) -> DetailModels.SeriesCatalogDiagnostics {
        let numberedEpisodes = episodes.filter { $0.season >= 0 && $0.episodeNum > 0 }
        let episodesByPosition = Dictionary(grouping: numberedEpisodes) {
            "\($0.season)|\($0.episodeNum)"
        }

        let duplicatePositions = episodesByPosition.compactMap { _, entries -> DetailModels.SeriesCatalogDiagnostics.DuplicateEpisodePosition? in
            let sourceIDs = Array(Set(entries.map { $0.id.trimmingCharacters(in: .whitespacesAndNewlines) }))
                .filter { !$0.isEmpty }
                .sorted()
            guard entries.count > 1, sourceIDs.count > 1,
                  let entry = entries.first
            else { return nil }
            return DetailModels.SeriesCatalogDiagnostics.DuplicateEpisodePosition(
                seasonNumber: entry.season,
                episodeNumber: entry.episodeNum,
                sourceIDs: sourceIDs
            )
        }
        .sorted {
            if $0.seasonNumber != $1.seasonNumber {
                return $0.seasonNumber < $1.seasonNumber
            }
            return $0.episodeNumber < $1.episodeNumber
        }

        let episodeNumbersBySeason = Dictionary(grouping: numberedEpisodes, by: \.season)
            .mapValues { Set($0.map(\.episodeNum)).sorted() }
        let missingRanges = episodeNumbersBySeason.flatMap { season, numbers in
            zip(numbers, numbers.dropFirst()).compactMap { previous, next -> DetailModels.SeriesCatalogDiagnostics.MissingEpisodeRange? in
                guard next > previous, next - previous > 1 else { return nil }
                return DetailModels.SeriesCatalogDiagnostics.MissingEpisodeRange(
                    seasonNumber: season,
                    firstMissingEpisode: previous + 1,
                    lastMissingEpisode: next - 1
                )
            }
        }
        .sorted {
            if $0.seasonNumber != $1.seasonNumber {
                return $0.seasonNumber < $1.seasonNumber
            }
            return $0.firstMissingEpisode < $1.firstMissingEpisode
        }

        return DetailModels.SeriesCatalogDiagnostics(
            missingEpisodeRanges: missingRanges,
            duplicateEpisodePositions: duplicatePositions
        )
    }

    static func canonicalized(_ episodes: [DetailModels.Episode]) -> [DetailModels.Episode] {
        var seenProviderIDs = Set<String>()
        var seenEpisodeCoordinates = Set<String>()

        return sorted(episodes).filter { episode in
            let providerID = episode.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !providerID.isEmpty, seenProviderIDs.insert(providerID).inserted else {
                return false
            }

            let titleIdentity = normalizedTitle(episode.title)
            guard episode.episodeNum >= 0, !titleIdentity.isEmpty else { return true }

            let coordinate = "\(episode.season)|\(episode.episodeNum)|\(titleIdentity)"
            return seenEpisodeCoordinates.insert(coordinate).inserted
        }
    }

    static func sorted(_ episodes: [DetailModels.Episode]) -> [DetailModels.Episode] {
        episodes.sorted { lhs, rhs in
            if lhs.season != rhs.season {
                return lhs.season < rhs.season
            }
            if lhs.episodeNum != rhs.episodeNum {
                return lhs.episodeNum < rhs.episodeNum
            }

            let lhsTitle = normalizedTitle(lhs.title)
            let rhsTitle = normalizedTitle(rhs.title)
            if lhsTitle != rhsTitle {
                return lhsTitle < rhsTitle
            }
            if lhs.id != rhs.id {
                return lhs.id < rhs.id
            }
            return lhs.streamURL.absoluteString < rhs.streamURL.absoluteString
        }
    }

    private static func normalizedTitle(_ title: String) -> String {
        let folded = title.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        return String(folded.filter { $0.isLetter || $0.isNumber })
    }
}
