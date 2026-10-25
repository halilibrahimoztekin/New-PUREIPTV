import Foundation

public struct EPGMappingSuggestionCandidate: Equatable, Identifiable, Sendable {
    public let option: CustomEPGChannelOption
    public let confidence: Int

    public var id: String {
        option.id
    }
}

public struct EPGMappingSuggestion: Equatable, Identifiable, Sendable {
    public let channelID: String
    public let channelName: String
    public let candidates: [EPGMappingSuggestionCandidate]

    public var id: String {
        channelID
    }
}

public nonisolated enum EPGMappingSuggestionEngine {
    public static func suggestions(
        for channels: [MediaModels.Item],
        from options: [CustomEPGChannelOption]
    ) async -> [EPGMappingSuggestion] {
        await Task.detached(priority: .utility) {
            let sortedOptions = options.sorted {
                if $0.channelName != $1.channelName {
                    return $0.channelName < $1.channelName
                }
                if $0.sourceName != $1.sourceName {
                    return $0.sourceName < $1.sourceName
                }
                return $0.channelID < $1.channelID
            }
            let normalizedOptions = sortedOptions.map { FuzzySearchEngine.normalize($0.channelName) }
            var optionIndicesByToken: [String: [Int]] = [:]
            var exactOptionIndices: [String: [Int]] = [:]
            var compactOptionIndices: [String: [Int]] = [:]

            for (index, normalizedName) in normalizedOptions.enumerated() {
                exactOptionIndices[normalizedName, default: []].append(index)
                compactOptionIndices[normalizedName.filter { !$0.isWhitespace }, default: []].append(index)
                for token in Set(normalizedName.split(whereSeparator: \.isWhitespace).map(String.init)) where token.count >= 3 {
                    optionIndicesByToken[token, default: []].append(index)
                }
            }

            let liveChannels = channels
                .filter { $0.type == .live }
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            var suggestions: [EPGMappingSuggestion] = []
            suggestions.reserveCapacity(min(liveChannels.count, 100))

            for (channelIndex, channel) in liveChannels.enumerated() {
                if channelIndex.isMultiple(of: 128), Task.isCancelled {
                    return []
                }
                let normalizedName = FuzzySearchEngine.normalize(channel.title)
                guard !normalizedName.isEmpty else { continue }

                var candidateIndices = Set(exactOptionIndices[normalizedName] ?? [])
                candidateIndices.formUnion(compactOptionIndices[normalizedName.filter { !$0.isWhitespace }] ?? [])
                for token in Set(normalizedName.split(whereSeparator: \.isWhitespace).map(String.init)) where token.count >= 3 {
                    for index in optionIndicesByToken[token, default: []].prefix(500) {
                        candidateIndices.insert(index)
                    }
                }
                guard !candidateIndices.isEmpty else { continue }

                let candidates = candidateIndices.compactMap { index -> EPGMappingSuggestionCandidate? in
                    guard let score = FuzzySearchEngine.score(query: normalizedName, target: normalizedOptions[index]), score >= 650 else { return nil }
                    return EPGMappingSuggestionCandidate(option: sortedOptions[index], confidence: min(100, score / 10))
                }
                .sorted {
                    if $0.confidence != $1.confidence {
                        return $0.confidence > $1.confidence
                    }
                    if $0.option.channelName != $1.option.channelName {
                        return $0.option.channelName < $1.option.channelName
                    }
                    return $0.option.sourceName < $1.option.sourceName
                }
                .prefix(3)

                guard !candidates.isEmpty else { continue }
                suggestions.append(EPGMappingSuggestion(channelID: channel.id, channelName: channel.title, candidates: Array(candidates)))
            }

            return suggestions.sorted {
                let lhs = $0.candidates.first?.confidence ?? 0
                let rhs = $1.candidates.first?.confidence ?? 0
                if lhs != rhs {
                    return lhs > rhs
                }
                return $0.channelName.localizedCaseInsensitiveCompare($1.channelName) == .orderedAscending
            }.prefix(100).map(\.self)
        }.value
    }
}
